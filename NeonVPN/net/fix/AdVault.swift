//
//  AdDepot.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/11.
//

import Foundation

final class AdVault {
    static let shared = AdVault()
    
    private let bannerKey = StoreKeys.Ads.adYandexBanner
    private let yandexIntKey = StoreKeys.Ads.adYandexInterstitial
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
        return "aaa;bbb;demo-banner-yandex"
        //return UserDefaults.standard.string(forKey: bannerKey) ?? "R-M-16910303-1;R-M-16910303-2"
    }
    
    /// 原: getYandexIntKey()
    func yandexInt() -> String {
        return "aa;demo-interstitial-yandex"
        //return UserDefaults.standard.string(forKey: yandexIntKey) ?? "R-M-16910303-3"
    }
    
    /// 原: getAdmobIntKey()
    func admobInt() -> String {
        return "ca-app-pub-3940256099942544/4411468910"
        //return UserDefaults.standard.string(forKey: admobIntKey) ?? "ca-app-pub-9967705190578179/7444843696"
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
        return UserDefaults.standard.bool(forKey: disabledKey)
    }
    
    /// 原: getAdsType()
    func variant() -> String? {
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
