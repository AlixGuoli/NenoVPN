//
//  ContentView.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/9/19.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @ObservedObject private var localeManager = LocaleDao.shared
    @EnvironmentObject private var globalConnectVM: ConnectVM

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // 主页
                HomeView(viewModel: globalConnectVM)
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text(LocalizedText("home"))
                    }
                    .tag(0)
                
                // 流量监控
                TrafficStatsView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text(LocalizedText("traffic_stats"))
                    }
                    .tag(1)
                
                // 连接历史
                HistoryView()
                    .tabItem {
                        Image(systemName: "clock.fill")
                        Text(LocalizedText("history"))
                    }
                    .tag(2)
                
                // 设置
                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text(LocalizedText("settings_title"))
                    }
                    .tag(3)
            }
            .accentColor(.accentColor)
            .environmentObject(globalConnectVM)
            .bindLocale()
            .navigationDestination(isPresented: $globalConnectVM.showConnectingView) {
                ConnectingView()
                    .environmentObject(globalConnectVM)
            }
            .navigationDestination(isPresented: $globalConnectVM.navigateToResult) {
                ResultView(resultType: globalConnectVM.resultType) {
                    globalConnectVM.closeResultPage()
                }
            }
            .overlay {
                if globalConnectVM.showDisconnectConfirm {
                    DisconnectConfirmView(
                        onConfirm: {
                            globalConnectVM.confirmDisconnect()
                        },
                        onCancel: {
                            globalConnectVM.cancelDisconnect()
                        }
                    )
                }
            }
            .alert(LocalizedText("no_network_title"), isPresented: $globalConnectVM.showNoNetworkAlert) {
                Button(LocalizedText("got_it")) {
                    globalConnectVM.showNoNetworkAlert = false
                }
            } message: {
                Text(LocalizedText("no_network_message"))
            }
            
        }
        .onChange(of: globalConnectVM.navigateToResult) { newValue in
            if newValue {
                globalConnectVM.showAdForResultIfNeeded()
            }
        }
    }
}

// MARK: - 主页视图
struct HomeView: View {
    @ObservedObject private var viewModel: ConnectVM
    @State private var showServers = false
    @ObservedObject private var localeManager = LocaleDao.shared
    @State private var isAnimating = false
    
    init(viewModel: ConnectVM) {
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack {
            // 自定义增强背景（双层网格 + 柔光Blob）
            EnhancedBackgroundView()
            
            ScrollView {
            VStack(spacing: 0) {
                // 顶部状态行
                HStack(spacing: 12) {
                    StatusCapsule(stage: viewModel.stage)
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)

                // 顶部入口行（服务器）
                CompactShortcutRow(
                    serversAction: { showServers = true },
                    settingsAction: { } // 移除设置入口，现在在Tab中
                )
                .onReceive(NotificationCenter.default.publisher(for: .selectedServerChanged)) { _ in
                    // 触发刷新以更新副标题
                }
                .padding(.top, 8)
                .padding(.horizontal, 24)
                
                 // （入口已移至顶部信息行）

                 // 中央连接区域
                VStack(spacing: 0) {
                    // 连接状态卡片
                        PremiumConnectionCard(
                            stage: viewModel.stage,
                            duration: viewModel.formattedDuration
                        )
                        
                        // 连接按钮
                        PremiumConnectionButton(
                            stage: viewModel.stage,
                            action: handleConnectionAction
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // 即时速率（上传/下载）卡片 - 仅在连接中模拟速率
                    ConnectionSpeedView(stage: viewModel.stage)
                        .frame(height: 64)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    
                    Spacer()
                    .padding(.bottom, 30)
                }
            }
            .fullScreenCover(isPresented: $showServers) {
                ServersView()
            }
             // toolbar 移除，入口改为快捷卡片
        }
        .bindLocale()
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private func handleConnectionAction() {
        switch viewModel.stage {
        case .disconnected, .failed:
            // 只调 beginSession；连接页在拿到权限后再由 VM 显示
            viewModel.beginSession()
        case .connected:
            viewModel.endSession()
        case .connecting:
            return
        }
    }
}

// MARK: - 高级暗色背景
struct PremiumDarkBackgroundView: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // 主背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.03, green: 0.03, blue: 0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 微妙的色彩点缀
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(0.03),
                    Color.clear
                ]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 200
            )
            .ignoresSafeArea()
            .scaleEffect(animateGradient ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateGradient)
            
