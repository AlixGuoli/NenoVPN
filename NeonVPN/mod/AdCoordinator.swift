//
//  AdCoordinator.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation
import UIKit
import YandexMobileAds

/// 统一管理项目中所有广告资源的加载与展示。
final class AdCoordinator {
    
    static let instance = AdCoordinator()
    
    private let mobService = AdmobInterstitialService()
    private let inYaService = YandexInterstitialService()
    private let emIntService = YandexEMInterstitialService()
    
    private init() {}
    
    // MARK: - Public state
    var isActive = false
    var isVip = false
    
    var isMobReady: Bool {
        guard adsEnabled && isMobEnabled && !AdVault.admobDisabledInCode else { return false }
        return mobService.isReady
    }
    
    var isInYaReady: Bool {
        guard adsEnabled && isInYaEnabled else { return false }
        if isEMMode { return emIntService.isReady }
        return inYaService.isReady
    }
    
    private var isEMMode: Bool { AdVault.shared.isEMMode() }
    
    var hasAnyReady: Bool {
        guard adsEnabled else { return false }
        return isMobReady || isInYaReady
    }
    
    // MARK: - Load entry points
    func loadAllAds(moment: String? = nil) {
        guard adsEnabled else {
            debugPrint("[ADS] [Manager] 广告已关闭")
            return
        }
        if isInYaEnabled {
            if isEMMode { emIntService.fetchContent(moment: moment) }
            else { inYaService.fetchContent(moment: moment) }
        }
        if isMobEnabled && !AdVault.admobDisabledInCode {
            mobService.fetchContent(moment: moment)
        } else {
            mobService.clear()
        }
    }
    
    func loadMob(moment: String? = nil, onReady: (() -> Void)? = nil, onFailed: (() -> Void)? = nil) {
        guard adsEnabled && isMobEnabled && !AdVault.admobDisabledInCode else {
            mobService.clear()
            onReady?()
            return
        }
        mobService.onContentReady = onReady
        mobService.onContentFailed = onFailed
        mobService.fetchContent(moment: moment)
    }
    
    func loadInYa(onReady: (() -> Void)? = nil, onFailed: (() -> Void)? = nil) {
        guard adsEnabled && isInYaEnabled else {
            onReady?()
            return
        }
        if isEMMode {
            emIntService.onContentReady = onReady
            emIntService.onContentFailed = onFailed
            emIntService.fetchContent()
        } else {
            inYaService.onContentReady = onReady
            inYaService.onContentFailed = onFailed
            inYaService.fetchContent()
        }
    }
    
    // MARK: - Present helpers
    func displayMob(from controller: UIViewController, moment: String?) {
        guard !AdVault.admobDisabledInCode else { return }
        guard ConnectionStatusCenter.shared.isConnected else {
            mobService.clear()
            return
        }
        if moment == StoreKeys.AdTrigger.disconnect {
            mobService.reloadAfterPresent = false
        }
        mobService.display(from: controller, moment: moment)
    }
    
    func displayInYa(from controller: UIViewController, onClose: (() -> Void)? = nil) {
        if isEMMode {
            emIntService.onContentClosed = onClose
            emIntService.display(from: controller)
        } else {
            inYaService.onContentClosed = onClose
            inYaService.display(from: controller)
        }
    }
    
    enum DisplayType {
        case mobInt(moment: String?)
        case inYa(onClose: (() -> Void)?)
    }
    
    func showFromWindow(_ placement: DisplayType) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        switch placement {
        case .mobInt(let moment):
            displayMob(from: root, moment: moment)
        case .inYa(let onClose):
            displayInYa(from: root, onClose: onClose)
        }
    }
    
    // MARK: - Private flags
    private var adsEnabled: Bool {
        guard !isVip else { return false }
        return !AdVault.shared.isDisabled()
    }
    
    private var isInYaEnabled: Bool {
        guard let variant = AdVault.shared.variant() else { return false }
        return variant.contains("y") || variant.contains("e")
    }
    
    private var isMobEnabled: Bool {
        guard let variant = AdVault.shared.variant(), variant.contains("a") else { return false }
        return ConnectionStatusCenter.shared.isConnected
    }
}

