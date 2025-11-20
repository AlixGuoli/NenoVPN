import SwiftUI

struct ReturnLaunchView: View {
    @ObservedObject private var localeManager = LocaleDao.shared
    let onShowAd: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // 黑色背景
            Color(uiColor: UIColor.systemBackground)
                .ignoresSafeArea()
            
            // 背景渐变
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.95),
                    Color.accentColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 微妙的网格纹理
            GridPatternView()
                .opacity(0.3)
            
            // 动态背景光点
            FloatingLightsView()
            
            VStack(spacing: 40) {
                Spacer()
                
                // 应用图标和名称
                VStack(spacing: 24) {
                    // 应用图标
                    ZStack {
                        // 外圈发光效果
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 120, height: 120)
                            .blur(radius: 8)

                        // 主图标（使用 Assets 中的 logo，带圆角）
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
                    }
                    
                    // 应用名称
                    VStack(spacing: 8) {
                        Text(LocalizedText("app_title"))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(LocalizedText("launch_subtitle"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
            }
        }
        .bindLocale()
        .onAppear {
            // 2秒后展示广告
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onShowAd()
            }
            
            // 3秒后自动关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                onComplete()
            }
        }
    }
}

