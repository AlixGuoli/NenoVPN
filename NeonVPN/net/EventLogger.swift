//
//  EventLogger.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/20.
//

import Foundation

final class EventLogger {
    
    static let shared = EventLogger()
    private init() {}
    
    // MARK: - Constants
    private static let requestTimeout: TimeInterval = 15
    private static let deviceModel = "iPhone"
    
    // MARK: - Helper Methods
    
    private func formatEventLabel(_ moment: String) -> String {
        switch moment {
        case NetProfile.EventKeys.KEY_START: return "开始连接"
        case NetProfile.EventKeys.KEY_SUCCESS: return "连接成功"
        case NetProfile.EventKeys.KEY_FAIL: return "连接失败"
        case NetProfile.EventKeys.KEY_DISCONNECT: return "断开连接"
        default: return moment
        }
    }
    
    private func formatAdLabel(_ moment: String) -> String {
        switch moment {
        case NetProfile.EventKeys.KEY_AD_START: return "开始加载广告"
        case NetProfile.EventKeys.KEY_AD_SUCCESS: return "广告加载成功"
        case NetProfile.EventKeys.KEY_AD_SHOW: return "展示广告"
        default: return moment
        }
    }
    
    private func createRequestTag(_ message: String) -> String {
        // 从 message 中提取关键信息作为标识
        let parts = message.split(separator: ",")
        if parts.isEmpty { return "Unknown" }
        
        let eventType = String(parts[0])
        
        // 根据事件类型提取不同的标识
        if eventType == NetProfile.EventKeys.KEY_START || eventType == NetProfile.EventKeys.KEY_SUCCESS || eventType == NetProfile.EventKeys.KEY_FAIL || eventType == NetProfile.EventKeys.KEY_DISCONNECT {
            // Connect 事件：提取时间戳部分
            if parts.count > 1 {
                let code = String(parts[1])
                // 提取时间戳（前 10 位）
                if code.count >= 10 {
                    let timestamp = String(code.prefix(10))
                    return "Connect:\(timestamp)"
                }
                return "Connect:\(code.prefix(8))"
            }
            return "Connect"
        } else if eventType == NetProfile.EventKeys.KEY_AD_START || eventType == NetProfile.EventKeys.KEY_AD_SUCCESS || eventType == NetProfile.EventKeys.KEY_AD_SHOW {
            // Ad 事件：提取 moment 和 key
            var id = "Ad:\(eventType)"
            if parts.count > 1 {
                let moment = String(parts[1])
                id += ":\(moment)"
            }
            if parts.count > 4, let key = parts.last {
                let keyStr = String(key)
                if !keyStr.isEmpty && keyStr != "empty" {
                    // 只取 key 的最后一部分
                    let keyParts = keyStr.split(separator: "/")
                    if let lastPart = keyParts.last {
                        id += ":...\(lastPart)"
                    }
                }
            }
            return id
        }
        
        return eventType
    }
    
    private func getCurrentIP() -> String {
        if ConnectionStatusCenter.shared.isConnected {
            if let ip = ServiceVault.shared.ipService, !ip.isEmpty {
                return ip
            }
            return "0.0.0.0"
        }
        return "local"
    }
    
