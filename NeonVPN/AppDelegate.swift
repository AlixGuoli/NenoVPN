//
//  AppDelegate.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        PostATTManager.shared.performInitIfReady()
        return true
    }
}

