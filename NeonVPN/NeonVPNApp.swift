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
    
    var body: some Scene {
        WindowGroup {
            if launchManager.isLaunching {
                LaunchView()
                    .preferredColorScheme(.dark)
                    .onAppear {
                        // 2秒后完成启动
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            launchManager.completeLaunch()
                        }
                    }
            } else if !onboardingManager.hasCompletedOnboarding {
                OnboardingView(onboardingManager: onboardingManager)
                    .preferredColorScheme(.dark)
            } else {
                ContentView()
                    .preferredColorScheme(.dark)
            }
        }
    }
}
