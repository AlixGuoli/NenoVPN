import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject private var vipCenter: VipCenter
    @Environment(\.openURL) private var openURL
    
    private static let termsURL = URL(string: "https://keyvpntwo.xyz/m.html")!
    private enum Plan: String, CaseIterable, Identifiable {
        case weekly
        case monthly
        case yearly
        
        var id: String { rawValue }
        
        var titleKey: String {
            switch self {
            case .weekly: return "vip_plan_weekly"
            case .monthly: return "vip_plan_monthly"
            case .yearly: return "vip_plan_yearly"
            }
        }
        
        var pack: VipCenter.Pack {
            switch self {
            case .weekly: return .week
            case .monthly: return .month
            case .yearly: return .year
            }
        }
        
        var days: Int {
            switch self {
            case .weekly: return 7
            case .monthly: return 30
            case .yearly: return 365
            }
        }
    }
    
    @State private var selectedPlan: Plan = .monthly
    @State private var agreed: Bool = true
    
    var body: some View {
        ZStack {
            // 简洁渐变背景
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.12),
                    Color(red: 0.03, green: 0.03, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        planSection
                        benefitsSection
                        termsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 20)
                }
                
                VStack(spacing: 12) {
                    agreementSection
                    primaryButton
                    restoreButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            
            if vipCenter.isBusy {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text(LocalizedText("vip_processing"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.70))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle(LocalizedText("vip_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vipCenter.loadProducts()
            await vipCenter.refreshVipStatus()
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(vipCenter.hasVip ? "isVip" : "noVip")
                .resizable()
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(vipCenter.hasVip ? LocalizedText("vip_premium_active") : LocalizedText("vip_premium_membership"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                if let end = vipCenter.vipEndDate, vipCenter.hasVip {
                    Text(String(format: LocalizedText("vip_valid_until"), formatExpiry(end)))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text(LocalizedText("vip_unlock_description"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.06))
        )
    }
    
    private var planSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedText("vip_select_package"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                ForEach(Plan.allCases) { plan in
                    planCard(for: plan)
                }
            }
        }
    }
    
    private func planCard(for plan: Plan) -> some View {
        let isSelected = plan == selectedPlan
        let product = vipCenter.product(for: plan.pack)
        
        return Button {
            selectedPlan = plan
        } label: {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Color.accentColor : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected ? Color.white.opacity(0.8) : Color.white.opacity(0.18),
                                    lineWidth: isSelected ? 1.5 : 1)
                    )
                
                VStack(spacing: 10) {
                    Spacer().frame(height: 12)

                    Text(LocalizedText(plan.titleKey))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    
                    Text(product?.displayPrice ?? "--")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)
                    
                    Text(perDayText(product: product, days: plan.days) ?? "--/day")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                    
                    Spacer().frame(height: 10)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .scaleEffect(isSelected ? 1.03 : 1.0)
    }

    // 计算每天价格：尽量保持和 displayPrice 相同的货币符号与格式
    private func perDayText(product: Product?, days: Int) -> String? {
        guard let product, days > 0 else { return nil }
        
        let displayPrice = product.displayPrice
        
        // 优先从 displayPrice 中抽取货币符号和数字，保持与总价格式一致
        if let symbol = extractCurrencySymbol(from: displayPrice),
           let numberPart = extractNumberPart(from: displayPrice),
           let total = Double(numberPart.replacingOccurrences(of: ",", with: ".")) {
            
            let perDay = total / Double(days)
            if let formatted = formatPerDayPrice(perDay, currencySymbol: symbol, original: displayPrice) {
                return "\(formatted)/day"
            }
        }
        
        // 退化到使用 price + 当前 locale 货币格式
        let totalDecimal = NSDecimalNumber(decimal: product.price).doubleValue
        guard totalDecimal > 0 else { return nil }
        let perDay = totalDecimal / Double(days)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        if let s = formatter.string(from: NSNumber(value: perDay)) {
            return "\(s)/day"
        }
        return nil
    }
    
    private func extractCurrencySymbol(from price: String) -> String? {
        let cleaned = price.replacingOccurrences(of: "[0-9.,\\s]", with: "", options: .regularExpression)
        return cleaned.isEmpty ? nil : cleaned
    }
    
    private func extractNumberPart(from price: String) -> String? {
        let number = price.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
        return number.isEmpty ? nil : number
    }
    
    private func formatPerDayPrice(_ value: Double, currencySymbol: String, original: String) -> String? {
        let symbolAtPrefix = original.hasPrefix(currencySymbol)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        // 判断原字符串是用逗号还是点作为小数分隔符
        if original.contains(",") && !original.contains(".") {
            formatter.decimalSeparator = ","
            formatter.groupingSeparator = "."
        } else {
            formatter.decimalSeparator = "."
            formatter.groupingSeparator = ","
        }
        
        guard let numberString = formatter.string(from: NSNumber(value: value)) else {
            return nil
        }
        
        return symbolAtPrefix ? "\(currencySymbol)\(numberString)" : "\(numberString) \(currencySymbol)"
    }
    
    private func formatExpiry(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: date)
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedText("vip_privileges"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 10) {
                horizontalBenefitItem(
                    iconName: "vSpeed",
                    title: LocalizedText("vip_benefit_speed_title"),
                    description: LocalizedText("vip_benefit_speed_desc")
                )
                horizontalBenefitItem(
                    iconName: "vAd",
                    title: LocalizedText("vip_benefit_ad_title"),
                    description: LocalizedText("vip_benefit_ad_desc")
                )
                horizontalBenefitItem(
                    iconName: "vServer",
                    title: LocalizedText("vip_benefit_server_title"),
                    description: LocalizedText("vip_benefit_server_desc")
                )
            }
        }
    }
    
    private func horizontalBenefitItem(iconName: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(iconName)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedText("vip_terms_conditions"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            Text(LocalizedText("vip_terms_long"))
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var agreementSection: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                agreed.toggle()
            } label: {
                Image(systemName: agreed ? "checkmark.square.fill" : "square")
                    .foregroundColor(agreed ? .accentColor : .white.opacity(0.7))
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 2) {
                Text(LocalizedText("vip_agree_prefix"))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                Button {
                    openURL(Self.termsURL)
                } label: {
                    Text(LocalizedText("vip_auto_renewal_terms"))
                        .underline()
                        .foregroundColor(.accentColor)
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                Text(", ")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 10))
                Button {
                    openURL(Self.termsURL)
                } label: {
                    Text(LocalizedText("vip_membership_terms"))
                        .underline()
                        .foregroundColor(.accentColor)
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            
            Spacer(minLength: 0)
        }
    }
    
    private var primaryButton: some View {
        Button {
            Task {
                _ = await vipCenter.purchase(pack: selectedPlan.pack)
            }
        } label: {
            Text(LocalizedText("vip_agree_and_pay"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(agreed ? Color.accentColor : Color.white.opacity(0.15))
                )
        }
        .disabled(!agreed)
        .buttonStyle(.plain)
        .opacity(vipCenter.isBusy ? 0.7 : 1)
    }

    private var restoreButton: some View {
        Button {
            Task { await vipCenter.restore() }
        } label: {
            Text(LocalizedText("vip_restore_purchase"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SubscriptionView()
}

