//
//  YandexInterstitialService.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation
import YandexMobileAds
import UIKit

/// 管理 Yandex 插屏广告的加载与展示。
final class YandexInterstitialService: NSObject {
    
    // MARK: - Callbacks
    var onContentReady: (() -> Void)?
    var onContentFailed: (() -> Void)?
    var onContentClosed: (() -> Void)?
    
    // MARK: - Private State
    private var mediaInstance: InterstitialAd?
    private var requestLoader = InterstitialAdLoader()
    private var mediaKeys: [String] = []
    private var isRequesting = false
    private var requestTimestamp: Date?
    private var keyIndex = 0
    
    override init() {
        super.init()
        requestLoader.delegate = self
    }
    
    var isReady: Bool {
        return mediaInstance != nil
    }
    
    func clear() {
        mediaInstance = nil
        isRequesting = false
        requestTimestamp = nil
        keyIndex = 0
    }
    
    // MARK: - Private helpers
    private func extractMediaKeys() {
        let raw = AdVault.shared.yandexInt()
        mediaKeys = raw
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func canStartRequest() -> Bool {
        if mediaInstance != nil { return false }
        if isRequesting {
            guard let ts = requestTimestamp else { return false }
            return Date().timeIntervalSince(ts) > 100
        }
        return true
    }
    
    private func requestMedia(at index: Int) {
        guard index < mediaKeys.count else {
            debugPrint("[ADS] [YandexInt] 加载失败: 所有 key 均失败")
            handleRequestFailure()
            return
        }
        
        let mediaId = mediaKeys[index]
        debugPrint("[ADS] [YandexInt] 开始加载: \(mediaId)")
        let config = AdRequestConfiguration(adUnitID: mediaId)
        requestLoader.loadAd(with: config)
    }
    
    private func handleRequestFailure() {
        isRequesting = false
        requestTimestamp = nil
        onContentFailed?()
    }
    
    private func attemptNextKey() {
        keyIndex += 1
        requestMedia(at: keyIndex)
    }
    
    // MARK: - Load
    func fetchContent(moment: String? = nil) {
        guard canStartRequest() else {
            debugPrint("[ADS] [YandexInt] 跳过加载，状态不满足")
            return
        }
        
        extractMediaKeys()
        guard !mediaKeys.isEmpty else {
            debugPrint("[ADS] [YandexInt] 无可用的广告 key")
            onContentFailed?()
            return
        }
        
        isRequesting = true
        requestTimestamp = Date()
        keyIndex = 0
        requestMedia(at: keyIndex)
    }
    
    func refresh(moment: String? = nil) {
        mediaInstance = nil
        fetchContent(moment: moment)
    }
    
    // MARK: - Present
    func display(from controller: UIViewController) {
        guard let ad = mediaInstance else {
            debugPrint("[ADS] [YandexInt] 无广告可展示")
            onContentFailed?()
            return
        }
        ad.show(from: controller)
    }
}

// MARK: - InterstitialAdLoaderDelegate

extension YandexInterstitialService: InterstitialAdLoaderDelegate {
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: InterstitialAd) {
        let mediaId = interstitialAd.adInfo?.adUnitId ?? "-"
        debugPrint("[ADS] [YandexInt] 加载成功: \(mediaId)")
        isRequesting = false
        requestTimestamp = nil
        mediaInstance = interstitialAd
        interstitialAd.delegate = self
        onContentReady?()
    }
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        let mediaId = error.adUnitId ?? "-"
        debugPrint("[ADS] [YandexInt] 加载失败: \(mediaId) - \(error.error.localizedDescription)")
        attemptNextKey()
    }
}

// MARK: - InterstitialAdDelegate

extension YandexInterstitialService: InterstitialAdDelegate {
    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
        debugPrint("[ADS] [YandexInt] 展示失败: \(error.localizedDescription)")
        AdCoordinator.instance.isActive = false
        mediaInstance = nil
        refresh()
    }
    
    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
        debugPrint("[ADS] [YandexInt] 展示成功")
        AdCoordinator.instance.isActive = true
    }
    
    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
        debugPrint("[ADS] [YandexInt] 关闭")
        onContentClosed?()
        refresh()
        AdCoordinator.instance.isActive = false
    }
    
    func interstitialAdDidClick(_ interstitialAd: InterstitialAd) {
        debugPrint("[ADS] [YandexInt] 点击")
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didTrackImpressionWith impressionData: ImpressionData?) {
        debugPrint("[ADS] [YandexInt] 曝光")
    }
}

