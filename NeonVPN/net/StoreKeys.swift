//
//  StoreKeys.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/11.
//

import Foundation

enum StoreKeys {
    enum Source {
        static let sourceProfile = "nvSourceProfile"
        static let sourceSavedAt = "nvSourceSavedAt"
    }
    
    enum Base {
        static let baseProfile = "nvBaseProfile"
        static let baseSavedAt = "nvBaseSavedAt"
        static let contactLink = "nvContactLink"
        static let profileGitRev = "nvProfileGitRev"
        static let serviceFlag = "nvServiceFlag"
    }
    
    enum Ads {
        static let adYandexBanner = "nvAdYandexBanner"
        static let adYandexInterstitial = "nvAdYandexInterstitial"
        static let adYandexEMInt = "nvAdYandexEMInt"
        static let adAdmobInterstitial = "nvAdAdmobInterstitial"
        static let adPenetration = "nvAdPenetration"
        static let adClickDelay = "nvAdClickDelay"
        static let adDisabled = "nvAdDisabled"
        static let adVariant = "nvAdVariant"
        static let adSavedAt = "nvAdSavedAt"
    }
    
    enum Service {
        static let serviceProfile = "nvServiceProfile"
    }
    
    enum Server {
        static let chosenServerId = "nvChosenServerId"
    }
    
    enum AdTrigger {
        static let launch = "launchApp"
        static let foreground = "foreground"
        static let connect = "connect"
        static let disconnect = "disconnect"
        static let closeAd = "closead"
        static let scenario = "scene"
    }
    
    enum GaKey {
        static let gameKey = "8ef35b9153a99995084f490b3503e36f"
        static let secretKey = "b70568589bd3aedde15973d520d41903e756947e"
    }
}


