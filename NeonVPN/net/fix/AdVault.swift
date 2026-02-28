//
//  AdDepot.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/11.
//

import Foundation

final class AdVault {
    static let shared = AdVault()
    
    /// 为 true 时：不加载、不展示 AdMob，仅保留 Yandex Int / EM Int。代码保留便于后续恢复。
    static let admobDisabledInCode = true
    
    private let bannerKey = StoreKeys.Ads.adYandexBanner
    private let yandexIntKey = StoreKeys.Ads.adYandexInterstitial
    private let emIntKey = StoreKeys.Ads.adYandexEMInt
    private let admobIntKey = StoreKeys.Ads.adAdmobInterstitial
    private let penetrationKey = StoreKeys.Ads.adPenetration
    private let clickDelayKey = StoreKeys.Ads.adClickDelay
    private let disabledKey = StoreKeys.Ads.adDisabled
    private let variantKey = StoreKeys.Ads.adVariant
    private let savedAtKey = StoreKeys.Ads.adSavedAt
    
    private init() {
        initDefaults()
    }
    
    // MARK: - 配置保存和读取
    
    /// 原: saveAdConfigDate()
    func saveTimestamp() {
        UserDefaults.standard.set(Date(), forKey: savedAtKey)
        UserDefaults.standard.synchronize()
    }
    
    /// 原: getAdConfigSaveDate()
    func savedTimestamp() -> Date? {
        return UserDefaults.standard.object(forKey: savedAtKey) as? Date
    }
    
    // MARK: - JSON 解析辅助
    
