//
//  ServiceVault.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/11.
//

import Foundation

final class ServiceVault {
    static let shared = ServiceVault()
    private init() {}
    
    private let cfgKey = StoreKeys.Service.serviceProfile
    
    // MARK: - 当前配置（内存中，未保存）
    
    /// 当前服务配置（加密的）
    var currentConfig: String? = nil
    
    var ipService: String? = nil
    var idConnect: String? = nil
    var isFromRequest = true
    
    // MARK: - 配置保存和读取
    
    /// 从 UserDefaults 加载服务配置
    func load() -> String? {
        let cfg = UserDefaults.standard.string(forKey: cfgKey)
        return (cfg?.isEmpty == false) ? cfg : nil
    }
    
    /// 保存服务配置到 UserDefaults（连接成功后调用）
    func store(_ config: String) {
        UserDefaults.standard.set(config, forKey: cfgKey)
        UserDefaults.standard.synchronize()
    }
    
    /// 读取 Bundle 中的本地服务配置（local.ser）
    func loadBundledService() -> String? {
        guard let path = Bundle.main.path(forResource: "local", ofType: "ser") else {
            debugPrint("[SERVICE] 未找到 local.ser")
            return nil
        }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            debugPrint("[SERVICE] 读取 local.ser 成功，长度: \(content.count)")
            return content
        } catch {
            debugPrint("[SERVICE] 读取 local.ser 失败: \(error.localizedDescription)")
            return nil
        }
    }
}

