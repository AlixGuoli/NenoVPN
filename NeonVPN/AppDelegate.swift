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
        return true
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
}

