//
//  ConnectionHistoryManager.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/9/19.
//

import Foundation

// MARK: - 连接记录
struct ConnectionRecord: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let server: String
    let success: Bool
    
    init(startTime: Date, endTime: Date? = nil, server: String, success: Bool) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime?.timeIntervalSince(startTime) ?? 0
        self.server = server
        self.success = success
    }
}

// MARK: - 连接历史管理器
class ConnectionHistoryManager: ObservableObject {
    static let shared = ConnectionHistoryManager()
    
    @Published var connectionHistory: [ConnectionRecord] = []
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "connectionHistory"
    private let maxHistoryCount = 100 // 最多保存100条记录
    
    private init() {
        loadHistory()
    }
    
    // MARK: - 记录连接开始
    func recordConnectionStart(server: String) {
        let record = ConnectionRecord(
            startTime: Date(),
            endTime: nil,
            server: server,
            success: false // 初始状态为失败，连接成功后更新
        )
        
        connectionHistory.insert(record, at: 0) // 插入到开头
        saveHistory()
    }
    
    // MARK: - 记录连接成功
    func recordConnectionSuccess() {
        guard !connectionHistory.isEmpty else { return }
        
        let startTime = connectionHistory[0].startTime
        let server = connectionHistory[0].server
        
        // 连接成功时，不记录结束时间，等待断开时记录
        let successRecord = ConnectionRecord(
            startTime: startTime,
            endTime: nil, // 不记录结束时间
            server: server,
            success: true
        )
        
        connectionHistory[0] = successRecord
        saveHistory()
    }
    
    // MARK: - 记录连接失败
    func recordConnectionFailure() {
        guard !connectionHistory.isEmpty else { return }
        
        let endTime = Date()
        let startTime = connectionHistory[0].startTime
        let server = connectionHistory[0].server
        
        let failureRecord = ConnectionRecord(
            startTime: startTime,
            endTime: endTime,
            server: server,
            success: false
        )
        
        connectionHistory[0] = failureRecord
        saveHistory()
    }
    
    // MARK: - 记录连接断开
    func recordConnectionDisconnect() {
        guard !connectionHistory.isEmpty else { return }
        
        // 如果当前记录还没有结束时间，记录断开时间
        if connectionHistory[0].endTime == nil {
            let endTime = Date()
            let startTime = connectionHistory[0].startTime
            let server = connectionHistory[0].server
            let success = connectionHistory[0].success
            
            let disconnectRecord = ConnectionRecord(
                startTime: startTime,
                endTime: endTime,
                server: server,
                success: success
            )
            
            connectionHistory[0] = disconnectRecord
            saveHistory()
        }
    }
    
    // MARK: - 删除单个记录
    func deleteRecord(id: UUID) {
        connectionHistory.removeAll { $0.id == id }
        saveHistory()
    }
    
    // MARK: - 清空历史
    func clearHistory() {
        connectionHistory.removeAll()
        saveHistory()
    }
    
    // MARK: - 获取统计信息
    func getStatistics() -> (totalConnections: Int, successfulConnections: Int, totalDuration: TimeInterval) {
        let total = connectionHistory.count
        let successful = connectionHistory.filter { $0.success }.count
        let totalDuration = connectionHistory.reduce(0) { $0 + $1.duration }
        
        return (total, successful, totalDuration)
    }
    
    // MARK: - 获取最常用的服务器
    func getMostUsedServer() -> String? {
        let serverCounts = Dictionary(grouping: connectionHistory.filter { $0.success }, by: { $0.server })
            .mapValues { $0.count }
        
        return serverCounts.max { $0.value < $1.value }?.key
    }
    
    // MARK: - 私有方法
    private func loadHistory() {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([ConnectionRecord].self, from: data) else {
            connectionHistory = []
            return
        }
        
        connectionHistory = history
    }
    
    private func saveHistory() {
        // 限制历史记录数量
        if connectionHistory.count > maxHistoryCount {
            connectionHistory = Array(connectionHistory.prefix(maxHistoryCount))
        }
        
        guard let data = try? JSONEncoder().encode(connectionHistory) else { return }
        userDefaults.set(data, forKey: historyKey)
    }
}
