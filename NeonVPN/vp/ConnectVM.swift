import Foundation
import Network
import NetworkExtension

final class ConnectVM: ObservableObject {

    enum Stage { case disconnected, connecting, connected, failed }
    
    enum ResultType {
        case success    // 连接成功
        case failed     // 连接失败
        case disconnected  // 断开成功
    }

    @Published var stage: Stage = .disconnected {
        didSet {
            ConnectionStatusCenter.shared.update(stage: stage)
        }
    }
    // 系统原始状态：仅记录，不直接用于 UI
    @Published var systemStatus: NEVPNStatus = .invalid
    // 结果页导航控制
    @Published var navigateToResult: Bool = false
    @Published var resultType: ResultType = .failed
    // 连接页导航控制
    @Published var showConnectingView: Bool = false
    // 断开确认弹窗
    @Published var showDisconnectConfirm: Bool = false
    /// 无网络提示（点击连接时无网则弹出，不进入连接流程）
    @Published var showNoNetworkAlert: Bool = false
    // 连接时间统计
    @Published var connectionDuration: TimeInterval = 0
    @Published var formattedDuration: String = "00:00:00"
    // 对齐旧实现：系统态 state -> didSet 触发统一映射入口
    @Published var state: NEVPNStatus = .invalid {
        didSet {
            guard oldValue != state else { return }
            applyStateToUI(state)
        }
    }

