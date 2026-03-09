//
//  PostATTManager.swift
//  NeonVPN
//
//  ATT 有结果后执行广告和 GA 的初始化（Guideline 5.1.1(iv)）
//

import Foundation
import AppTrackingTransparency
import GoogleMobileAds
import YandexMobileAds

final class PostATTManager {
    static let shared = PostATTManager()
    private let lock = NSLock()

    private(set) var isInitialized: Bool = false

    private init() {}

    /// ATT 有结果时执行初始化
    func performInitIfReady() {
        lock.lock()
        defer { lock.unlock() }
        guard !isInitialized else { return }

        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            guard status != .notDetermined else {
                return
            }
        }

        setupAdmob()
        setupYandex()
        setupGA()
        isInitialized = true
        debugPrint("[PostATT] 广告和 GA 初始化完成")
    }

    private func setupAdmob() {
        MobileAds.shared.start { status in
            let isReady = status.adapterStatusesByClassName.values.contains { $0.state == .ready }
            debugPrint(isReady ? "[AD] Google Mobile Ads 初始化完成" : "[AD] Google Mobile Ads 初始化未就绪")
        }
    }

    private func setupYandex() {
        MobileAds.initializeSDK {
            debugPrint("[AD] Yandex Mobile Ads 初始化完成")
        }
    }

    private func setupGA() {
        debugPrint("初始化 GameAnalytics")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        GameAnalytics.setEnabledInfoLog(true)
        GameAnalytics.setEnabledVerboseLog(true)
        GameAnalytics.configureAutoDetectAppVersion(true)
        GameAnalytics.configureBuild(version)
        GameAnalytics.initialize(withGameKey: StoreKeys.GaKey.gameKey, gameSecret: StoreKeys.GaKey.secretKey)
    }
}
