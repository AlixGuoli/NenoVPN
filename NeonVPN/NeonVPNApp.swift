//
//  NeonVPNApp.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/9/19.
//

import SwiftUI

@main
struct NeonVPNApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var launchManager = LaunchManager()
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var globalConnectVM = ConnectVM()
    @StateObject private var vipCenter = VipCenter.shared
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var startupDone = false
    @State private var showReturnLaunch = false
    @State private var isBack = false
    @State private var shouldShowStartupAd = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // 主界面
                if launchManager.isLaunching {
                    LaunchView(shouldShowStartupAd: $shouldShowStartupAd)
                        .environmentObject(launchManager)
                        .environmentObject(onboardingManager)
                        .environmentObject(vipCenter)
                        .preferredColorScheme(.dark)
                } else if !onboardingManager.hasCompletedOnboarding {
                    OnboardingView(onboardingManager: onboardingManager)
                        .preferredColorScheme(.dark)
                } else {
                    ContentView()
                        .environmentObject(globalConnectVM)
                        .environmentObject(vipCenter)
                        .preferredColorScheme(.dark)
                }
                
                // 前台返回启动页
                if showReturnLaunch {
                    ReturnLaunchView(onShowAd: {
                        showBackgroundAd()
                    }, onComplete: {
                        showReturnLaunch = false
                    })
                    .preferredColorScheme(.dark)
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: launchManager.isLaunching) { newValue in
            if !newValue {
                startupDone = true
                showStartupAdIfNeeded()
            }
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            Task {
                // 前台时优先刷新 VIP 状态，避免过期 / 新购时广告判断不准确
                await vipCenter.refreshVipStatus()
                
                if isBack
                    && startupDone
                    && onboardingManager.hasCompletedOnboarding
                    && globalConnectVM.stage != .connecting
                    && !launchManager.isLaunching {
                    
                    let ads = AdCoordinator.instance
                    
                    // 拉广告（内部已根据 isVip 决定是否真正请求）
                    ads.loadAllAds(moment: StoreKeys.AdTrigger.foreground)
                    
                    // 检查是否有广告正在展示
                    if !ads.isActive {
                        // 检查是否有广告可以展示
                        if ads.hasAnyReady {
                            debugPrint("[ADS] [Manager] 从后台返回，显示后台页")
                            showReturnLaunch = true
                            isBack = false
                        } else {
                            debugPrint("[ADS] [Manager] 从后台返回，但没有广告可展示，跳过后台页")
                            isBack = false
                        }
                    } else {
                        debugPrint("[ADS] [Manager] 从后台返回，但广告正在展示，跳过后台页")
                        isBack = false
                    }
                }
            }
        case .background:
            isBack = true
        default:
            break
        }
    }
    
    private func showStartupAdIfNeeded() {
        guard shouldShowStartupAd,
              onboardingManager.hasCompletedOnboarding else {
            shouldShowStartupAd = false
            return
        }
        shouldShowStartupAd = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            presentYandexSplashAd()
        }
    }
    
    private func presentYandexSplashAd() {
        let ads = AdCoordinator.instance
        if ads.isMobReady {
            ads.showFromWindow(.mobInt(moment: StoreKeys.AdTrigger.launch))
        } else if ads.isInYaReady {
            ads.showFromWindow(.inYa(onClose: nil))
        }
    }
    
    private func showBackgroundAd() {
        // 检查隐私状态（已完成引导页）
        guard onboardingManager.hasCompletedOnboarding else {
            debugPrint("[ADS] [Manager] 隐私未同意，跳过后台广告")
            return
        }
        
        let ads = AdCoordinator.instance
        
        // 检查是否有广告可以展示，优先级：AdMob > Yandex/EM Int
        if ads.hasAnyReady {
            if ads.isMobReady {
                debugPrint("[ADS] [Manager] 从后台页展示 AdMob 广告")
                ads.showFromWindow(.mobInt(moment: StoreKeys.AdTrigger.foreground))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showReturnLaunch = false }
            } else if ads.isInYaReady {
                debugPrint("[ADS] [Manager] 从后台页展示 Yandex/EM Int 广告")
                ads.showFromWindow(.inYa(onClose: nil))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showReturnLaunch = false }
            }
        } else {
            debugPrint("[ADS] [Manager] 没有广告可展示，后台页将在 3 秒后自动关闭")
        }
    }
}
