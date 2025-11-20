//
//  AdsManager.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation
import UIKit
import YandexMobileAds

/// 统一管理项目中所有广告资源的加载与展示。
final class AdsManager {
    
    static let shared = AdsManager()
    
    private let admob = AdmobInterstitialService()
    private let yandexInt = YandexInterstitialService()
    private let yandexBanner = YandexBannerService()
    
    private init() {}
    
    // MARK: - Public state
    var isShowingAd = false
    var isVip = false
    
    var isAdmobReady: Bool {
        guard adsEnabled && admobEnabled else { return false }
        return admob.isPrepared
    }
    
    var isYandexIntReady: Bool {
        guard adsEnabled && yandexEnabled else { return false }
        return yandexInt.isPrepared
    }
    
    var isYandexBannerReady: Bool {
        guard adsEnabled && yandexEnabled else { return false }
        return yandexBanner.isPrepared
    }
    
    var isAnyReady: Bool {
        guard adsEnabled else { return false }
        return isAdmobReady || isYandexIntReady || isYandexBannerReady
    }
    
    // MARK: - Load entry points
    func prepareAllAds(moment: String? = nil) {
        guard adsEnabled else {
            debugPrint("[ADS] [Manager] 广告已关闭")
            return
        }
        if yandexEnabled {
            yandexInt.loadAd()
            yandexBanner.loadBanner()
        }
        if admobEnabled {
            admob.loadAd(moment: moment)
        } else {
            admob.reset()
        }
    }
    
    func prepareAdmob(moment: String? = nil, onReady: (() -> Void)? = nil, onFailed: (() -> Void)? = nil) {
        guard adsEnabled && admobEnabled else {
            admob.reset()
            onReady?()
            return
        }
        admob.onAdReady = onReady
        admob.onAdFailed = onFailed
        admob.loadAd(moment: moment)
    }
    
    func prepareYandexInt(onReady: (() -> Void)? = nil, onFailed: (() -> Void)? = nil) {
        guard adsEnabled && yandexEnabled else {
            onReady?()
            return
        }
        yandexInt.onAdReady = onReady
        yandexInt.onAdFailed = onFailed
        yandexInt.loadAd()
    }
    
    func prepareYandexBanner(onReady: (() -> Void)? = nil, onFailed: (() -> Void)? = nil) {
        guard adsEnabled && yandexEnabled else {
            onReady?()
            return
        }
        yandexBanner.onAdReady = onReady
        yandexBanner.onAdFailed = onFailed
        yandexBanner.loadBanner()
    }
    
    // MARK: - Present helpers
    func showAdmob(from controller: UIViewController, moment: String?) {
        guard ConnectionStatusCenter.shared.isConnected else {
            admob.reset()
            return
        }
        admob.present(from: controller, moment: moment)
        admob.loadAd(moment: moment)
    }
    
    func showYandexInt(from controller: UIViewController, onClose: (() -> Void)? = nil) {
        yandexInt.onAdClosed = onClose
        yandexInt.present(from: controller)
    }
    
    func showYandexBanner(from controller: UIViewController) {
        yandexBanner.present(from: controller)
    }
    
    enum Placement {
        case admobInt(moment: String?)
        case yandexInt(onClose: (() -> Void)?)
        case yandexBanner
    }
    
    func presentFromRoot(_ placement: Placement) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        switch placement {
        case .admobInt(let moment):
            showAdmob(from: root, moment: moment)
        case .yandexInt(let onClose):
            showYandexInt(from: root, onClose: onClose)
        case .yandexBanner:
            showYandexBanner(from: root)
        }
    }
    
    // MARK: - Private flags
    private var adsEnabled: Bool {
        // 测试
        //return false
        guard !isVip else { return false }
        return !AdVault.shared.isDisabled()
    }
    
    private var yandexEnabled: Bool {
        guard let variant = AdVault.shared.variant() else { return false }
        return variant.contains("y")
    }
    
    private var admobEnabled: Bool {
        guard let variant = AdVault.shared.variant(), variant.contains("a") else { return false }
        return ConnectionStatusCenter.shared.isConnected
    }
}

