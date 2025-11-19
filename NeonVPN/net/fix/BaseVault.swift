//
//  BaseDepot.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/11.
//

import Foundation

final class BaseVault {
    static let shared = BaseVault()
    private init() {}
    
    private let cfgKey = StoreKeys.Base.baseProfile
    private let saveTimeKey = StoreKeys.Base.baseSavedAt
    private let flagKey = StoreKeys.Base.serviceFlag
    
    // MARK: - 配置保存和读取
    
    /// 原: currentConfig()
    func load() -> String? {
        let cfg = UserDefaults.standard.string(forKey: cfgKey)
        return (cfg?.isEmpty == false) ? cfg : nil
    }
    
    /// 原: saveConfig()
    func store(_ config: String) {
        UserDefaults.standard.set(config, forKey: cfgKey)
        UserDefaults.standard.set(Date(), forKey: saveTimeKey)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - 字段提取
    
    /// 原: detectionServers()
    func nodes() -> [String]? {
        guard let config = load() else { return nil }
        return parseNodes(from: config)
    }
    
    /// 原: gitVersion()
    func rev() -> Int? {
        guard let config = load() else { return nil }
        return parseRev(from: config)
    }
    
    /// 原: adsOff()
    func adState() -> Bool? {
        guard let config = load() else { return nil }
        return parseAdState(from: config)
    }
    
    /// 原: adsType()
    func adVariant() -> String? {
        guard let config = load() else { return nil }
        return parseAdVariant(from: config)
    }
    
    /// 原: dynamicTgLink()
    func contactLink() -> String? {
        guard let config = load() else { return nil }
        return parseContactLink(from: config)
    }
    
    /// 原: iosProfessionalVersions()
    func proVersions() -> [String]? {
        guard let config = load() else { return nil }
        return parseProVersions(from: config)
    }
    
    /// 原: hotcode()
    func serviceFlag() -> String? {
        guard let config = load() else { return nil }
        return parseServiceFlag(from: config)
    }
    
    /// 原: rateusConfig()
    func ratingConfig() -> (maxDailyPopups: Int?, cooldownDays: Int?)? {
        guard let config = load() else { return nil }
        return parseRatingConfig(from: config)
    }
    
    // MARK: - Contact Link 保存
    
    /// 原: saveTgLink(_:)
    func storeContactLink(_ link: String?) {
        guard let link = link, !link.isEmpty else { return }
        UserDefaults.standard.set(link, forKey: StoreKeys.Base.contactLink)
        UserDefaults.standard.synchronize()
    }
    
    /// 原: getSavedTgLink()
    func savedContactLink() -> String? {
        return UserDefaults.standard.string(forKey: StoreKeys.Base.contactLink)
    }
    
    // MARK: - Flag 永久保存
    
    /// 原: saveHotcodeIfNeeded()
    func persistFlagIfNeeded(_ flag: String?) {
        let normalized = normalizeFlag(flag)
        if UserDefaults.standard.string(forKey: flagKey) == nil {
            UserDefaults.standard.set(normalized, forKey: flagKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    /// 原: getSavedHotcode()
    func savedFlag() -> String? {
        return UserDefaults.standard.string(forKey: flagKey)
    }
    
    /// 原: isServiceAvailable()
    func isEnabled() -> Bool {
        if let saved = savedFlag() {
            return saved == "in_service"
        }
        let current = normalizeFlag(serviceFlag())
        return current == "in_service"
    }
    
    private func normalizeFlag(_ code: String?) -> String {
        let trimmed = (code ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "in_service" ? "in_service" : "out_of_service"
    }
    
    // MARK: - JSON 解析辅助
    
    private func loadCommonConf(from config: String) -> [String: Any]? {
        guard let jsonData = config.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        return root["commonConf"] as? [String: Any]
    }
    
    // MARK: - 私有解析方法
    
    private func parseNodes(from config: String) -> [String]? {
        guard let common = loadCommonConf(from: config),
              let detection = common["detectionConfig"] as? [String: Any] else {
            return nil
        }
        return detection["detectionServers"] as? [String]
    }
    
    private func parseRev(from config: String) -> Int? {
        guard let common = loadCommonConf(from: config) else { return nil }
        return common["git_version"] as? Int
    }
    
    private func parseAdState(from config: String) -> Bool? {
        guard let common = loadCommonConf(from: config) else { return nil }
        return common["adsOff"] as? Bool
    }
    
    private func parseAdVariant(from config: String) -> String? {
        guard let common = loadCommonConf(from: config) else { return nil }
        return common["adsType"] as? String
    }
    
    private func parseContactLink(from config: String) -> String? {
        guard let common = loadCommonConf(from: config) else { return nil }
        return common["dynamic_tg_link"] as? String
    }
    
    private func parseProVersions(from config: String) -> [String]? {
        guard let common = loadCommonConf(from: config) else { return nil }
        return common["ios_professional_versions"] as? [String]
    }
    
    private func parseServiceFlag(from config: String) -> String? {
        guard let common = loadCommonConf(from: config) else { return nil }
        return common["hotcode"] as? String
    }
    
    private func parseRatingConfig(from config: String) -> (maxDailyPopups: Int?, cooldownDays: Int?)? {
        guard let common = loadCommonConf(from: config),
              let rateus = common["rateus"] as? [String: Any] else {
            return nil
        }
        
        let maxDailyPopups = rateus["maxDailyPopups"] as? Int
        let cooldownDays = rateus["cooldownDays"] as? Int
        
        return (maxDailyPopups, cooldownDays)
    }
}
