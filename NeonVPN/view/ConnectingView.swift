import SwiftUI

struct ConnectingView: View {
    @EnvironmentObject private var connectVM: ConnectVM
    @ObservedObject private var localeManager = LocaleDao.shared
    @State private var animationPhase: Double = 0
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationTimer: Timer?
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.15),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 浮动光点背景
            FloatingLightsView()
            
            VStack(spacing: 32) {
                Spacer()
                
                // 连接动画区域
                VStack(spacing: 24) {
                    // 主图标和动画
                    ZStack {
                        // 背景光晕（呼吸效果）
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.25),
                                        Color.accentColor.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .scaleEffect(pulseScale)
                            .opacity(0.6 + sin(animationPhase * 0.8) * 0.2)
                        
                        // 外圈静态边框
                        Circle()
                            .stroke(
                                Color.accentColor.opacity(0.2),
                                lineWidth: 2
                            )
                            .frame(width: 180, height: 180)
                        
                        // 外弧旋转动画
                        Circle()
                            .trim(from: 0.0, to: 0.25)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.accentColor,
                                        Color.accentColor.opacity(0.3),
                                        Color.accentColor.opacity(0)
                                    ]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(rotationAngle))
                            .shadow(color: Color.accentColor.opacity(0.5), radius: 8, x: 0, y: 0)
                        
                        // 内弧反向旋转
                        Circle()
                            .trim(from: 0.5, to: 0.75)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.accentColor.opacity(0.8),
                                        Color.accentColor.opacity(0.2),
                                        Color.accentColor.opacity(0)
                                    ]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(-rotationAngle * 0.8))
                        
                        // 中心毛玻璃效果
                        Circle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.4)
                            .frame(width: 100, height: 100)
                        
                        // 中心图标（带脉冲效果）
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.accentColor)
                            .scaleEffect(1.0 + sin(animationPhase * 1.2) * 0.08)
                    }
                    
                    // 状态文本
                    VStack(spacing: 12) {
                        Text(LocalizedText("connecting_status"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(LocalizedText("connecting_page_subtitle"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
            }
            
            // 关闭按钮（X图标）- 右上角
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        connectVM.closeConnectingView()
                        // 如果正在连接，取消连接
                        if connectVM.stage == .connecting {
                            connectVM.endSession()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .bindLocale()
        .transaction { transaction in
            transaction.animation = nil
        }
        .onAppear {
            // 启动动画
            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                animationPhase += 0.08
            }
            
            // 旋转动画（使用 Timer 手动更新，绕过 transaction 限制）
            rotationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                rotationAngle += 360.0 / (1.6 * 60.0) // 1.6秒转360度，60fps
                if rotationAngle >= 360 {
                    rotationAngle = 0
                }
            }
            
            // 脉冲动画（更柔和）
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.12
            }
        }
        .onDisappear {
            // 清理旋转定时器，避免内存泄漏
            rotationTimer?.invalidate()
            rotationTimer = nil
        }
    }
}

#Preview {
    ConnectingView()
        .environmentObject(ConnectVM())
}