    private var manager: NETunnelProviderManager?
    private let config = Config()
    private var userInitiated: Bool = false // 是否用户主动发起连接
    private var resultAdShown: Bool = false
    private var connectionStartTime: Date?
    private var timer: Timer?
    private let connectionTimeKey = "connectionStartTime"
    private let historyManager = ConnectionHistoryManager.shared

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(onSystemStatus), name: .NEVPNStatusDidChange, object: nil)
        bootstrap()
        setupTimer()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }

    // MARK: - Public API

    func beginSession() {
        // 发起连接；进行中时直接返回
        guard stage != .connecting else { return }

        // 无网先拦：点击时做一次即时 path 检查，避免用尚未更新的 trafficData 误判（首点易误报无网）
        let pathMonitor = NWPathMonitor()
        let pathQueue = DispatchQueue(label: "com.neonvpn.connect.path")
        pathMonitor.pathUpdateHandler = { [weak self] path in
            pathMonitor.cancel()
            DispatchQueue.main.async {
                guard let self = self else { return }
                if path.status != .satisfied {
                    self.showNoNetworkAlert = true
                    return
                }
                self.proceedWithConnectionFlow()
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    /// 在确认有网、拿到权限后再出连接页并起隧道
    private func proceedWithConnectionFlow() {
        loadOrCreateManager { [weak self] mgr in
            guard let self = self, let mgr = mgr else {
                DispatchQueue.main.async { self?.stage = .disconnected }
                return
            }
            self.enableAndReload(mgr) { [weak self] ok in
                guard let self = self else { return }
                guard ok else {
                    DispatchQueue.main.async { self.stage = .disconnected }
                    return
                }
                // 权限/配置就绪后再出连接页并上报、拉广告
                DispatchQueue.main.async {
                    self.showConnectingView = true
                    self.stage = .connecting
                    self.userInitiated = true
                    ServiceVault.shared.idConnect = EventLogger.createSessionId()
                    EventLogger.shared.logConnection(
                        moment: NetProfile.EventKeys.KEY_START,
                        ip: ServiceVault.shared.ipService,
                        sid: ServiceVault.shared.idConnect
                    )
                    AdCoordinator.instance.loadAllAds(moment: StoreKeys.AdTrigger.connect)
                }
                // 拉服务配置后立即起隧道（无人为延迟）；主线程更新用 main.async 投递，不 await，保持原有时序
                Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        try await self.loadService()
                    } catch {
                        DispatchQueue.main.async { [weak self] in
                            self?.stage = .failed
                            self?.showConnectingView = false
                        }
                        return
                    }
                    let selectedServer = UserDefaults.standard.string(forKey: "selectedServerCode") ?? "auto"
                    let serverName = self.getServerDisplayName(for: selectedServer)
                    // recordConnectionStart 会改 @Published，投到主线程执行，不 await 不改变后续 startVPNTunnel 的时机
                    DispatchQueue.main.async { [weak self] in
                        self?.historyManager.recordConnectionStart(server: serverName)
                    }
                    do {
                        try self.manager?.connection.startVPNTunnel()
                    } catch {
                        debugPrint("[CONNECT] startVPNTunnel 失败: \(error)")
                        DispatchQueue.main.async { [weak self] in
                            self?.stage = .failed
                            self?.showConnectingView = false
                        }
                    }
                }
            }
        }
    }

    func endSession() {
        // 断开连接；进行中时直接返回
        guard stage != .connecting else { return }
        guard let mgr = manager else { return }
        switch mgr.connection.status {
        case .connected, .connecting, .reasserting:
            // 显示确认弹窗前，先加载广告
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                AdCoordinator.instance.loadAllAds(moment: StoreKeys.AdTrigger.connect)
            }
            // 显示确认弹窗
            showDisconnectConfirm = true
        default:
            break
        }
    }
    
    /// 确认断开连接
    func confirmDisconnect() {
        guard let mgr = manager else { return }
        showDisconnectConfirm = false
        
        // 先设置结果页状态，触发结果页显示
        resultType = .disconnected
        navigateToResult = true
        
        // 检查是否有广告可以展示
        let ads = AdCoordinator.instance
        if ads.hasAnyReady {
            debugPrint("[ADS] [Manager] 断开时有广告可展示，延迟 3 秒后断开")
            // 延迟 3 秒后断开，给广告展示时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                mgr.connection.stopVPNTunnel()
            }
        } else {
            debugPrint("[ADS] [Manager] 断开时没有广告可展示，立即断开")
            // 没有广告，立即断开
            mgr.connection.stopVPNTunnel()
        }
    }
    
    /// 取消断开连接
    func cancelDisconnect() {
        showDisconnectConfirm = false
    }

    // MARK: - Private

    private func bootstrap() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] list, _ in
            guard let self = self else { return }
            self.manager = list?.first
            let s = self.manager?.connection.status ?? .invalid
            DispatchQueue.main.async {
                self.systemStatus = s
                self.state = s // 首帧触发一次映射
                // 如果系统已连接，恢复连接时间
                if s == .connected {
                    self.restoreConnectionTime()
                }
            }
        }
    }

    @objc private func onSystemStatus() {
        let s = manager?.connection.status ?? .invalid
        systemStatus = s
        // 常规路径：仅更新系统态，由 didSet 统一映射
        state = s
    }

    // 统一映射入口（对齐旧实现 applyStateToUI）
    private func applyStateToUI(_ newState: NEVPNStatus) {
        debugPrint("🟡 applyStateToUI: \(newState), userInitiated: \(userInitiated), navigateToResult: \(navigateToResult)")
        switch newState {
        case .connected:
            // 若为用户主动触发，先探测网络，再通知成功/失败
            if userInitiated {
                debugPrint("🟡 手动连接，开始探测网络")
                checkConnectivity()
            } else {
                debugPrint("🟡 自动连接")
                stage = .connected
            }
        case .disconnected, .invalid:
            debugPrint("🟡 连接断开，navigateToResult: \(navigateToResult)")
            if userInitiated {
                // 用户主动连接失败，需要关闭连接页并弹出结果页
                notifyConnectFailed()
            } else {
                // 自动断开或其他情况
                stage = .disconnected
                userInitiated = false
                stopConnectionTimer()
                NetworkMonitor.shared.stopVPNConnection()
                historyManager.recordConnectionDisconnect() // 记录连接断开
            }
        case .connecting:
            stage = .connecting
        case .disconnecting, .reasserting:
            stage = .connecting
        @unknown default:
            stage = .failed
            userInitiated = false
        }
    }


    // 无表驱动：使用 applyStateToUI 保持可读逻辑

    
    // MARK: - 连接时间统计
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateConnectionDuration()
        }
    }
    
    private func startConnectionTimer() {
        connectionStartTime = Date()
        UserDefaults.standard.set(connectionStartTime, forKey: connectionTimeKey)
    }
    
    private func stopConnectionTimer() {
        connectionStartTime = nil
        connectionDuration = 0
        formattedDuration = "00:00:00"
        UserDefaults.standard.removeObject(forKey: connectionTimeKey)
    }
    
    private func updateConnectionDuration() {
        guard stage == .connected else { return }
        
        let startTime: Date
        if let savedTime = connectionStartTime {
            startTime = savedTime
        } else if let savedTime = UserDefaults.standard.object(forKey: connectionTimeKey) as? Date {
            startTime = savedTime
            connectionStartTime = savedTime
        } else {
            return
        }
        
        connectionDuration = Date().timeIntervalSince(startTime)
        formattedDuration = formatDuration(connectionDuration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // 恢复连接时间（app重启后调用）
    func restoreConnectionTime() {
        guard stage == .connected else { return }
        
        if let savedTime = UserDefaults.standard.object(forKey: connectionTimeKey) as? Date {
            connectionStartTime = savedTime
            updateConnectionDuration()
        }
    }
    
    // MARK: - 历史记录通知方法
    
    func notifyConnectSucceeded() {
        // 上报连接成功
        EventLogger.shared.logConnection(
            moment: NetProfile.EventKeys.KEY_SUCCESS,
            ip: ServiceVault.shared.ipService,
            sid: ServiceVault.shared.idConnect
        )
        
        // 如果是从请求获取的配置，保存到 UserDefaults
        if ServiceVault.shared.isFromRequest,
           let serviceConfig = ServiceVault.shared.currentConfig,
           !serviceConfig.isEmpty {
            debugPrint("[CONNECT] 保存服务配置到 UserDefaults")
            ServiceVault.shared.store(serviceConfig)
        }
        
        stage = .connected
        userInitiated = false
        startConnectionTimer()
        NetworkMonitor.shared.startVPNConnection()
        TrafficStatsManager.shared.simulateVPNTraffic()
        historyManager.recordConnectionSuccess() // 记录连接成功
        resultType = .success
        // 先显示结果页，再关闭连接页，实现无缝衔接
        navigateToResult = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showConnectingView = false
        }
    }
    
    func notifyConnectFailed() {
        // 上报连接失败
        EventLogger.shared.logConnection(
            moment: NetProfile.EventKeys.KEY_FAIL,
            ip: ServiceVault.shared.ipService,
            sid: ServiceVault.shared.idConnect
        )
        
        if let mgr = manager {
            switch mgr.connection.status {
            case .connected, .connecting, .reasserting:
                mgr.connection.stopVPNTunnel()
            default:
                break
            }
        }
        stage = .failed
        userInitiated = false
        stopConnectionTimer()
        NetworkMonitor.shared.stopVPNConnection()
        historyManager.recordConnectionFailure() // 记录连接失败
        resultType = .failed
        // 先显示结果页，再关闭连接页，实现无缝衔接
        navigateToResult = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showConnectingView = false
        }
    }
    
    // MARK: - 结果页管理
    
    func closeResultPage() {
        navigateToResult = false
        resultAdShown = false
    }
    
    /// 在结果页显示时展示广告（连接成功或断开成功时展示，连接失败不展示）
    func showAdForResultIfNeeded() {
        guard !resultAdShown else { return }
        // 连接失败不出广告
        guard resultType != .failed else {
            debugPrint("[ADS] [Manager] 连接失败，不展示广告")
            return
        }

        let ads = AdCoordinator.instance

        // 检查是否有广告可以展示，优先级顺序：AdMob > Yandex Banner > Yandex Int
        guard ads.hasAnyReady else {
            debugPrint("[ADS] [Manager] 没有广告可展示")
            return
        }

        resultAdShown = true
        
        // 根据结果类型选择 moment
        let moment: String
        switch resultType {
        case .success:
            moment = StoreKeys.AdTrigger.connect
        case .disconnected:
            moment = StoreKeys.AdTrigger.disconnect
        case .failed:
            return // 已在上面的 guard 中处理
        }
        
        // 按优先级展示广告
        if ads.isMobReady {
            debugPrint("[ADS] [Manager] 从结果页展示 AdMob 广告")
            ads.showFromWindow(.mobInt(moment: moment))
        } else if ads.isBaYaReady {
            debugPrint("[ADS] [Manager] 从结果页展示 Yandex Banner 广告")
            ads.showFromWindow(.baYa)
        } else if ads.isInYaReady {
            debugPrint("[ADS] [Manager] 从结果页展示 Yandex Int 广告")
            ads.showFromWindow(.inYa(onClose: nil))
        }
    }
    
    // MARK: - 连接页管理
    
    func closeConnectingView() {
        showConnectingView = false
    }
    
    // MARK: - 辅助方法
    
    private func getServerDisplayName(for code: String) -> String {
        switch code {
        case "auto": return LocalizedText("auto_node")
        case "us": return "United States"
        case "uk": return "United Kingdom"
        case "sg": return "Singapore"
        case "jp": return "Japan"
        case "de": return "Germany"
        case "nl": return "Netherlands"
        case "ca": return "Canada"
        case "au": return "Australia"
        default: return "Unknown"
        }
    }
}