            // 微妙的网格纹理
            GridPatternView()
        }
        .onAppear {
            animateGradient = true
        }
    }
}

// MARK: - 网格纹理
struct GridPatternView: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 40
            let lineWidth: CGFloat = 0.5
            
            // 垂直线
            for x in stride(from: 0, through: size.width, by: gridSize) {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(.white.opacity(0.02)),
                    lineWidth: lineWidth
                )
            }
            
            // 水平线
            for y in stride(from: 0, through: size.height, by: gridSize) {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.white.opacity(0.02)),
                    lineWidth: lineWidth
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 增强背景：双层网格 + 柔光Blob
struct EnhancedBackgroundView: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            PremiumDarkBackgroundView()
            // 大网格（更稀疏）
            Canvas { context, size in
                let gridSize: CGFloat = 80
                let lineWidth: CGFloat = 0.4
                for x in stride(from: 0, through: size.width, by: gridSize) {
                    context.stroke(Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    }, with: .color(.white.opacity(0.01)), lineWidth: lineWidth)
                }
                for y in stride(from: 0, through: size.height, by: gridSize) {
                    context.stroke(Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    }, with: .color(.white.opacity(0.01)), lineWidth: lineWidth)
                }
            }
            .ignoresSafeArea()

            // 柔光 Blob
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 320, height: 320)
                    .offset(x: animate ? -30 : 10, y: animate ? -20 : 20)
                    .blur(radius: 40)
                    .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: animate)
                Circle()
                    .fill(Color.blue.opacity(0.06))
                    .frame(width: 260, height: 260)
                    .offset(x: animate ? 40 : -10, y: animate ? 30 : -10)
                    .blur(radius: 50)
                    .animation(.easeInOut(duration: 16).repeatForever(autoreverses: true), value: animate)
            }
            .ignoresSafeArea()
        }
        .onAppear { animate = true }
    }
}

// MARK: - 状态胶囊
private struct StatusCapsule: View {
    let stage: ConnectVM.Stage
    @State private var pulse: CGFloat = 1.0
    @State private var flowPhase: CGFloat = 0
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulse)
                if stage == .connecting {
                    Circle()
                        .stroke(dotColor.opacity(0.7), lineWidth: 1)
                        .frame(width: 16, height: 16)
                        .opacity(Double(2 - pulse))
                }
            }
            Text(mainText)
                .font(.system(size: 15, weight: .semibold))
            
            Spacer(minLength: 0)
            
            Text(subText)
                .font(.system(size: 12))
                .opacity(0.7)
            
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [glowBgColor.opacity(0.22), glowBgColor.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentStrokeColor.opacity(0.38), lineWidth: 1)
        )
        // 连接中：描边流光
        .overlay(
            Group {
                if stage == .connecting {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [8, 12], dashPhase: flowPhase))
                        .foregroundColor(accentStrokeColor.opacity(0.7))
                }
            }
        )
        .shadow(color: accentStrokeColor.opacity(0.20), radius: 10, x: 0, y: 6)
        .onAppear {
            guard stage == .connecting else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = 1.5
            }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                flowPhase = -20
            }
        }
        .onChange(of: stage) { newStage in
            if newStage == .connecting {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = 1.5
                }
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    flowPhase = -20
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) { pulse = 1.0 }
                flowPhase = 0
            }
        }
    }
    private var iconName: String {
        switch stage {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "arrow.triangle.2.circlepath" 
        case .failed: return "xmark.octagon.fill"
        case .disconnected: return "circle.fill"
        }
    }
    private var mainText: String {
        switch stage {
        case .connected: return LocalizedText("connected_status")
        case .connecting: return LocalizedText("connecting_status")
        case .failed: return LocalizedText("failed_status")
        case .disconnected: return LocalizedText("disconnected_status")
        }
    }
    private var subText: String {
        switch stage {
        case .connected: return LocalizedText("status_protected")
        case .connecting: return LocalizedText("status_negotiating")
        case .failed: return LocalizedText("status_retry")
        case .disconnected: return LocalizedText("status_ready")
        }
    }
    private var bgColor: Color {
        switch stage {
        case .connected: return .green
        case .connecting: return .orange
        case .failed: return .red
        case .disconnected: return .white
        }
    }
    private var accentStrokeColor: Color {
        switch stage {
        case .connected: return .green
        case .connecting: return .accentColor
        case .failed: return .red
        case .disconnected: return .accentColor
        }
    }

    private var glowBgColor: Color {
        switch stage {
        case .connected: return .green
        case .connecting: return .accentColor
        case .failed: return .red
        case .disconnected: return .accentColor
        }
    }

    private var dotColor: Color {
        switch stage {
        case .connected: return .green
        case .connecting: return .accentColor
        case .failed: return .red
        case .disconnected: return .white.opacity(0.6)
        }
    }
}
// MARK: - 高级标题
struct PremiumTitleView: View {
    var body: some View {
        Text(LocalizedText("app_title"))
            .font(.system(size: 36, weight: .light, design: .default))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .white.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

// MARK: - 高级状态指示器
struct PremiumStatusIndicatorView: View {
    let stage: ConnectVM.Stage
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseScale)
                
                if stage == .connecting {
                    Circle()
                        .stroke(statusColor.opacity(0.6), lineWidth: 1)
                        .frame(width: 16, height: 16)
                        .scaleEffect(pulseScale * 1.3)
                        .opacity(2 - pulseScale)
                }
            }
            
