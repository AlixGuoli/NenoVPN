import Foundation
import Network
import SwiftUI

// 网络类型枚举
enum NetworkType: String, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case other = "Other"
    case none = "No Connection"
    
    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .other: return "network"
        case .none: return "wifi.slash"
        }
    }
    
    var color: Color {
        switch self {
        case .wifi: return .green
        case .cellular: return .blue
        case .ethernet: return .purple
        case .other: return .orange
        case .none: return .red
        }
    }
}

// 流量数据模型
struct TrafficData {
    var networkType: NetworkType = .none
    var isConnected: Bool = false
    var connectionStartTime: Date?
    var estimatedDataUsage: Int64 = 0 // 字节
    var connectionDuration: TimeInterval = 0
    
    var formattedDataUsage: String {
        return formatBytes(estimatedDataUsage)
    }
    
    var formattedDuration: String {
        return formatDuration(connectionDuration)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// 网络监控器
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var trafficData = TrafficData()
    @Published var isMonitoring = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var timer: Timer?
    private let dataUsageKey = "estimatedDataUsage"
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path: path)
            }
        }
        monitor.start(queue: queue)
        
        // 启动定时器更新流量估算
        startTrafficEstimation()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        monitor.cancel()
        timer?.invalidate()
        timer = nil
    }
    
    func startVPNConnection() {
        trafficData.connectionStartTime = Date()
        UserDefaults.standard.set(trafficData.connectionStartTime, forKey: "vpnConnectionStartTime")
    }
    
    func stopVPNConnection() {
        trafficData.connectionStartTime = nil
        UserDefaults.standard.removeObject(forKey: "vpnConnectionStartTime")
        saveDataUsage()
    }
    
    // MARK: - Private Methods
    
    private func updateNetworkStatus(path: NWPath) {
        let oldType = trafficData.networkType
        let oldConnected = trafficData.isConnected
        
        // 更新网络类型
        if path.usesInterfaceType(.wifi) {
            trafficData.networkType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            trafficData.networkType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            trafficData.networkType = .ethernet
        } else if path.status == .satisfied {
            trafficData.networkType = .other
        } else {
            trafficData.networkType = .none
        }
        
        // 更新连接状态
        trafficData.isConnected = path.status == .satisfied
        
        // 如果网络类型或连接状态改变，记录日志
        if oldType != trafficData.networkType || oldConnected != trafficData.isConnected {
            debugPrint("Network changed: \(oldType.rawValue) -> \(trafficData.networkType.rawValue), Connected: \(trafficData.isConnected)")
        }
    }
    
    private func startTrafficEstimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTrafficEstimation()
        }
        
        // 恢复VPN连接时间（如果存在）
        if let savedTime = UserDefaults.standard.object(forKey: "vpnConnectionStartTime") as? Date {
            trafficData.connectionStartTime = savedTime
        }
        
        // 恢复数据使用量
        trafficData.estimatedDataUsage = Int64(UserDefaults.standard.double(forKey: dataUsageKey))
    }
    
    private func updateTrafficEstimation() {
        guard let startTime = trafficData.connectionStartTime else { return }
        
        // 更新连接时长
        trafficData.connectionDuration = Date().timeIntervalSince(startTime)
        
        // 更合理的流量估算：只在连接初期给予一个基础估算
        // 避免持续累加造成的"假流量"
        if trafficData.estimatedDataUsage == 0 {
            // 连接建立时的初始估算（基于网络类型）
            let initialEstimate = getInitialTrafficEstimate()
            trafficData.estimatedDataUsage = initialEstimate
        }
        // 后续不再自动累加，等待实际流量数据
    }
    
    private func getInitialTrafficEstimate() -> Int64 {
        // 连接建立时的初始流量估算（字节）
        switch trafficData.networkType {
        case .wifi:
            return 50 * 1024 // 50KB 初始连接开销
        case .cellular:
            return 30 * 1024 // 30KB 初始连接开销
        case .ethernet:
            return 100 * 1024 // 100KB 初始连接开销
        case .other:
            return 20 * 1024 // 20KB 初始连接开销
        case .none:
            return 0
        }
    }
    
    private func getEstimatedSpeed() -> Double {
        // 改为更保守的估算，只在有实际活动时计算
        // 这里返回一个基础的最小值，实际流量应该通过其他方式获取
        return 0 // 暂时设为0，避免无意义的累加
    }
    
    private func saveDataUsage() {
        UserDefaults.standard.set(Double(trafficData.estimatedDataUsage), forKey: dataUsageKey)
    }
    
    // MARK: - Data Management
    
    func resetDataUsage() {
        trafficData.estimatedDataUsage = 0
        UserDefaults.standard.removeObject(forKey: dataUsageKey)
    }
    
    func getDailyDataUsage() -> Int64 {
        // 这里可以实现更复杂的日统计逻辑
        // 目前返回当前会话的估算数据
        return trafficData.estimatedDataUsage
    }
    
    // 手动添加流量（用于测试或实际流量统计）
    func addTrafficUsage(_ bytes: Int64) {
        trafficData.estimatedDataUsage += bytes
        saveDataUsage()
    }
    
    // 模拟网络活动（用于演示）
    func simulateNetworkActivity() {
        // 模拟一些网络活动，增加少量流量
        let simulatedBytes = Int64.random(in: 1024...10240) // 1KB-10KB
        addTrafficUsage(simulatedBytes)
    }
}
