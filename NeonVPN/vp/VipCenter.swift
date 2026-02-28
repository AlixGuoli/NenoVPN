import Foundation
import StoreKit

/// VIP 订阅中心：负责订阅产品加载、购买、恢复、订阅状态管理（StoreKit 2）。
@MainActor
final class VipCenter: ObservableObject {
    static let shared = VipCenter()

    enum Pack: String, CaseIterable {
        case week = "com.coco.neon.vpn.fly.week"
        case month = "com.coco.neon.vpn.fly.month"
        case year = "com.coco.neon.vpn.fly.year"
    }

    // MARK: - Cache keys
    private let cacheHasVipKey = "VipCenter_HasVip"
    private let cacheExpiryKey = "VipCenter_Expiry"
    private let cacheProductIdKey = "VipCenter_ProductId"

    private let packProductIds: Set<String> = Set(Pack.allCases.map(\.rawValue))

    // MARK: - Published states
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published private(set) var isRestoring: Bool = false

    @Published private(set) var hasVip: Bool = false
    @Published private(set) var vipEndDate: Date? = nil
    @Published private(set) var currentProductId: String? = nil

    var isBusy: Bool { isLoadingProducts || isPurchasing || isRestoring }

    private init() {
        restoreFromCache()
        log("init cached hasVip=\(hasVip) end=\(vipEndDate.map(fmt) ?? "nil") pid=\(currentProductId ?? "nil")")
        AdCoordinator.instance.isVip = hasVip
        Task { [weak self] in
            guard let self else { return }
            await refreshVipStatus()
            await observeTransactions()
        }
    }

    // MARK: - Products

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: packProductIds)
            // 固定顺序：week / month / year
            let map: [String: Int] = [
                Pack.week.rawValue: 0,
                Pack.month.rawValue: 1,
                Pack.year.rawValue: 2
            ]
            products = loaded.sorted { (map[$0.id] ?? 999) < (map[$1.id] ?? 999) }
            log("✅ loadProducts ok count=\(products.count)")
            products.forEach { p in
                log("  product id=\(p.id) price=\(p.displayPrice)")
            }
        } catch {
            log("❌ loadProducts failed err=\(error.localizedDescription)")
        }
    }

    func product(for pack: Pack) -> Product? {
        products.first { $0.id == pack.rawValue }
    }

    // MARK: - Purchase

    func purchase(pack: Pack) async -> Bool {
        if let p = product(for: pack) {
            return await purchase(product: p)
        }
        await loadProducts()
        guard let p = product(for: pack) else { return false }
        return await purchase(product: p)
    }

    private func purchase(product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            log("start purchase product=\(product.id) price=\(product.displayPrice)")
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                log("✅ purchase verified pid=\(transaction.productID) tid=\(transaction.id)")
                await transaction.finish()
                await rebuildVipSnapshot()
                log("✅ purchase finished pid=\(product.id) hasVip=\(hasVip) end=\(vipEndDate.map(fmt) ?? "nil")")
                return true
            case .userCancelled:
                log("user cancelled")
                return false
            case .pending:
                log("pending")
                return false
            @unknown default:
                log("unknown purchase result")
                return false
            }
        } catch {
            log("❌ purchase failed err=\(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Restore

    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        do {
            log("start restore (AppStore.sync)")
            try await AppStore.sync()
        } catch {
            log("AppStore.sync error: \(error.localizedDescription)")
        }
        await rebuildVipSnapshot()
        log("restore done hasVip=\(hasVip) end=\(vipEndDate.map(fmt) ?? "nil") pid=\(currentProductId ?? "nil")")
    }

    // MARK: - Status

    func refreshVipStatus() async {
        await rebuildVipSnapshot()
    }

    private func rebuildVipSnapshot() async {
        let now = Date()
        let (expiry, pid) = await latestEntitlement()

        if let expiry, expiry > now {
            hasVip = true
            vipEndDate = expiry
            currentProductId = pid
            writeCache(expiry: expiry, productId: pid)
            AdCoordinator.instance.isVip = true
            log("snapshot hasVip=true end=\(fmt(expiry)) pid=\(pid ?? "nil")")
        } else {
            hasVip = false
            vipEndDate = nil
            currentProductId = nil
            clearCache()
            AdCoordinator.instance.isVip = false
            log("snapshot hasVip=false")
        }
    }

    // MARK: - Transactions

    private func observeTransactions() async {
        for await update in Transaction.updates {
            do {
                let t = try checkVerified(update)
                guard packProductIds.contains(t.productID) else {
                    await t.finish()
                    continue
                }
                log("tx update pid=\(t.productID) tid=\(t.id) revoked=\(t.revocationDate != nil)")
                await rebuildVipSnapshot()
                await t.finish()
            } catch {
                log("❌ tx update verify failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Helpers

private extension VipCenter {
    enum VipError: Error { case failedVerification }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw VipError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    func latestEntitlement() async -> (expiry: Date?, productId: String?) {
        var bestExpiry: Date? = nil
        var bestPid: String? = nil

        for await entitlement in Transaction.currentEntitlements {
            do {
                let t = try checkVerified(entitlement)
                guard packProductIds.contains(t.productID) else { continue }
                if t.revocationDate != nil { continue }

                let expiry = t.expirationDate ?? .distantFuture
                if bestExpiry == nil || expiry > bestExpiry! {
                    bestExpiry = expiry
                    bestPid = t.productID
                }
            } catch {
                // ignore invalid entitlements
            }
        }
        return (bestExpiry, bestPid)
    }

    func restoreFromCache() {
        let defaults = UserDefaults.standard
        let cached = defaults.bool(forKey: cacheHasVipKey)
        let interval = defaults.object(forKey: cacheExpiryKey) as? TimeInterval
        let pid = defaults.string(forKey: cacheProductIdKey)

        if cached, let interval {
            let expiry = Date(timeIntervalSince1970: interval)
            if expiry > Date() {
                hasVip = true
                vipEndDate = expiry
                currentProductId = pid
                AdCoordinator.instance.isVip = true
                return
            }
        }

        hasVip = false
        vipEndDate = nil
        currentProductId = nil
        clearCache()
        AdCoordinator.instance.isVip = false
    }

    func writeCache(expiry: Date, productId: String?) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: cacheHasVipKey)
        defaults.set(expiry.timeIntervalSince1970, forKey: cacheExpiryKey)
        defaults.set(productId, forKey: cacheProductIdKey)
    }

    func clearCache() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: cacheHasVipKey)
        defaults.removeObject(forKey: cacheExpiryKey)
        defaults.removeObject(forKey: cacheProductIdKey)
    }

    func log(_ msg: String) {
        debugPrint("[VIP] \(msg)")
    }

    func fmt(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}

