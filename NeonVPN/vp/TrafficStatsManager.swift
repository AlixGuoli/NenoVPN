import Foundation
import Network
import SwiftUI

// 流量统计数据类型
enum TrafficType: String, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case vpn = "VPN"
    
    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .vpn: return "shield.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .wifi: return .green
        case .cellular: return .blue
        case .vpn: return .purple
        }
    }
}

// 单日流量数据
struct DailyTrafficData {
    let date: Date
    var wifiBytes: Int64 = 0
    var cellularBytes: Int64 = 0
    var vpnBytes: Int64 = 0
    
    var totalBytes: Int64 {
        return wifiBytes + cellularBytes + vpnBytes
    }
    
    var formattedWifi: String {
        return formatBytes(wifiBytes)
    }
    
    var formattedCellular: String {
        return formatBytes(cellularBytes)
    }
    
    var formattedVPN: String {
        return formatBytes(vpnBytes)
    }
    
    var formattedTotal: String {
        return formatBytes(totalBytes)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// 流量统计管理器
final class TrafficStatsManager: ObservableObject {
    static let shared = TrafficStatsManager()
    
    @Published var currentNetworkType: NetworkType = .none
    @Published var dailyData: [DailyTrafficData] = []
    @Published var isMonitoring = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "TrafficStatsManager")
    private var currentDayData: DailyTrafficData?
    private let userDefaults = UserDefaults.standard
    private let dailyDataKey = "dailyTrafficData"
    
    private init() {
        loadDailyData()
        startNetworkMonitoring()
        setupCurrentDayData()
        
        // 监听VPN连接状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onVPNStatusChanged),
            name: .NEVPNStatusDidChange,
            object: nil
        )
    }
    
