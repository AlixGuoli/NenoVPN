import SwiftUI

private struct AppMeta {
    // 获取App版本号
    static func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

struct SettingsView: View {
    @ObservedObject private var localeManager = LocaleDao.shared
    @State private var showLanguageSettings = false
    @State private var showAbout = false
    @State private var showVip = false
    @EnvironmentObject private var vipCenter: VipCenter
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // 顶部应用信息卡片
                        AppInfoCard()
                        
                        // 设置项
                        LazyVStack(spacing: 16) {
                            // Vip 状态
                            SettingsCard(
                                icon: "crown.fill",
                                title: LocalizedText("vip_title"),
                                subtitle: vipCenter.hasVip
                                    ? String(format: LocalizedText("vip_active_until"), formatVipExpiry(vipCenter.vipEndDate))
                                    : LocalizedText("vip_not_subscribed"),
                                action: { showVip = true }
                            )
                            
                            // 语言设置
                            SettingsCard(
                                icon: "globe",
                                title: LocalizedText("language_settings"),
                                subtitle: LocalizedText("change_language"),
                                action: { showLanguageSettings = true }
                            )
                            
                            // 隐私政策
                            SettingsCard(
                                icon: "hand.raised.fill",
                                title: LocalizedText("privacy_policy"),
                                subtitle: LocalizedText("privacy_policy_subtitle"),
                                action: { openURL("https://keyvpntwo.xyz/p.html") }
                            )
                            
                            // 服务条款
                            SettingsCard(
                                icon: "doc.text.fill",
                                title: LocalizedText("terms_of_use"),
                                subtitle: LocalizedText("terms_of_use_subtitle"),
                                action: { openURL("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") }
                            )
                            
                            // 关于
                            SettingsCard(
                                icon: "info.circle",
                                title: LocalizedText("about"),
                                subtitle: LocalizedText("app_info"),
                                action: { showAbout = true }
                            )
                        }
                        
                        // 底部安全信息
                        VStack(spacing: 12) {
                            Text(LocalizedText("secure_connection"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack(spacing: 6) {
                                Image(systemName: "shield.checkered")
                                    .foregroundColor(.accentColor)
                                Text(LocalizedText("encrypted"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(LocalizedText("settings_title"))
            .navigationBarTitleDisplayMode(.inline)
                    .fullScreenCover(isPresented: $showLanguageSettings) {
                        LanguageSettingsView()
                    }
                    .fullScreenCover(isPresented: $showAbout) {
                        AboutView()
                    }
                    .navigationDestination(isPresented: $showVip) {
                        SubscriptionView()
                    }
        }
        .bindLocale()
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func formatVipExpiry(_ date: Date?) -> String {
        guard let date else { return LocalizedText("vip_not_subscribed") }
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: date)
    }
}

// MARK: - 应用信息卡片
struct AppInfoCard: View {
    @ObservedObject private var localeManager = LocaleDao.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // 应用图标（使用 Assets 中的 logo）
            Image("logo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
            
            // 应用名称和版本
            VStack(spacing: 4) {
                Text(LocalizedText("app_title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(LocalizedText("version")) \(AppMeta.getAppVersion())")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// MARK: - 设置卡片
struct SettingsCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var pressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.08)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.08)) { pressed = false }
            }
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .scaleEffect(pressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 关于页面
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localeManager = LocaleDao.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 应用图标和名称
                        VStack(spacing: 16) {
                            Image("logo")
                                .resizable()
                                .renderingMode(.original)
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                )
                                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 5)
                            
                            VStack(spacing: 4) {
                                Text(LocalizedText("app_title"))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("\(LocalizedText("version")) \(AppMeta.getAppVersion())")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.top, 20)
                        
                        // 应用描述
                        VStack(spacing: 16) {
                            Text(LocalizedText("about_description"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                            
                            Text(LocalizedText("about_features"))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                        .padding(.horizontal, 20)
                        
                        // 技术信息
                        VStack(spacing: 12) {
                            AboutInfoRow(title: LocalizedText("developer"), value: "Independent Developer")
                            AboutInfoRow(title: LocalizedText("platform"), value: "iOS")
                            AboutInfoRow(title: LocalizedText("framework"), value: "SwiftUI")
                            AboutInfoRow(title: LocalizedText("build_date"), value: "2025")
                            
                            // 官网链接
                            Button(action: {
                                if let url = URL(string: "https://keyvpntwo.xyz") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Text(LocalizedText("official_website"))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 16))
                                        .foregroundColor(.accentColor)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 版权信息
                        VStack(spacing: 8) {
                            Text("© 2025 Independent Developer")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(LocalizedText("all_rights_reserved"))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(LocalizedText("about"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedText("done")) {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
        .bindLocale()
    }
}

// MARK: - 关于信息行
struct AboutInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack { SettingsView() }
}