// MARK: - VPN 配置管理
extension ConnectVM {
    private func loadOrCreateManager(completion: @escaping (NETunnelProviderManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] list, _ in
            if let mgr = list?.first {
                self?.manager = mgr
                completion(mgr)
                return
            }
            // 新建（按之前做法：不设置 providerBundleIdentifier）
            let mgr = NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.serverAddress = self?.config.displayName
            // 可选：传参给扩展（使用非直观键名）
            // proto.providerConfiguration = ["x_cfg": ["p": "v1"]]

            mgr.protocolConfiguration = proto
            mgr.localizedDescription = self?.config.displayName
            mgr.isEnabled = true
            mgr.saveToPreferences { error in
                guard error == nil else { completion(nil); return }
                mgr.loadFromPreferences { error in
                    guard error == nil else { completion(nil); return }
                    self?.manager = mgr
                    completion(mgr)
                }
            }
        }
    }

    private func enableAndReload(_ mgr: NETunnelProviderManager, completion: @escaping (Bool) -> Void) {
        mgr.isEnabled = true
        mgr.saveToPreferences { error in
            guard error == nil else { completion(false); return }
            mgr.loadFromPreferences { error in
                completion(error == nil)
            }
        }
    }
    
    private struct Config { let displayName = "VPN Fly" }
}

