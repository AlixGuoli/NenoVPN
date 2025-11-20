import SwiftUI

struct ResultView: View {
    let resultType: ConnectVM.ResultType
    let onClose: () -> Void
    
    private var isSuccess: Bool {
        resultType == .success
    }
    
    private var isDisconnected: Bool {
        resultType == .disconnected
    }
    @ObservedObject private var localeManager = LocaleDao.shared
    @EnvironmentObject private var connectVM: ConnectVM
    @State private var animationPhase: Double = 0
    @State private var showDetails = false
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: getGradientColors(),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 浮动光点背景
            FloatingLightsView()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)
                    
                    // 主要状态区域
                    VStack(spacing: 20) {
                        // 状态图标
                        ZStack {
                            // 背景光晕
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            getStatusColor().opacity(0.3),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .scaleEffect(1.0 + sin(animationPhase * 1) * 0.03)
                                .opacity(0.4 + sin(animationPhase * 0.8) * 0.2)
                            
                            // 主图标
                            Image(getStatusIcon())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                        }
                        
                        // 状态文本
                        VStack(spacing: 8) {
                            Text(getStatusTitle())
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(getStatusSubtitle())
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // 连接信息卡片
                    ConnectionInfoCard(success: isSuccess)
                    
                    // 操作建议卡片
                    ActionSuggestionCard(success: isSuccess)
                    
                    // 关闭按钮
                    Button(action: onClose) {
                        Text(LocalizedText("got_it"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [.accentColor, .accentColor.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarBackButtonHidden()
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: onClose) {
//                    HStack(spacing: 6) {
//                        Image(systemName: "chevron.left")
//                            .font(.system(size: 16, weight: .medium))
//                        Text(LocalizedText("back"))
//                            .font(.system(size: 16, weight: .medium))
//                    }
//                    .foregroundColor(.white.opacity(0.8))
//                }
//            }
//        }
        .bindLocale()
        .onAppear {
            // 启动动画
            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                animationPhase += 0.1
            }
            
            // 延迟显示详细信息
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    showDetails = true
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func getGradientColors() -> [Color] {
        switch resultType {
        case .success:
            return [Color.green.opacity(0.1), Color.black]
        case .failed:
            return [Color.red.opacity(0.1), Color.black]
        case .disconnected:
            return [Color.blue.opacity(0.1), Color.black]
        }
    }
    
    private func getStatusColor() -> Color {
        switch resultType {
        case .success:
            return Color.green
        case .failed:
            return Color.red
        case .disconnected:
            return Color.blue
        }
    }
    
    private func getStatusIcon() -> String {
        switch resultType {
        case .success:
            return "success"
        case .failed:
            return "failed"
        case .disconnected:
            return "success" // 使用成功图标，或者可以添加新的断开图标
        }
    }
    
    private func getStatusTitle() -> String {
        switch resultType {
        case .success:
            return LocalizedText("connection_success")
        case .failed:
            return LocalizedText("connection_failed")
        case .disconnected:
            return LocalizedText("disconnect_success_title")
        }
    }
    
    private func getStatusSubtitle() -> String {
        switch resultType {
        case .success:
            return LocalizedText("success_subtitle")
        case .failed:
            return LocalizedText("failed_subtitle")
        case .disconnected:
            return LocalizedText("disconnect_success_subtitle")
        }
    }
}

// MARK: - 连接信息卡片
struct ConnectionInfoCard: View {
    let success: Bool
    @EnvironmentObject private var connectVM: ConnectVM
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                
                Text(LocalizedText("connection_info"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                InfoRow(
                    icon: "globe",
                    title: LocalizedText("server_location"),
                    value: getServerLocation()
                )
                
                if success {
                    InfoRow(
                        icon: "shield.checkered",
                        title: LocalizedText("protection_status"),
                        value: LocalizedText("active")
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.accentColor.opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func getServerLocation() -> String {
        let code = UserDefaults.standard.string(forKey: "selectedServerCode") ?? "auto"
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

// MARK: - 信息行
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - 操作建议卡片
struct ActionSuggestionCard: View {
    let success: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: success ? "lightbulb.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(success ? .yellow : .orange)
                
                Text(success ? LocalizedText("suggestions") : LocalizedText("troubleshooting"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if success {
                    SuggestionItem(text: LocalizedText("suggestion_1"))
                    SuggestionItem(text: LocalizedText("suggestion_2"))
                } else {
                    SuggestionItem(text: LocalizedText("troubleshoot_1"))
                    SuggestionItem(text: LocalizedText("troubleshoot_2"))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [(success ? Color.green : Color.orange).opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 建议项
struct SuggestionItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.leading)
        }
    }
}