            Text(statusText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .onAppear {
            if stage == .connecting {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.3
                }
            }
        }
        .onChange(of: stage) { newStage in
            if newStage == .connecting {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.3
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    pulseScale = 1.0
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch stage {
        case .connected: return .green
        case .connecting: return .accentColor
        case .failed: return .red
        case .disconnected: return .white.opacity(0.4)
        }
    }
    
    private var statusText: String {
        switch stage {
        case .disconnected: return LocalizedText("disconnected_status")
        case .connecting: return LocalizedText("connecting_status")
        case .connected: return LocalizedText("connected_status")
        case .failed: return LocalizedText("failed_status")
        }
    }
}

// MARK: - 高级连接卡片
struct PremiumConnectionCard: View {
    let stage: ConnectVM.Stage
    let duration: String
    @State private var rotationAngle: Double = 0
    @State private var orbitRotation: Double = 0
    @State private var flowPhase: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // 连接图标（增强：更大外圈 + 虚线轨道 + 内部毛玻璃）
            ZStack {
                // 背景柔光稍加强
                Circle()
                    .fill(statusColor.opacity(0.10))
                    .frame(width: 270, height: 270)
                    .blur(radius: 8)

                // 外环（更粗更大；未连接时提高对比度）
                Circle()
                    .stroke((stage == .disconnected ? Color.white.opacity(0.28) : statusColor.opacity(0.28)), lineWidth: 2)
                    .frame(width: 260, height: 260)
                
                // 状态卡片边框效果
                Circle()
                    .stroke(accentStrokeColor.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 260, height: 260)
                
                // 连接中：流光边框
                if stage == .connecting {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [12, 16], dashPhase: flowPhase))
                        .foregroundColor(accentStrokeColor)
                        .frame(width: 260, height: 260)
                        .shadow(color: accentStrokeColor.opacity(0.6), radius: 4, x: 0, y: 0)
                }

                // 虚线轨道（极慢旋转）
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                    .foregroundColor(Color.white.opacity(0.14))
                    .frame(width: 238, height: 238)
                    .rotationEffect(.degrees(orbitRotation))

                // 中心内容
                if stage == .connecting {
                    // 内圈毛玻璃焦点
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.35)
                        .frame(width: 140, height: 140)
                    
