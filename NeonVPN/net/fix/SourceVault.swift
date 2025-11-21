//
//  SourceDepot.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/11.
//

import Foundation

final class SourceVault {
    static let shared = SourceVault()
    private init() {}
    
    private let cfgKey = StoreKeys.Source.sourceProfile
    private let saveTimeKey = StoreKeys.Source.sourceSavedAt
    
    /// 原: currentConfig()
    func load() -> String? {
        let cfg = UserDefaults.standard.string(forKey: cfgKey)
        return (cfg?.isEmpty == false) ? cfg : nil
    }
    
    /// 原: ensureConfig()
    func ensure() -> String? {
        debugPrint("检查 UserDefaults 是否有配置")
        if let cfg = load() {
            debugPrint("✅ UserDefaults 已有配置，直接使用")
            return cfg
        }
        debugPrint("UserDefaults 无配置，尝试读取本地文件")
        
        debugPrint("查找 local.git 文件")
        if let resourcePath = Bundle.main.resourcePath {
            let fileManager = FileManager.default
            if let files = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                debugPrint("Bundle 中的文件: \(files.filter { $0.contains("local") })")
            }
        }
        guard let bundlePath = Bundle.main.path(forResource: "local", ofType: "git") else {
            debugPrint("!!! 未找到文件: local.git")
            return nil
        }
        
        debugPrint("找到文件路径: \(bundlePath)")
        debugPrint("读取文件内容")
        do {
            let envelope = try String(contentsOfFile: bundlePath, encoding: .utf8)
            debugPrint("文件读取成功，内容长度: \(envelope.count)")
            debugPrint("解密前内容: \(envelope)")
        
            debugPrint("开始解密")
            guard let decrypted = NetProfile.Sec.reveal(envelope) else {
                debugPrint("!!! 解密失败")
                return nil
            }
            debugPrint("解密成功，解密后长度: \(decrypted.count)")
            debugPrint("解密后内容: \(decrypted)")
            
            guard !decrypted.isEmpty else {
                debugPrint("!!! 解密后内容为空")
                return nil
            }
            
            debugPrint("保存配置到 UserDefaults")
            store(decrypted)
            debugPrint("✅ 配置保存成功")
            return decrypted
        } catch {
            debugPrint("!!! 读取文件错误: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 原: saveCurrent()
    func store(_ config: String) {
        UserDefaults.standard.set(config, forKey: cfgKey)
        UserDefaults.standard.set(Date(), forKey: saveTimeKey)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - JSON 解析辅助
    
    private func loadApiSection(from config: String) -> [String: Any]? {
        guard let jsonData = config.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        return root["api"] as? [String: Any]
    }
    
    // MARK: - 字段提取
    
    /// 原: hosts(from:)
    func endpoints(from config: String) -> [String] {
        // 临时测试：让所有host超时，触发Git更新流程
        // 测试完后删除或注释掉这段代码
//        #if DEBUG
//        let testTimeout = false  // 改为 true 启用测试
//        if testTimeout {
//            debugPrint("[TEST] 测试模式：使用延迟URL，模拟请求超时（延迟6秒，超过5秒超时）")
//            return ["https://httpbin.org/delay/6"]
//        }
//        #endif
        
        guard let api = loadApiSection(from: config) else { return [] }
        return api["host"] as? [String] ?? []
    }
    
    /// 原: gitSources(from:)
    func sources(from config: String) -> [String] {
        guard let api = loadApiSection(from: config) else { return [] }
        return api["git"] as? [String] ?? []
    }
    
    /// 原: gReport(from:)
    func reportUrl(from config: String) -> String? {
        guard let api = loadApiSection(from: config),
              let url = api["greport"] as? String,
              !url.isEmpty else {
            return nil
        }
        return url
    }
    
    /// 原: connReport(from:)
    func connectionUrl(from config: String) -> String? {
        guard let api = loadApiSection(from: config),
              let url = api["connreport"] as? String,
              !url.isEmpty else {
            return nil
        }
        return url
    }
}
