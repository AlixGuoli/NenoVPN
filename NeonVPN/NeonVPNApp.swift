//
//  NeonVPNApp.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/9/19.
//

import SwiftUI

@main
struct NeonVPNApp: App {
    @StateObject private var launchManager = LaunchManager()
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var globalConnectVM = ConnectVM()
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var startupDone = false
    @State private var showReturnLaunch = false
    @State private var isBack = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // 主界面
                if launchManager.isLaunching {
                    LaunchView()
                        .environmentObject(launchManager)
                        .preferredColorScheme(.dark)
                } else if !onboardingManager.hasCompletedOnboarding {
                    OnboardingView(onboardingManager: onboardingManager)
                        .preferredColorScheme(.dark)
                } else {
                    ContentView()
                        .environmentObject(globalConnectVM)
                        .preferredColorScheme(.dark)
                }
                
                // 前台返回启动页
                if showReturnLaunch {
                    ReturnLaunchView {
                        showReturnLaunch = false
                    }
                    .preferredColorScheme(.dark)
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: launchManager.isLaunching) { newValue in
            if !newValue {
                // 冷启动完成
                startupDone = true
            }
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // 从后台回到前台，需要满足以下条件：
            // 1. 之前进入过后台
            // 2. 冷启动已完成
            // 3. 已完成引导
            // 4. 不在连接中（stage != .connecting）
            // 5. 不在断开中（系统状态不是 .disconnecting）
            // 6. 不在启动中
            if isBack 
                && startupDone 
                && onboardingManager.hasCompletedOnboarding
                && globalConnectVM.stage != .connecting
                && !launchManager.isLaunching {
                showReturnLaunch = true
                isBack = false
            }
        case .background:
            isBack = true
        default:
            break
        }
    }
}
