import SwiftUI

struct TrafficStatsView: View {
    @ObservedObject private var trafficManager = TrafficStatsManager.shared
    @ObservedObject private var localeManager = LocaleDao.shared
    @EnvironmentObject private var connectVM: ConnectVM
    @State private var selectedPeriod: TrafficPeriod = .today
    
    enum TrafficPeriod: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        
        var localized: String {
            switch self {
            case .today: return LocalizedText("today")
            case .week: return LocalizedText("this_week")
            case .month: return LocalizedText("this_month")
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 时间段选择器
                    PeriodSelector(selectedPeriod: $selectedPeriod)
                    
                    // 当前网络状态
                    CurrentNetworkCard()
                    
                    // 流量统计卡片
                    DetailedTrafficStatsCard(period: selectedPeriod)
                    
                    // 历史数据图表
                    TrafficHistoryChart(period: selectedPeriod)
                    
                    // 操作按钮
                    ActionButtons()
                    
                    // 准确性说明
                    AccuracyNotice()
                }
                .padding()
            }
            .navigationTitle(LocalizedText("traffic_stats"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .bindLocale()
    }
}

// MARK: - 时间段选择器
struct PeriodSelector: View {
    @Binding var selectedPeriod: TrafficStatsView.TrafficPeriod
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrafficStatsView.TrafficPeriod.allCases, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                }) {
                    Text(period.localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedPeriod == period ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedPeriod == period ? Color.accentColor : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - 当前网络状态卡片
struct CurrentNetworkCard: View {
    @ObservedObject private var trafficManager = TrafficStatsManager.shared
    @EnvironmentObject private var connectVM: ConnectVM
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: getVPNStatusIcon())
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(getVPNStatusColor())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedText("vpn_status"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(getVPNStatusText())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // 连接状态
                HStack(spacing: 6) {
                    Circle()
                        .fill(getVPNStatusColor())
                        .frame(width: 8, height: 8)
                    
                    Text(getVPNStatusSubText())
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
                                colors: [getVPNStatusColor().opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - VPN状态相关方法
    
    private func getVPNStatusIcon() -> String {
        switch connectVM.stage {
        case .connected: return "shield.checkered"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .failed: return "shield.slash"
        case .disconnected: return "shield"
        }
    }
    
    private func getVPNStatusColor() -> Color {
        switch connectVM.stage {
        case .connected: return .green
        case .connecting: return .orange
        case .failed: return .red
        case .disconnected: return .gray
        }
    }
    
    private func getVPNStatusText() -> String {
        switch connectVM.stage {
        case .connected: return LocalizedText("connected_status")
        case .connecting: return LocalizedText("connecting_status")
        case .failed: return LocalizedText("failed_status")
        case .disconnected: return LocalizedText("disconnected_status")
        }
    }
    
    private func getVPNStatusSubText() -> String {
        switch connectVM.stage {
        case .connected: return LocalizedText("status_protected")
        case .connecting: return LocalizedText("status_negotiating")
        case .failed: return LocalizedText("status_retry")
        case .disconnected: return LocalizedText("status_ready")
        }
    }
}

// MARK: - 详细流量统计卡片
struct DetailedTrafficStatsCard: View {
    let period: TrafficStatsView.TrafficPeriod
    @ObservedObject private var trafficManager = TrafficStatsManager.shared
    
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
            VStack(spacing: 12) {
                // WiFi流量
                TrafficRow(
                    type: .wifi,
                    usage: getWifiUsage(),
                    total: getTotalUsage()
                )
                
                // 蜂窝流量
                TrafficRow(
                    type: .cellular,
                    usage: getCellularUsage(),
                    total: getTotalUsage()
                )
                
                // VPN流量
                TrafficRow(
                    type: .vpn,
                    usage: getVPNUsage(),
                    total: getTotalUsage()
                )
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // 总计
                HStack {
                    Text(LocalizedText("total"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(getTotalUsage())
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
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
    
    private func getWifiUsage() -> String {
        switch period {
        case .today:
            return trafficManager.getTodayTraffic().formattedWifi
        case .week:
            return formatTotalUsage(trafficManager.getWeeklyTraffic().reduce(0) { $0 + $1.wifiBytes })
        case .month:
            return formatTotalUsage(trafficManager.getMonthlyTraffic().reduce(0) { $0 + $1.wifiBytes })
        }
    }
    
    private func getCellularUsage() -> String {
        switch period {
        case .today:
            return trafficManager.getTodayTraffic().formattedCellular
        case .week:
            return formatTotalUsage(trafficManager.getWeeklyTraffic().reduce(0) { $0 + $1.cellularBytes })
        case .month:
            return formatTotalUsage(trafficManager.getMonthlyTraffic().reduce(0) { $0 + $1.cellularBytes })
        }
    }
    
    private func getVPNUsage() -> String {
        switch period {
        case .today:
            return trafficManager.getTodayTraffic().formattedVPN
        case .week:
            return formatTotalUsage(trafficManager.getWeeklyTraffic().reduce(0) { $0 + $1.vpnBytes })
        case .month:
            return formatTotalUsage(trafficManager.getMonthlyTraffic().reduce(0) { $0 + $1.vpnBytes })
        }
    }
    
    private func getTotalUsage() -> String {
        switch period {
        case .today:
            return trafficManager.getTodayTraffic().formattedTotal
        case .week:
            return formatTotalUsage(trafficManager.getWeeklyTraffic().reduce(0) { $0 + $1.totalBytes })
        case .month:
            return formatTotalUsage(trafficManager.getMonthlyTraffic().reduce(0) { $0 + $1.totalBytes })
        }
    }
    
    private func formatTotalUsage(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - 流量行
struct TrafficRow: View {
    let type: TrafficType
    let usage: String
    let total: String
    
    var body: some View {
        HStack {
            Image(systemName: type.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(type.color)
                .frame(width: 20)
            
            Text(type.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(usage)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

// MARK: - 历史数据图表
struct TrafficHistoryChart: View {
    let period: TrafficStatsView.TrafficPeriod
    @ObservedObject private var trafficManager = TrafficStatsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedText("usage_history"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            // 简化的历史数据展示
            VStack(spacing: 8) {
                ForEach(getHistoryData().prefix(7), id: \.date) { data in
                    HistoryRow(data: data)
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
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func getHistoryData() -> [DailyTrafficData] {
        switch period {
        case .today:
            return [trafficManager.getTodayTraffic()]
        case .week:
            return trafficManager.getWeeklyTraffic()
        case .month:
            return trafficManager.getMonthlyTraffic()
        }
    }
}

// MARK: - 历史数据行
struct HistoryRow: View {
    let data: DailyTrafficData
    
    var body: some View {
        HStack {
            Text(formatDate(data.date))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            Text(data.formattedTotal)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - 操作按钮
struct ActionButtons: View {
    @ObservedObject private var trafficManager = TrafficStatsManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 模拟流量按钮
            Button(action: {
                trafficManager.simulateTrafficActivity()
            }) {
                Text(LocalizedText("simulate_traffic"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
            
            // 重置数据按钮
            Button(action: {
                trafficManager.resetAllData()
            }) {
                Text(LocalizedText("reset_all"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
            }
        }
    }
}

// MARK: - 准确性说明
struct AccuracyNotice: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                
                Text(LocalizedText("accuracy_notice"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
            }
            
            Text(LocalizedText("accuracy_description"))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    TrafficStatsView()
        .background(Color.black)
}