    /// 原: extractAdConfig(from:)
    func parseConfig(from jsonString: String) -> [String: Any]? {
        guard let jsonData = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            debugPrint("[AdVault] 解析配置失败")
            return nil
        }
        return root
    }
    
    private func loadAdConfig(from config: [String: Any]) -> [String: Any]? {
        return config["adConfig"] as? [String: Any]
    }
    
    /// 原: extractAdMixed(from:)
    func parseMixed(from config: [String: Any]) -> [[String: Any]]? {
        guard let adConfig = loadAdConfig(from: config) else { return nil }
        return adConfig["adMixed"] as? [[String: Any]]
    }
    
    // MARK: - 提取具体广告类型配置
    
    private func findAdItem(by name: String, in adMixed: [[String: Any]]) -> [String: Any]? {
        return adMixed.first { ($0["name"] as? String) == name }
    }
    
    /// 原: extractYandexBannerConfig(from:)
    func parseBannerConfig(from adMixed: [[String: Any]]) -> (key: String?, penetrate: Int?, clickDelay: Int?)? {
        guard let item = findAdItem(by: "Yandex_Banner_List", in: adMixed) else { return nil }
        let key = item["key"] as? String
        let penetrate = item["penetrate"] as? Int
        let clickDelay = item["clickDelayPenet"] as? Int
        return (key, penetrate, clickDelay)
    }
    
    /// 原: extractYandexIntConfig(from:)
    func parseYandexInt(from adMixed: [[String: Any]]) -> String? {
        guard let item = findAdItem(by: "Yandex_Int_List", in: adMixed) else { return nil }
        return item["key"] as? String
    }
    
    /// EM 插屏：接口字段 Yandex_EMInt_List
    func parseEMInt(from adMixed: [[String: Any]]) -> String? {
        guard let item = findAdItem(by: "Yandex_EMInt_List", in: adMixed) else { return nil }
        return item["key"] as? String
    }
    
    /// 原: extractAdmobIntConfig(from:)
    func parseAdmobInt(from adMixed: [[String: Any]]) -> String? {
        guard let item = findAdItem(by: "Admob_Int_List", in: adMixed) else { return nil }
        return item["key"] as? String
    }
    
    // MARK: - 保存具体广告配置
    
    /// 原: saveYandexBannerKey(_:)
    func storeBannerKey(_ key: String?) {
        guard let key = key else { return }
        UserDefaults.standard.set(key, forKey: bannerKey)
        UserDefaults.standard.synchronize()
    }
    
    /// 原: saveYandexIntKey(_:)
    func storeYandexIntKey(_ key: String?) {
        guard let key = key else { return }
        UserDefaults.standard.set(key, forKey: yandexIntKey)
        UserDefaults.standard.synchronize()
    }
    
    func storeEMIntKey(_ key: String?) {
        guard let key = key else { return }
        UserDefaults.standard.set(key, forKey: emIntKey)
        UserDefaults.standard.synchronize()
    }
    
    /// 原: saveAdmobIntKey(_:)
    func storeAdmobIntKey(_ key: String?) {
        guard let key = key else { return }
        UserDefaults.standard.set(key, forKey: admobIntKey)
        UserDefaults.standard.synchronize()
    }
    
    /// 原: savePenetrateSettings(penetrate:clickDelay:)
    func storePenetration(penetrate: Int?, clickDelay: Int?) {
        if let penetrate = penetrate {
            UserDefaults.standard.set(penetrate, forKey: penetrationKey)
        }
        
        if let clickDelay = clickDelay {
            UserDefaults.standard.set(clickDelay, forKey: clickDelayKey)
        }
        UserDefaults.standard.synchronize()
    }
    
    /// 原: saveAdsOff(_:)
    func storeDisabled(_ isOff: Bool?) {
        guard let isOff = isOff else { return }
        UserDefaults.standard.set(isOff, forKey: disabledKey)
        UserDefaults.standard.synchronize()
    }
    
    /// 原: saveAdsType(_:)
    func storeVariant(_ variant: String?) {
        guard let variant = variant else { return }
        UserDefaults.standard.set(variant, forKey: variantKey)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - 获取保存的广告配置
    
    /// 原: getYandexBannerKey()
    func banner() -> String {
        /// 测试服
        //return "demo-banner-yandex"
        return UserDefaults.standard.string(forKey: bannerKey) ?? "R-M-17736350-1;R-M-17736350-2"
    }
    
    /// 原: getYandexIntKey()
    func yandexInt() -> String {
        /// 测试服
        //return "demo-interstitial-yandex"
        return UserDefaults.standard.string(forKey: yandexIntKey) ?? "R-M-18817612-1"
    }
    
    /// EM 插屏 key，接口 Yandex_EMInt_List
    func emInt() -> String {
        /// 测试服
        //return "R-M-18812052-1"
        return UserDefaults.standard.string(forKey: emIntKey) ?? "R-M-18812052-1"
    }
    
    /// 是否 EM 模式：adsType 含 "e" 时用 EM Int
    func isEMMode() -> Bool {
        return variant()?.contains("e") == true
    }
    
    /// 原: getAdmobIntKey()
    func admobInt() -> String {
        /// 测试服
        //return "ca-app-pub-3940256099942544/4411468910"
        return UserDefaults.standard.string(forKey: admobIntKey) ?? "ca-app-pub-9967705190578179/2229741380"
    }
    
    /// 原: getPenetrate()
    func penetration() -> Int {
        return UserDefaults.standard.integer(forKey: penetrationKey)
    }
    
    /// 原: getClickDelay()
    func clickDelay() -> Int {
        return UserDefaults.standard.integer(forKey: clickDelayKey)
    }
    
    /// 原: getAdsOff()
    func isDisabled() -> Bool {
        /// 测试服
        //return false
        return UserDefaults.standard.bool(forKey: disabledKey)
    }
    
    /// 原: getAdsType()
    func variant() -> String? {
        /// 测试服
        //return "y;a"
        //return "y;e;a"
        return UserDefaults.standard.string(forKey: variantKey)
    }
    
    // MARK: - 初始化默认值
    
    /// 原: initializeDefaultValues()
    private func initDefaults() {
        if UserDefaults.standard.object(forKey: penetrationKey) == nil {
            UserDefaults.standard.set(100, forKey: penetrationKey)
            debugPrint("[AdVault] 初始化默认 penetrate: 100")
        }
        
        if UserDefaults.standard.object(forKey: clickDelayKey) == nil {
            UserDefaults.standard.set(15, forKey: clickDelayKey)
            debugPrint("[AdVault] 初始化默认 clickDelay: 15")
        }
        
        if UserDefaults.standard.object(forKey: disabledKey) == nil {
            UserDefaults.standard.set(true, forKey: disabledKey)
            debugPrint("[AdVault] 初始化默认 adsOff: true")
        }
        
        UserDefaults.standard.synchronize()
    }
}