    private func getTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMddHHmmss"
        return formatter.string(from: Date())
    }
    
    static func createSessionId() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).description
    }
    
    // MARK: - Helpers
    private enum RequestType {
        case status
        case log
    }
    
    private static func constructURL(
        endpoint: String,
        message: String,
        type: RequestType
    ) -> String? {
        let baseURL: String
        switch type {
        case .status:
            baseURL = endpoint + "/report_total"
        case .log:
            baseURL = endpoint
        }
        
        guard var components = URLComponents(string: baseURL) else {
            return nil
        }
        
        components.queryItems = type == .status
        ? buildStatusQuery(value: message)
        : buildLogQuery(message: message)
        
        return components.url?.absoluteString
    }
    
    private static func buildStatusQuery(value: String) -> [URLQueryItem] {
        let profile = NetProfile.shared
        return [
            URLQueryItem(name: "name", value: "getService"),
            URLQueryItem(name: "cty", value: profile.region),
            URLQueryItem(name: "pk", value: profile.packageId),
            URLQueryItem(name: "v", value: profile.ver),
            URLQueryItem(name: "asn", value: "0"),
            URLQueryItem(name: "isf", value: value),
            URLQueryItem(name: "cnt", value: "1")
        ]
    }
    
    private static func buildLogQuery(message: String) -> [URLQueryItem] {
        let profile = NetProfile.shared
        return [
            URLQueryItem(name: "imei", value: profile.deviceKey),
            URLQueryItem(name: "country", value: profile.region),
            URLQueryItem(name: "lang", value: profile.locale),
            URLQueryItem(name: "mobile", value: deviceModel),
            URLQueryItem(name: "pk", value: profile.packageId),
            URLQueryItem(name: "version", value: profile.ver),
            URLQueryItem(name: "info", value: message)
        ]
    }
    
    private static func executeRequest(urlString: String, messageId: String) async {
        guard let url = URL(string: urlString) else {
            debugPrint("[REPORT] [\(messageId)] 无效的 URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        let start = Date()
        debugPrint("[REPORT] [\(messageId)] → 发送请求 | \(urlString)")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let duration = Date().timeIntervalSince(start)
            if let http = response as? HTTPURLResponse,
               200..<300 ~= http.statusCode {
                debugPrint("[REPORT] [\(messageId)] ✓ 成功 | 状态码: \(http.statusCode) | 耗时: \(String(format: "%.2f", duration))s")
            } else if let http = response as? HTTPURLResponse {
                debugPrint("[REPORT] [\(messageId)] ✗ 失败 | 状态码: \(http.statusCode) | 耗时: \(String(format: "%.2f", duration))s")
            }
        } catch {
            let duration = Date().timeIntervalSince(start)
            debugPrint("[REPORT] [\(messageId)] ✗ 错误 | \(error.localizedDescription) | 耗时: \(String(format: "%.2f", duration))s")
        }
    }
    
    // MARK: - Connect Reports
    func logConnection(moment: String, ip: String? = nil, sid: String? = nil) {
        let timestamp = getTimestamp()
        let session = sid ?? ""
        let code = "\(timestamp)-\(session)"
        
        let message: String
        switch moment {
        case NetProfile.EventKeys.KEY_START:
            message = "\(NetProfile.EventKeys.KEY_START),\(code),0.0.0.0"
        case NetProfile.EventKeys.KEY_FAIL:
            message = "\(NetProfile.EventKeys.KEY_FAIL),\(code),\(ip ?? "0.0.0.0")"
        case NetProfile.EventKeys.KEY_SUCCESS:
            message = "\(NetProfile.EventKeys.KEY_SUCCESS),0,\(code),\(ip ?? "0.0.0.0")"
        case NetProfile.EventKeys.KEY_DISCONNECT:
            message = "\(NetProfile.EventKeys.KEY_DISCONNECT),\(code),\(ip ?? "0.0.0.0")"
        default:
            debugPrint("[REPORT] [Connect] 未知事件类型: \(moment)")
            return
        }
        
        let eventName = formatEventLabel(moment)
        if let sid = sid, !sid.isEmpty {
            debugPrint("[REPORT] [Connect] \(eventName) | IP: \(ip ?? "0.0.0.0") | SID: \(sid)")
        } else {
            debugPrint("[REPORT] [Connect] \(eventName) | IP: \(ip ?? "0.0.0.0")")
        }
        submitLog(message: message)
    }
    
    // MARK: - Ad Reports
    func logAdvertisement(moment: String, key: String? = nil, adMoment: String? = nil) {
        let ip = getCurrentIP()
        let momentValue = adMoment ?? ""
        
        let message: String
        switch moment {
        case NetProfile.EventKeys.KEY_AD_START:
            message = "\(NetProfile.EventKeys.KEY_AD_START),\(momentValue),\(ip),ad"
        case NetProfile.EventKeys.KEY_AD_SUCCESS:
            message = "\(NetProfile.EventKeys.KEY_AD_SUCCESS),\(momentValue),\(ip),ad,\(key ?? "")"
        case NetProfile.EventKeys.KEY_AD_SHOW:
            message = "\(NetProfile.EventKeys.KEY_AD_SHOW),\(momentValue),\(ip),ad,\(key ?? "empty")"
        default:
            debugPrint("[REPORT] [Ad] 未知事件类型: \(moment)")
            return
        }
        
        let eventName = formatAdLabel(moment)
        var logMsg = "[REPORT] [Ad] \(eventName)"
        if let momentValue = adMoment, !momentValue.isEmpty {
            logMsg += " | Moment: \(momentValue)"
        }
        if let adKey = key, !adKey.isEmpty {
            let keyParts = adKey.split(separator: "/")
            if let lastPart = keyParts.last {
                logMsg += " | Key: .../\(lastPart)"
            } else {
                logMsg += " | Key: \(adKey)"
            }
        }
        logMsg += " | IP: \(ip)"
        debugPrint(logMsg)
        submitLog(message: message)
    }
    
    // MARK: - Status Reports
    func logServiceStatus(success: Bool) {
        Task.detached { [statusURL = self.getStatusURL()] in
            guard let endpoint = statusURL else {
                debugPrint("[REPORT] [Status] 无状态上报端点")
                return
            }
            
            let statusCode = success ? "0" : "1"
            let statusText = success ? "成功" : "失败"
            debugPrint("[REPORT] [Status] 服务配置获取: \(statusText)")
            
            guard let url = Self.constructURL(
                endpoint: endpoint,
                message: statusCode,
                type: .status
            ) else {
                debugPrint("[REPORT] [Status] 无效的 URL")
                return
            }
            
            let messageId = "[Status:\(statusCode)]"
            await Self.executeRequest(urlString: url, messageId: messageId)
        }
    }
    
    // MARK: - Private Send
    private func submitLog(message: String) {
        let messageId = createRequestTag(message)
        
        Task.detached { [logURL = self.getLogURL(), msgId = messageId] in
            guard let endpoint = logURL else {
                debugPrint("[REPORT] [Log] 无日志上报端点")
                return
            }
            
            guard let url = Self.constructURL(
                endpoint: endpoint,
                message: message,
                type: .log
            ) else {
                debugPrint("[REPORT] [Log] 无效的 URL")
                return
            }
            
            await Self.executeRequest(urlString: url, messageId: msgId)
        }
    }
    
    private func getStatusURL() -> String? {
        if let config = SourceVault.shared.load() ?? SourceVault.shared.ensure() {
            return SourceVault.shared.reportUrl(from: config)
        }
        return nil
    }
    
    private func getLogURL() -> String? {
        if let config = SourceVault.shared.load() ?? SourceVault.shared.ensure() {
            return SourceVault.shared.connectionUrl(from: config)
        }
        return nil
    }
}