                    DualArcAnimation(color: statusColor)
                        .frame(width: 200, height: 200)
                } else {
                    Image(iconNameForCenter)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 140, height: 140)
                }
            }

            // 连接时间：固定高度 + 透明度，避免跳动
            VStack(spacing: 6) {
                Text(LocalizedText("connection_time"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text(duration)
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(height: 44)
            .opacity(stage == .connected ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: stage)
        }
        .padding(.vertical, 16)
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                orbitRotation = 360
            }
            // 流光边框动画
            if stage == .connecting {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    flowPhase = -20
                }
            }
        }
        .onChange(of: stage) { newStage in
            if newStage == .connecting {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    flowPhase = -20
                }
            } else {
                flowPhase = 0
            }
        }
    }
    
    private var iconName: String {
        switch stage {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .failed: return "xmark.circle.fill"
        case .disconnected: return "circle.dotted"
        }
    }
    
    private var iconNameForCenter: String {
        switch stage {
        case .connected: return "success"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .failed: return "failed"
        case .disconnected: return "defult"
        }
    }
    
    private var centerIconColor: Color {
        switch stage {
        case .connected: return .green
        case .connecting: return statusColor
        case .failed: return .red
        case .disconnected: return .white.opacity(0.7)
        }
    }
    
    private var statusColor: Color {
        switch stage {
        case .connected: return .green
        case .connecting: return .accentColor
        case .failed: return .red
        case .disconnected: return .white.opacity(0.3)
        }
    }
    
    private var accentStrokeColor: Color {
        switch stage {
        case .connected: return .green
        case .connecting: return .accentColor
        case .failed: return .red
        case .disconnected: return .accentColor
        }
    }
}

// MARK: - 高级连接动画
struct DualArcAnimation: View {
    let color: Color
    @State private var rotation: Double = 0
    @State private var pulse: CGFloat = 0.9

    var body: some View {
        ZStack {
            // 外弧
            Circle()
                .trim(from: 0.0, to: 0.22)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [color, color.opacity(0)]), center: .center),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))

            // 内弧（反向）
            Circle()
                .trim(from: 0.55, to: 0.77)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [color.opacity(0.8), color.opacity(0)]), center: .center),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-rotation * 0.8))

            // 中心呼吸光点
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 10, height: 10)
                .scaleEffect(pulse)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = 1.2
            }
        }
    }
}

// MARK: - 高级连接按钮
struct PremiumConnectionButton: View {
    let stage: ConnectVM.Stage
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
            action()
        }) {
            HStack(spacing: 16) {
                if stage == .connecting {
                    PremiumProgressView()
                }
                
                Text(buttonTitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: buttonGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [buttonColor.opacity(0.3), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .opacity(0.2)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .scaleEffect(stage == .connecting ? 0.99 : 1.0)
        }
        .disabled(stage == .connecting)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var buttonTitle: String {
        switch stage {
        case .disconnected, .failed: return LocalizedText("connect_button")
        case .connecting: return LocalizedText("connecting_status")
        case .connected: return LocalizedText("disconnect_button")
        }
    }
    
    private var buttonColor: Color {
        switch stage {
        case .connected: return .red
        case .connecting: return .accentColor
        case .failed: return .red
        case .disconnected: return .accentColor
        }
    }
    
    private var buttonGradientColors: [Color] {
        switch stage {
        case .connected: return [Color.red.opacity(0.8), Color.red.opacity(0.6)]
        case .connecting: return [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.6)]
        case .failed: return [Color.red.opacity(0.8), Color.red.opacity(0.6)]
        case .disconnected: return [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.6)]
        }
    }
}

// MARK: - 高级进度指示器
struct PremiumProgressView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 18, height: 18)
            
            Circle()
                .trim(from: 0, to: 0.6)
                .stroke(
                    LinearGradient(
                        colors: [.accentColor, .white.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 18, height: 18)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - 快捷入口卡片
private struct ShortcutCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.08)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.08)) { pressed = false }
            }
            onTap()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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

