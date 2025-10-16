import SwiftUI
import Network

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var hasNetworkPermission = false
    @State private var hasAgreedToTerms = false
    @State private var isComplete = false
    @ObservedObject private var localeManager = LocaleDao.shared
    @ObservedObject var onboardingManager: OnboardingManager
    
    private let totalPages = 3
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()
            
            // 微妙的网格纹理
            GridPatternView()
                .opacity(0.2)
            
            VStack(spacing: 0) {
                // 顶部进度指示器
                HStack {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index <= currentPage ? Color.accentColor : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
                
                // 页面内容（自定义切换动画，无滑动）
                ZStack {
                    if currentPage == 0 {
                        PrivacyProtectionPage(
                            hasAgreed: $hasAgreedToTerms,
                            onNext: {
                                if hasAgreedToTerms {
                                    withAnimation(.easeInOut(duration: 0.35)) { currentPage = 1 }
                                }
                            },
                            onboardingManager: onboardingManager
                        )
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                    if currentPage == 1 {
                        NetworkPermissionPage(
                            hasPermission: $hasNetworkPermission,
                            onNext: {
                                if hasNetworkPermission {
                                    withAnimation(.easeInOut(duration: 0.35)) { currentPage = 2 }
                                }
                            }
                        )
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                    if currentPage == 2 {
                        CompletionPage(
                            onComplete: {
                                isComplete = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onboardingManager.completeOnboarding()
                                }
                            }
                        )
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                }
            }
        }
        .bindLocale()
        .onAppear {
            // 移除自动检测网络权限
        }
    }
    
}

// MARK: - 隐私保护与数据使用声明页面
struct PrivacyProtectionPage: View {
    @Binding var hasAgreed: Bool
    let onNext: () -> Void
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject private var localeManager = LocaleDao.shared
    @State private var isRequesting = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 标题区域
                VStack(spacing: 12) {
                    Text(LocalizedText("privacy_protection_title"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Text(LocalizedText("privacy_protection_preamble"))
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // 内容区域
                ScrollView {
                    VStack(spacing: 16) {
                        // 数据收集说明
                        VStack(spacing: 12) {
                            PrivacyInfoRow(
                                title: LocalizedText("privacy_info_title"),
                                content: LocalizedText("privacy_info_body")
                            )
                            
                            PrivacyInfoRow(
                                title: LocalizedText("privacy_records_title"),
                                content: LocalizedText("privacy_records_body")
                            )
                            
                            PrivacyInfoRow(
                                title: LocalizedText("privacy_duration_title"),
                                content: LocalizedText("privacy_duration_body")
                            )
                            
                            PrivacyInfoRow(
                                title: LocalizedText("privacy_adservice_title"),
                                content: LocalizedText("privacy_adservice_body")
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        // 隐私政策链接
                        HStack {
                            Text(LocalizedText("privacy_policy_footer"))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Button(action: {
                                if let url = URL(string: "https://keyvpntwo.xyz/p.html") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text(LocalizedText("privacy_policy_link"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.accentColor)
                                    .underline()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 20)
                }
                .frame(maxHeight: geometry.size.height * 0.5)
                
                Spacer()
                
                // 底部操作区域
                VStack(spacing: 16) {
                    // 同意选项
                    HStack(spacing: 12) {
                        Button(action: {
                            hasAgreed.toggle()
                        }) {
                            Image(systemName: hasAgreed ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(hasAgreed ? .accentColor : .white.opacity(0.6))
                        }
                        
                        Text(LocalizedText("agree_to_privacy"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    
                    // 按钮组
                    VStack(spacing: 12) {
                        // 接受并继续按钮
                        Button(action: {
                            if hasAgreed {
                                isRequesting = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isRequesting = false
                                    onNext()
                                }
                            }
                        }) {
                            HStack {
                                if isRequesting {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                }
                                Text(LocalizedText("accept_continue"))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(hasAgreed ? Color.accentColor : Color.white.opacity(0.2))
                            )
                        }
                        .disabled(!hasAgreed || isRequesting)
                        
                        // 暂不按钮
                        Button(action: {
                            exit(0)
                        }) {
                            Text(LocalizedText("not_now"))
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - 隐私信息行
struct PrivacyInfoRow: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - 网络权限页面
struct NetworkPermissionPage: View {
    @Binding var hasPermission: Bool
    let onNext: () -> Void
    @ObservedObject private var localeManager = LocaleDao.shared
    @State private var isRequesting = false
    
    private func requestNetworkPermission() {
        // 防止重复点击
        guard !isRequesting else { return }
        isRequesting = true
        
        // 模拟网络权限请求
        // 在实际应用中，这里会触发系统的网络权限请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            hasPermission = true
            isRequesting = false
            onNext()
        }
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "wifi")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            // 内容
            VStack(spacing: 20) {
                Text(LocalizedText("network_permission_title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(LocalizedText("network_permission_description"))
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // 按钮
            Button(action: {
                requestNetworkPermission()
            }) {
                HStack {
                    if isRequesting {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text(LocalizedText("grant_permission"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isRequesting ? Color.accentColor.opacity(0.7) : Color.accentColor)
                )
            }
            .disabled(isRequesting)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - 用户协议页面
struct TermsAgreementPage: View {
    @Binding var hasAgreed: Bool
    let onNext: () -> Void
    @ObservedObject private var localeManager = LocaleDao.shared
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "doc.text")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            // 内容
            VStack(spacing: 20) {
                Text(LocalizedText("terms_title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedText("terms_content_1"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(LocalizedText("terms_content_2"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(LocalizedText("terms_content_3"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(LocalizedText("terms_content_4"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: 200)
            }
            
            Spacer()
            
            // 同意选项和按钮
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Button(action: {
                        hasAgreed.toggle()
                    }) {
                        Image(systemName: hasAgreed ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20))
                            .foregroundColor(hasAgreed ? .accentColor : .white.opacity(0.6))
                    }
                    
                    Text(LocalizedText("agree_to_terms"))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                
                Button(action: {
                    if hasAgreed {
                        onNext()
                    }
                }) {
                    Text(LocalizedText("continue"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(hasAgreed ? Color.accentColor : Color.white.opacity(0.2))
                        )
                }
                .disabled(!hasAgreed)
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
        }
    }
}

// MARK: - 完成页面
struct CompletionPage: View {
    let onComplete: () -> Void
    @ObservedObject private var localeManager = LocaleDao.shared
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.green)
            }
            
            // 内容
            VStack(spacing: 20) {
                Text(LocalizedText("setup_complete"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(LocalizedText("welcome_message"))
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // 开始使用按钮
            Button(action: {
                onComplete()
            }) {
                Text(LocalizedText("start_using"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - 引导管理器
class OnboardingManager: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView(onboardingManager: OnboardingManager())
}