// MARK: - 服务配置扩展
private extension ConnectVM {
    /// 加载服务配置
    func loadService() async throws {
        var encryptedConfig = await NetCenter.shared.getServiceEndpoint()
        //encryptedConfig = nil
        if encryptedConfig == nil || encryptedConfig?.isEmpty == true {
            debugPrint("[CONNECT] 请求服务配置失败，尝试从 UserDefaults 读取")
            encryptedConfig = ServiceVault.shared.load()
            
            if encryptedConfig == nil || encryptedConfig?.isEmpty == true {
                debugPrint("[CONNECT] !!! UserDefaults 中也没有服务配置")
                return
            }
            
            debugPrint("[CONNECT] 使用 UserDefaults 中的服务配置")
            ServiceVault.shared.currentConfig = encryptedConfig!
            ServiceVault.shared.isFromRequest = false
            EventLogger.shared.logServiceStatus(success: false)
        } else {
            debugPrint("[CONNECT] 使用请求到的服务配置")
            ServiceVault.shared.currentConfig = encryptedConfig!
            ServiceVault.shared.isFromRequest = true
            EventLogger.shared.logServiceStatus(success: true)
        }
        
        guard let payload = encryptedConfig else {
            debugPrint("[CONNECT] !!! 服务配置为空")
            return
        }
        
        guard let decryptedConfig = NetProfile.Sec.reveal(payload) else {
            debugPrint("[CONNECT] !!! 服务配置解密失败")
            return
        }
        
        debugPrint("[CONNECT] 解密后的服务配置: \(decryptedConfig)")
        
        // 解析配置，提取节点信息
        extractNodeAddress(configString: decryptedConfig, shouldPrefix: ServiceVault.shared.isFromRequest)
        
        // 保存到 Group，供 PacketTunnel 使用
        try await ConnectionBuilder.instance.storeGroupConfig(serviceConfig: decryptedConfig)
    }
    
