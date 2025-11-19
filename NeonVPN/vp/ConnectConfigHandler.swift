//
//  ConnectConfigHandler.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//


import Foundation

import CryptoKit
import Network

class ConnectConfigHandler {
    
    static let shared = ConnectConfigHandler()
    
    func savedGroupServiceConfig(serviceConfig: String) async throws {
        debugPrint("[直连配置] === 开始处理连接配置 ===")
        
        let processedConfig = processConfigurationPipeline(serviceConfig) ?? serviceConfig
        await persistConfiguration(processedConfig)
        
        debugPrint("[直连配置] Save Connect Config to Group UserDefaults ** ⬇️")
        debugPrint("[直连配置] 最终配置: \(processedConfig)")
    }
    
    // MARK: - 配置处理管道
    
    private func processConfigurationPipeline(_ jsonString: String) -> String? {
        guard let config = parseConfigurationData(jsonString) else { return nil }
        let updatedConfig = updateInboundConfiguration(config)
        let enhancedConfig = enhanceRoutingConfiguration(updatedConfig)
        return serializeConfiguration(enhancedConfig)
    }
    
    // MARK: - 配置解析和序列化
    
    private func parseConfigurationData(_ jsonString: String) -> [String: Any]? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: jsonData, options: [])) as? [String: Any]
    }
    
    private func serializeConfiguration(_ config: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
    
    // MARK: - 入站配置更新
    
    private func updateInboundConfiguration(_ config: [String: Any]) -> [String: Any] {
        var updatedConfig = config
        guard var inbounds = updatedConfig["inbounds"] as? [[String: Any]],
              var firstInbound = inbounds.first else { return updatedConfig }
        
        firstInbound["listen"] = "[::1]"
        firstInbound["port"] = "8080"
        inbounds[0] = firstInbound
        updatedConfig["inbounds"] = inbounds
        
        return updatedConfig
    }
    
    // MARK: - 路由配置增强
    
    private func enhanceRoutingConfiguration(_ config: [String: Any]) -> [String: Any] {
        let enhancedConfig = config
        let bypassDomains = collectBypassDomains()
        let routingRules = constructRoutingRules(bypassDomains)
        return mergeRoutingConfiguration(enhancedConfig, rules: routingRules)
    }
    
    private func collectBypassDomains() -> [String] {
        var domains: [String] = []
        
        // 固定域名
        domains.append(contentsOf: ["yastatic","yandex","gameanalytics","mradx.net","target.my.com","vk.ru","vk.me","vk.com","mail.ru"])
        
        // 动态域名
        let hostConfig = SourceVault.shared.load() ?? SourceVault.shared.ensure()
        domains.append(contentsOf: extractDynamicDomains(from: hostConfig))
        
        return domains
    }
    
    private func extractDynamicDomains(from hostConfig: String?) -> [String] {
        var domains: [String] = []
        
        debugPrint("[直连配置] 获取到的host配置: \(hostConfig ?? "nil")")
        
        // 获取 connReport 域名
        if let hostConfig, let connReport = SourceVault.shared.connectionUrl(from: hostConfig) {
            debugPrint("[直连配置] connReport: \(connReport)")
            if let connHost = URL(string: connReport)?.host {
                domains.append(connHost)
                debugPrint("[直连配置] 添加 connReport 域名到直连: \(connHost)")
            } else {
                debugPrint("[直连配置] !!! 无法解析 connReport 域名: \(connReport)")
            }
        } else {
            debugPrint("[直连配置] !!! 未获取到 connReport")
        }
        
        // 获取 genReport 域名
        if let hostConfig, let genReport = SourceVault.shared.reportUrl(from: hostConfig) {
            debugPrint("[直连配置] genReport: \(genReport)")
            if let genHost = URL(string: genReport)?.host {
                domains.append(genHost)
                debugPrint("[直连配置] 添加 genReport 域名到直连: \(genHost)")
            } else {
                debugPrint("[直连配置] !!! 无法解析 genReport 域名: \(genReport)")
            }
        } else {
            debugPrint("[直连配置] !!! 未获取到 genReport")
        }
        
        // 获取 hostList 域名
        if let hostConfig, !hostConfig.isEmpty {
            let hosts = SourceVault.shared.endpoints(from: hostConfig)
            debugPrint("[直连配置] hostList: \(hosts)")
            let hostDomains = hosts.compactMap { URL(string: $0)?.host }
            domains.append(contentsOf: hostDomains)
            debugPrint("[直连配置] 添加 hostList 域名到直连: \(hostDomains)")
        } else {
            debugPrint("[直连配置] !!! 未获取到 hostList")
        }
        
        return domains
    }
    
    private func constructRoutingRules(_ domains: [String]) -> [[String: Any]] {
        debugPrint("[直连配置] === 开始添加直连规则 ===")
        var rules: [[String: Any]] = []
        
        // 固定规则：raw.githubusercontent.com 单独处理
        rules.append([
            "type": "field",
            "domain": ["raw.githubusercontent.com"],
            "outboundTag": "direct"
        ])
        debugPrint("[直连配置] 添加直连规则: [\"raw.githubusercontent.com\"]")
        
        // 动态规则：其他域名
        if !domains.isEmpty {
            rules.append([
                "type": "field",
                "domain": domains,
                "outboundTag": "direct"
            ])
            debugPrint("[直连配置] 添加直连规则: \(domains)")
        } else {
            debugPrint("[直连配置] !!! 没有需要直连的域名")
        }
        
        debugPrint("[直连配置] 最终直连规则数量: \(rules.count)")
        for (index, rule) in rules.enumerated() {
            debugPrint("[直连配置] 规则 \(index + 1): \(rule)")
        }
        
        return rules
    }
    
    private func mergeRoutingConfiguration(_ config: [String: Any], rules: [[String: Any]]) -> [String: Any] {
        var mergedConfig = config
        
        if mergedConfig["routing"] == nil {
            mergedConfig["routing"] = [
                "domainStrategy": "AsIs",
                "rules": rules
            ]
            debugPrint("[直连配置] 创建新的 routing 配置")
        } else if var routing = mergedConfig["routing"] as? [String: Any] {
            routing["rules"] = rules
            mergedConfig["routing"] = routing
            debugPrint("[直连配置] 更新现有 routing 配置")
        }
        
        debugPrint("[直连配置] === 直连规则添加完成 ===")
        return mergedConfig
    }
    
    // MARK: - 配置持久化
    
    private func persistConfiguration(_ config: String) async {
        let userDefaults = UserDefaults(suiteName: RouterConf.targetGroup)
        userDefaults?.set(Date(), forKey: RouterConf.targetDate)
        userDefaults?.set(config, forKey: RouterConf.targetConfig)
        userDefaults?.synchronize()
    }
}