// MARK: - 紧凑型快捷入口行（铺满宽度的两卡：服务器/设置）
private struct CompactShortcutRow: View {
    let serversAction: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ServerWideCard(
                title: LocalizedText("servers_title"),
                subtitle: LocalizedText("servers_subtitle"),
                action: serversAction
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}

// 铺满宽度：服务器卡（带副标题）
private struct ServerWideCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var pressed = false
    @State private var currentSubtitle: String = ""

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.08)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.08)) { pressed = false }
            }
            action()
        }) {
            HStack(spacing: 12) {
                // 国旗
                Text(flagForSelected())
                    .font(.system(size: 20))
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    Text(currentSubtitle.isEmpty ? subtitle : currentSubtitle)
                        .font(.system(size: 12))
                        .opacity(0.65)
                }
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.02), Color.white.opacity(0.00)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor.opacity(0.32), lineWidth: 1)
            )
            .shadow(color: Color.accentColor.opacity(0.20), radius: 10, x: 0, y: 6)
            .overlay(
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.trailing, 12),
                alignment: .trailing
            )
            .scaleEffect(pressed ? 0.98 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear { updateSubtitle() }
        .onReceive(NotificationCenter.default.publisher(for: .selectedServerChanged)) { _ in
            updateSubtitle()
        }
    }

    private func updateSubtitle() {
        let code = UserDefaults.standard.string(forKey: "selectedServerCode") ?? "auto"
        currentSubtitle = displayName(for: code)
    }

    private func displayName(for code: String) -> String {
        switch code {
        case "auto": return LocalizedText("recommended")
        case "us": return "United States"
        case "uk": return "United Kingdom"
        case "sg": return "Singapore"
        case "jp": return "Japan"
        case "de": return "Germany"
        case "nl": return "Netherlands"
        case "ca": return "Canada"
        case "au": return "Australia"
        default: return LocalizedText("recommended")
        }
    }

    private func flagForSelected() -> String {
        let code = UserDefaults.standard.string(forKey: "selectedServerCode") ?? "auto"
        switch code {
        case "auto": return "🧭"
        case "us": return "🇺🇸"
        case "uk": return "🇬🇧"
        case "sg": return "🇸🇬"
        case "jp": return "🇯🇵"
        case "de": return "🇩🇪"
        case "nl": return "🇳🇱"
        case "ca": return "🇨🇦"
        case "au": return "🇦🇺"
        default: return "🧭"
        }
    }
}

// 铺满宽度：设置卡（仅标题，描边更明显以区分）
private struct SettingWideCard: View {
    let title: String
    let icon: String
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
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.98 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
private struct CapsuleShortcut: View {
    let icon: String
    let text: String
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
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(
                Capsule().fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 即时速率（模拟）
struct ConnectionSpeedView: View {
    let stage: ConnectVM.Stage
    @State private var uploadKbps: Int = 0
    @State private var downloadKbps: Int = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 12) {
            // 上传卡片
            SpeedTile(
                title: LocalizedText("upload"),
                value: formatted(uploadKbps),
                icon: "arrow.up.circle.fill",
                color: .orange
            )

            // 下载卡片
            SpeedTile(
                title: LocalizedText("download"),
                value: formatted(downloadKbps),
                icon: "arrow.down.circle.fill",
                color: .green
            )
        }
        .onAppear { schedule() }
        .onChange(of: stage) { _ in schedule() }
        .task(id: stage) { schedule() } // 再保险：状态变化必触发
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private func schedule() {
        timer?.invalidate(); timer = nil
        guard stage == .connected else {
            stopAndZero(); return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // 按网络类型设置合理范围（单位：KB/s）
            let network = NetworkMonitor.shared.trafficData.networkType
            let multiplier: Double
            switch network {
            case .wifi, .ethernet: multiplier = 1.0
            case .cellular: multiplier = 0.6
            default: multiplier = 0.8
            }

            // 已连接：更接近真实区间
            let upRange = Int(200 * multiplier)...Int(3000 * multiplier)    // 200~3000 KB/s
            let downRange = Int(500 * multiplier)...Int(12000 * multiplier) // 500~12000 KB/s

            let newUp = Int.random(in: upRange)
            let newDown = Int.random(in: downRange)

            // 指数平滑，避免跳变（0.6保留，0.4新值）
            uploadKbps = Int(0.6 * Double(uploadKbps) + 0.4 * Double(newUp))
            downloadKbps = Int(0.6 * Double(downloadKbps) + 0.4 * Double(newDown))
        }
    }

    private func stopAndZero() {
        timer?.invalidate(); timer = nil
        uploadKbps = 0
        downloadKbps = 0
    }

    private func formatted(_ kBps: Int) -> String {
        // 自适应单位：KB/s 或 MB/s（以字节为单位更贴近用户认知）
        if kBps >= 1024 {
            let mBps = Double(kBps) / 1024.0
            return String(format: "%.1f MB/s", mBps)
        }
        return "\(kBps) KB/s"
    }
}

private struct SpeedTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(ConnectVM())
}
