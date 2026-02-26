//
//  ConnectionBuilder.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//


import Foundation

import CryptoKit
import Network

class ConnectionBuilder {
    
    static let instance = ConnectionBuilder()
    
    func storeGroupConfig(serviceConfig: String) async throws {
        debugPrint("[CONFIG] [Builder] 开始处理连接配置")
        
        let transformedPayload = applyConfigTransform(serviceConfig) ?? serviceConfig
        await writeToStorage(transformedPayload)
        
        debugPrint("[CONFIG] [Builder] 保存配置到 Group UserDefaults")
        debugPrint("[CONFIG] [Builder] 最终配置: \(transformedPayload)")
        debugPrint("[CONFIG] [Builder] 配置处理完成")
    }
    
    // MARK: - 配置处理管道
    
    private func applyConfigTransform(_ inputString: String) -> String? {
        guard let configDict = deserializeJson(inputString) else { return nil }
        let modifiedPayload = adjustInboundSettings(configDict)
        let enrichedPayload = applyRoutingEnhancement(modifiedPayload)
        return stringifyConfig(enrichedPayload)
    }
    
    // MARK: - 配置解析和序列化
    
    private func deserializeJson(_ inputString: String) -> [String: Any]? {
        guard let rawData = inputString.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: rawData, options: [])) as? [String: Any]
    }
    
    private func stringifyConfig(_ configDict: [String: Any]) -> String? {
        guard let rawData = try? JSONSerialization.data(withJSONObject: configDict, options: .prettyPrinted) else { return nil }
        return String(data: rawData, encoding: .utf8)
    }
    
    // MARK: - 入站配置更新
    
    private func adjustInboundSettings(_ configDict: [String: Any]) -> [String: Any] {
        var modifiedPayload = configDict
        guard var inboundArray = modifiedPayload["inbounds"] as? [[String: Any]],
              var primaryEntry = inboundArray.first else { return modifiedPayload }
        
        primaryEntry["listen"] = "[::1]"
        primaryEntry["port"] = "8080"
        inboundArray[0] = primaryEntry
        modifiedPayload["inbounds"] = inboundArray
        
        return modifiedPayload
    }
    
    // MARK: - 路由配置增强
    
    private func applyRoutingEnhancement(_ configDict: [String: Any]) -> [String: Any] {
        let enrichedPayload = configDict
        let directHostList = collectAllDirectDomains()
        return buildAndInjectRules(into: enrichedPayload, hosts: directHostList)
    }
    
    // MARK: - 域名收集
    
    private func collectAllDirectDomains() -> [String] {
        var hostCollection: [String] = []
        
        // 固定域名（含 Yandex 广告直连）
        hostCollection.append(contentsOf: [
            "yastatic", "yandex", "yandex.ru", "yandexadexchange.net", "ads.adfox.ru", "appmetrica.yandex.ru",
            "gameanalytics", "mradx.net", "target.my.com", "vk.ru", "vk.me", "vk.com", "mail.ru"
        ])
        
        // 动态域名
        let sourcePayload = SourceVault.shared.load() ?? SourceVault.shared.ensure()
        debugPrint("[CONFIG] [Builder] 获取 host 配置: \(sourcePayload != nil ? "成功" : "失败")")
        
        // 提取各种动态域名
        if let connectionHost = extractConnectionHost(from: sourcePayload) {
            hostCollection.append(connectionHost)
        }
        
        if let reportHost = extractReportHost(from: sourcePayload) {
            hostCollection.append(reportHost)
        }
        
        let endpointHosts = extractEndpointHosts(from: sourcePayload)
        hostCollection.append(contentsOf: endpointHosts)
        
        debugPrint("[CONFIG] [Builder] 收集域名总数: \(hostCollection.count)")
        return hostCollection
    }
    
    private func extractConnectionHost(from sourcePayload: String?) -> String? {
        guard let sourcePayload, let connectionEndpoint = SourceVault.shared.connectionUrl(from: sourcePayload) else {
            debugPrint("[CONFIG] [Builder] 未获取到 connection URL")
            return nil
        }
        
        debugPrint("[CONFIG] [Builder] Connection URL: \(connectionEndpoint)")
        guard let connectionHostname = URL(string: connectionEndpoint)?.host else {
            debugPrint("[CONFIG] [Builder] 无法解析 connection 域名: \(connectionEndpoint)")
            return nil
        }
        
        debugPrint("[CONFIG] [Builder] 添加 connection 域名: \(connectionHostname)")
        return connectionHostname
    }
    
    private func extractReportHost(from sourcePayload: String?) -> String? {
        guard let sourcePayload, let reportEndpoint = SourceVault.shared.reportUrl(from: sourcePayload) else {
            debugPrint("[CONFIG] [Builder] 未获取到 report URL")
            return nil
        }
        
        debugPrint("[CONFIG] [Builder] Report URL: \(reportEndpoint)")
        guard let reportHostname = URL(string: reportEndpoint)?.host else {
            debugPrint("[CONFIG] [Builder] 无法解析 report 域名: \(reportEndpoint)")
            return nil
        }
        
        debugPrint("[CONFIG] [Builder] 添加 report 域名: \(reportHostname)")
        return reportHostname
    }
    
    private func extractEndpointHosts(from sourcePayload: String?) -> [String] {
        guard let sourcePayload, !sourcePayload.isEmpty else {
            debugPrint("[CONFIG] [Builder] 未获取到 endpoint 列表")
            return []
        }
        
        let endpointList = SourceVault.shared.endpoints(from: sourcePayload)
        debugPrint("[CONFIG] [Builder] Endpoint 列表数量: \(endpointList.count)")
            let extractedHostnames = endpointList.compactMap { URL(string: $0)?.host }
        debugPrint("[CONFIG] [Builder] 提取 endpoint 域名: \(extractedHostnames.count) 个")
        return extractedHostnames
    }
    
    // MARK: - 规则构建和注入
    
    private func buildAndInjectRules(into configDict: [String: Any], hosts: [String]) -> [String: Any] {
        debugPrint("[CONFIG] [Builder] 开始构建路由规则")
        var ruleArray: [[String: Any]] = []
        
        // 固定规则：raw.githubusercontent.com 单独处理
        ruleArray.append([
            "type": "field",
            "domain": ["raw.githubusercontent.com"],
            "outboundTag": "direct"
        ])
        debugPrint("[CONFIG] [Builder] 添加固定规则: raw.githubusercontent.com")
        
        // 动态规则：其他域名
        if !hosts.isEmpty {
            ruleArray.append([
                "type": "field",
                "domain": hosts,
                "outboundTag": "direct"
            ])
            debugPrint("[CONFIG] [Builder] 添加动态规则: \(hosts.count) 个域名")
        } else {
            debugPrint("[CONFIG] [Builder] 无动态域名，跳过动态规则")
        }
        
        debugPrint("[CONFIG] [Builder] 规则总数: \(ruleArray.count)")
        
        // 注入规则到配置
        var finalPayload = configDict
        
        if finalPayload["routing"] == nil {
            finalPayload["routing"] = [
                "domainStrategy": "AsIs",
                "rules": ruleArray
            ]
            debugPrint("[CONFIG] [Builder] 创建新的 routing 配置")
        } else if var routingSection = finalPayload["routing"] as? [String: Any] {
            routingSection["rules"] = ruleArray
            finalPayload["routing"] = routingSection
            debugPrint("[CONFIG] [Builder] 更新现有 routing 配置")
        }
        
        debugPrint("[CONFIG] [Builder] 路由规则注入完成")
        return finalPayload
    }
    
    // MARK: - 配置持久化
    
    private func writeToStorage(_ configString: String) async {
        let userDefaults = UserDefaults(suiteName: RouterConf.routerGroupId)
        userDefaults?.set(Date(), forKey: RouterConf.routerTimestamp)
        userDefaults?.set(configString, forKey: RouterConf.routerConfigKey)
        userDefaults?.synchronize()
    }
}