    /// 解析服务配置，提取节点
    func extractNodeAddress(configString: String?, shouldPrefix: Bool) {
        guard let configData = configString?.data(using: .utf8) else { return }
        
        do {
            let jsonRoot = try JSONSerialization.jsonObject(with: configData, options: .allowFragments) as? [String: Any]
            let outboundList = jsonRoot?["outbounds"] as? [[String: Any]]
            
            outboundList?.forEach { outboundItem in
                let settingsDict = outboundItem["settings"] as? [String: Any]
                let nodeList = settingsDict?["vnext"] as? [[String: Any]]
                
                nodeList?.forEach { nodeItem in
                    if let address = nodeItem["address"] as? String {
                        let targetAddress = shouldPrefix ? address : "f\(address)"
                        ServiceVault.shared.ipService = targetAddress
                    }
                }
            }
        } catch {
            debugPrint("[CONNECT] 解析服务配置失败: \(error)")
        }
    }
    
    /// 检查网络连通性
    func checkConnectivity() {
        Task {
            let isConnected = await NetCenter.shared.checkConnectivity()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if isConnected {
                    debugPrint("[CONNECT] 网络探测成功")
                    self.loadAdWithTimeout()
                } else {
                    debugPrint("[CONNECT] 网络探测失败")
                    self.notifyConnectFailed()
                }
            }
        }
    }
    
    /// 准备并通知连接成功（加载 Admob 广告，带超时管理）
    private func loadAdWithTimeout() {
        // 设置全局连接状态为已连接（Admob 需要连接状态才能加载）
        ConnectionStatusCenter.shared.update(stage: .connected)
        
        let startTime = Date()
        debugPrint("[ADS] [Manager] 开始加载 Admob，开始时间: \(startTime)")
        
        var isCompleted = false
        let timeoutDuration: TimeInterval = 15.0
        
        // 设置超时任务
        let timeoutTask = DispatchWorkItem { [weak self] in
            guard let self = self, !isCompleted else { return }
            isCompleted = true
            let timeoutTimestamp = Date()
            debugPrint("[ADS] [Manager] Admob 加载超时: \(timeoutTimestamp)，耗时: \(timeoutTimestamp.timeIntervalSince(startTime))")
            self.notifyConnectSucceeded()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutDuration, execute: timeoutTask)
        
        // 加载 Admob 广告
        AdCoordinator.instance.loadMob(moment: StoreKeys.AdTrigger.connect, onReady: { [weak self] in
            // 成功处理
            guard let self = self, !isCompleted else { return }
            isCompleted = true
            timeoutTask.cancel()
            let endTime = Date()
            debugPrint("[ADS] [Manager] Admob 加载成功: \(endTime)，耗时: \(endTime.timeIntervalSince(startTime))")
            self.notifyConnectSucceeded()
        }, onFailed: { [weak self] in
            // 失败处理
            guard let self = self, !isCompleted else { return }
            isCompleted = true
            timeoutTask.cancel()
            let endTime = Date()
            debugPrint("[ADS] [Manager] Admob 加载失败: \(endTime)，耗时: \(endTime.timeIntervalSince(startTime))")
            self.notifyConnectSucceeded()
        })
    }
}
