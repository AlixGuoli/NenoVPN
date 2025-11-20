//
//  AdMoments.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation

/// 用于描述广告触发场景的标识集合。
enum AdMoment {
    static let launch = "launchApp"
    static let foreground = "foreground"
    static let connect = "connect"
    static let disconnect = "disconnect"
    static let closeAd = "closead"
    static let scenario = "scene"
}