    deinit {
        monitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    func startNetworkMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkType(path: path)
            }
        }
        monitor.start(queue: queue)
    }
    
    func addTrafficUsage(_ bytes: Int64, type: TrafficType) {
        guard var dayData = currentDayData else { return }
        
        switch type {
        case .wifi:
            dayData.wifiBytes += bytes
        case .cellular:
            dayData.cellularBytes += bytes
        case .vpn:
            dayData.vpnBytes += bytes
        }
        
        currentDayData = dayData
        updateDailyData(dayData)
    }
    
    func getTodayTraffic() -> DailyTrafficData {
        return currentDayData ?? DailyTrafficData(date: Date())
    }
    
    func getWeeklyTraffic() -> [DailyTrafficData] {
        let calendar = Calendar.current
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        
        return dailyData.filter { data in
            data.date >= weekAgo
        }.sorted { $0.date > $1.date }
    }
    
    func getMonthlyTraffic() -> [DailyTrafficData] {
        let calendar = Calendar.current
        let today = Date()
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today) ?? today
        
        return dailyData.filter { data in
            data.date >= monthAgo
        }.sorted { $0.date > $1.date }
    }
    
    func resetAllData() {
        dailyData.removeAll()
        currentDayData = DailyTrafficData(date: Date())
        saveDailyData()
    }
    
    // MARK: - Private Methods
    
    private func updateNetworkType(path: NWPath) {
        let oldType = currentNetworkType
        
        if path.usesInterfaceType(.wifi) {
            currentNetworkType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            currentNetworkType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            currentNetworkType = .ethernet
        } else if path.status == .satisfied {
            currentNetworkType = .other
        } else {
            currentNetworkType = .none
        }
        
        if oldType != currentNetworkType {
            debugPrint("Network type changed: \(oldType.rawValue) -> \(currentNetworkType.rawValue)")
        }
    }
    
    private func setupCurrentDayData() {
        let today = Calendar.current.startOfDay(for: Date())
        
        // 查找今天的数据
        if let existingData = dailyData.first(where: { 
            Calendar.current.isDate($0.date, inSameDayAs: today) 
        }) {
            currentDayData = existingData
        } else {
            // 创建新的今日数据
            currentDayData = DailyTrafficData(date: today)
            dailyData.append(currentDayData!)
            saveDailyData()
        }
    }
    
    private func updateDailyData(_ data: DailyTrafficData) {
        // 更新或添加今日数据
        if let index = dailyData.firstIndex(where: { 
            Calendar.current.isDate($0.date, inSameDayAs: data.date) 
        }) {
            dailyData[index] = data
        } else {
            dailyData.append(data)
        }
        
        saveDailyData()
    }
    
    private func loadDailyData() {
        if let data = userDefaults.data(forKey: dailyDataKey),
           let decoded = try? JSONDecoder().decode([DailyTrafficData].self, from: data) {
            dailyData = decoded
        }
    }
    
    private func saveDailyData() {
        if let encoded = try? JSONEncoder().encode(dailyData) {
            userDefaults.set(encoded, forKey: dailyDataKey)
        }
    }
    
    // MARK: - VPN状态监听
    
    @objc private func onVPNStatusChanged() {
        // 这里可以添加VPN状态变化时的处理逻辑
        // 比如记录VPN连接/断开的时间等
    }
    
    // MARK: - 更真实的流量监控
    
    func simulateTrafficActivity() {
        guard let dayData = currentDayData else { return }
        
        // 基于网络类型的更真实估算
        let baseBytes = getRealisticTrafficEstimate()
        addTrafficUsage(baseBytes, type: getCurrentTrafficType())
    }
    
    func simulateVPNTraffic() {
        // VPN连接时的真实流量估算（包括握手、加密等开销）
        let vpnBytes = Int64.random(in: 1024 * 1024 * 1...1024 * 1024 * 5) // 1MB-5MB VPN流量
        addTrafficUsage(vpnBytes, type: .vpn)
    }
    
    private func getRealisticTrafficEstimate() -> Int64 {
        // 基于网络类型和时间的更真实估算
        let timeOfDay = Calendar.current.component(.hour, from: Date())
        let baseMultiplier: Double
        
        // 根据时间段调整流量估算
        switch timeOfDay {
        case 6...11:   // 上午
            baseMultiplier = 1.2
        case 12...17:  // 下午
            baseMultiplier = 1.5
        case 18...22:  // 晚上
            baseMultiplier = 1.8
        default:       // 深夜/凌晨
            baseMultiplier = 0.3
        }
        
        // 基于网络类型的基础流量（合理的数值）
        let baseBytes: Int64
        switch currentNetworkType {
        case .wifi:
            baseBytes = Int64(1024 * 1024 * Int64(2 * baseMultiplier)) // 2MB基础
        case .cellular:
            baseBytes = Int64(1024 * 1024 * Int64(1 * baseMultiplier)) // 1MB基础
        case .ethernet:
            baseBytes = Int64(1024 * 1024 * Int64(3 * baseMultiplier)) // 3MB基础
        default:
            baseBytes = Int64(1024 * 1024 * Int64(0.5 * baseMultiplier)) // 0.5MB基础
        }
        
        return baseBytes
    }
    
    private func getCurrentTrafficType() -> TrafficType {
        switch currentNetworkType {
        case .wifi:
            return .wifi
        case .cellular:
            return .cellular
        default:
            return .wifi // 默认归类为WiFi
        }
    }
    
    // 添加基于实际网络活动的流量监控
    func recordNetworkActivity(bytes: Int64) {
        addTrafficUsage(bytes, type: getCurrentTrafficType())
    }
    
    // 获取更准确的流量统计信息
    func getAccurateTrafficInfo() -> String {
        let today = getTodayTraffic()
        let wifiMB = Double(today.wifiBytes) / (1024 * 1024)
        let cellularMB = Double(today.cellularBytes) / (1024 * 1024)
        let vpnMB = Double(today.vpnBytes) / (1024 * 1024)
        
        return String(format: "WiFi: %.2fMB, 蜂窝: %.2fMB, VPN: %.2fMB", wifiMB, cellularMB, vpnMB)
    }
}

// 让DailyTrafficData支持Codable
extension DailyTrafficData: Codable {
    enum CodingKeys: String, CodingKey {
        case date, wifiBytes, cellularBytes, vpnBytes
    }
}
