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
                
                // 页面内容
                TabView(selection: $currentPage) {
                    // 页面1：网络权限
                    NetworkPermissionPage(
                        hasPermission: $hasNetworkPermission,
                        onNext: { 
                            if hasNetworkPermission {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    currentPage = 1
                                }
                            }
                        }
                    )
                    .tag(0)
                    
                    // 页面2：用户协议
                    TermsAgreementPage(
                        hasAgreed: $hasAgreedToTerms,
                        onNext: { 
                            if hasAgreedToTerms {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    currentPage = 2
                                }
                            }
                        }
                    )
                    .tag(1)
                    
                    // 页面3：完成
                    CompletionPage(
                        onComplete: {
                            isComplete = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                onboardingManager.completeOnboarding()
                            }
                        }
                    )
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.5), value: currentPage)
            }
        }
        .onAppear {
            // 移除自动检测网络权限
        }
    }
    
}

// MARK: - 网络权限页面
struct NetworkPermissionPage: View {
    @Binding var hasPermission: Bool
    let onNext: () -> Void
    @ObservedObject private var localeManager = LocaleDao.shared
    
    private func requestNetworkPermission() {
        // 模拟网络权限请求
        // 在实际应用中，这里会触发系统的网络权限请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            hasPermission = true
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
                Text(LocalizedText("grant_permission"))
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
