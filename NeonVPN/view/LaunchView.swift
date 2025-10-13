import SwiftUI

struct LaunchView: View {
    @State private var progress: Double = 0
    @State private var isComplete = false
    @ObservedObject private var localeManager = LocaleDao.shared
    
    var body: some View {
        ZStack {
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
                        
                        // 主图标
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.accentColor.opacity(0.4), Color.accentColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle()
                                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 2)
                            )
                        
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.accentColor)
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
                
                // 进度条和百分比
                VStack(spacing: 20) {
                    // 进度条
                    VStack(spacing: 12) {
                        HStack {
                            Text(LocalizedText("loading"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("\(Int(progress))%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                        
                        // 进度条背景
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)
                            
                            // 进度条填充
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: CGFloat(progress) * 2.8, height: 6) // 280px max width
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
            }
        }
        .onAppear {
            startLoading()
        }
    }
    
    private func startLoading() {
        // 3秒内从0到100
        let duration: TimeInterval = 3.0
        let steps = 100
        let stepDuration = duration / Double(steps)
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    progress = Double(i)
                }
                
                if i == steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isComplete = true
                    }
                }
            }
        }
    }
}

// MARK: - 浮动光点背景
struct FloatingLightsView: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.accentColor.opacity(0.6), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .scaleEffect(animate ? 1.2 : 0.8)
                        .opacity(animate ? 0.3 : 0.1)
                        .animation(
                            .easeInOut(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: true),
                            value: animate
                        )
                }
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - 启动页管理器
class LaunchManager: ObservableObject {
    @Published var isLaunching = true
    
    func completeLaunch() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isLaunching = false
        }
    }
}

#Preview {
    LaunchView()
}
