import SwiftUI

struct TrafficMonitorView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var localeManager = LocaleDao.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // 网络状态卡片
            NetworkStatusCard()
            
            // 流量统计卡片
            TrafficStatsCard()
        }
        .bindLocale()
    }
}

// MARK: - 网络状态卡片
struct NetworkStatusCard: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: networkMonitor.trafficData.networkType.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(networkMonitor.trafficData.networkType.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedText("network_type"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(networkMonitor.trafficData.networkType.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // 连接状态指示器
                HStack(spacing: 6) {
                    Circle()
                        .fill(networkMonitor.trafficData.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    Text(networkMonitor.trafficData.isConnected ? 
                         LocalizedText("connected") : LocalizedText("disconnected"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [networkMonitor.trafficData.networkType.color.opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 流量统计卡片
struct TrafficStatsCard: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                
                Text(LocalizedText("data_usage"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // 流量统计
            HStack(spacing: 20) {
                // 数据使用量
                VStack(spacing: 4) {
                    Text(LocalizedText("data_used"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(networkMonitor.trafficData.formattedDataUsage)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                // 连接时长
                VStack(spacing: 4) {
                    Text(LocalizedText("connection_time"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(networkMonitor.trafficData.formattedDuration)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                if networkMonitor.trafficData.estimatedDataUsage > 0 {
                    Button(action: {
                        networkMonitor.resetDataUsage()
                    }) {
                        Text(LocalizedText("reset_data"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
                
                // 模拟网络活动按钮（用于测试）
                Button(action: {
                    networkMonitor.simulateNetworkActivity()
                }) {
                    Text(LocalizedText("simulate_activity"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.accentColor.opacity(0.2), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 简化版流量监控视图（用于主界面）
struct CompactTrafficView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // 网络类型
            HStack(spacing: 6) {
                Image(systemName: networkMonitor.trafficData.networkType.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(networkMonitor.trafficData.networkType.color)
                
                Text(networkMonitor.trafficData.networkType.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // 数据使用量
            if networkMonitor.trafficData.estimatedDataUsage > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                    
                    Text(networkMonitor.trafficData.formattedDataUsage)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        TrafficMonitorView()
        CompactTrafficView()
    }
    .padding()
    .background(Color.black)
}
