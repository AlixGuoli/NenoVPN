//
//  AppDelegate.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import UIKit
import GoogleMobileAds
import YandexMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        setupAdmob()
        setupYandex()
        setupGA()
        return true
    }
    
    private func setupAdmob() {
        guard !AdVault.admobDisabledInCode else {
            debugPrint("[AD] AdMob 已在代码中关闭，跳过初始化")
            return
        }
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
       
        // Enable log
        GameAnalytics.setEnabledInfoLog(true)
        GameAnalytics.setEnabledVerboseLog(true)
        GameAnalytics.configureAutoDetectAppVersion(true)
        GameAnalytics.configureBuild(version)
        GameAnalytics.initialize(withGameKey: StoreKeys.GaKey.gameKey, gameSecret: StoreKeys.GaKey.secretKey)
    }
}

