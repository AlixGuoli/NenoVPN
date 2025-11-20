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
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClosed: (() -> Void)?
    
    // MARK: - Private State
    private var currentAd: InterstitialAd?
    private var loader = InterstitialAdLoader()
    private var adUnitIDs: [String] = []
    private var isLoading = false
    private var loadTimestamp: Date?
    private var currentIndex = 0
    
    override init() {
        super.init()
        loader.delegate = self
    }
    
    var isPrepared: Bool {
        return currentAd != nil
    }
    
    func reset() {
        currentAd = nil
        isLoading = false
        loadTimestamp = nil
        currentIndex = 0
    }
    
    // MARK: - Load
    func loadAd(moment: String? = nil) {
        guard shouldBeginLoading() else {
            debugPrint("[ADS] [YandexInt] 跳过加载，状态不满足")
            return
        }
        
        prepareKeys()
        guard !adUnitIDs.isEmpty else {
            debugPrint("[ADS] [YandexInt] 无可用的广告 key")
            onAdFailed?()
            return
        }
        
        isLoading = true
        loadTimestamp = Date()
        currentIndex = 0
        loadAd(at: currentIndex)
    }
    
    func reload(moment: String? = nil) {
        currentAd = nil
        loadAd(moment: moment)
    }
    
    // MARK: - Present
    func present(from controller: UIViewController) {
        guard let ad = currentAd else {
            debugPrint("[ADS] [YandexInt] 无广告可展示")
            onAdFailed?()
            return
        }
        ad.show(from: controller)
    }
    
    // MARK: - Private helpers
    private func prepareKeys() {
        let raw = AdVault.shared.yandexInt()
        adUnitIDs = raw
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func shouldBeginLoading() -> Bool {
        if currentAd != nil { return false }
        if isLoading {
            guard let ts = loadTimestamp else { return false }
            return Date().timeIntervalSince(ts) > 100
        }
        return true
    }
    
    private func loadAd(at index: Int) {
        guard index < adUnitIDs.count else {
            debugPrint("[ADS] [YandexInt] 加载失败: 所有 key 均失败")
            finishFailure()
            return
        }
        
        let unitID = adUnitIDs[index]
        debugPrint("[ADS] [YandexInt] 开始加载: \(unitID)")
        let config = AdRequestConfiguration(adUnitID: unitID)
        loader.loadAd(with: config)
    }
    
    private func finishFailure() {
        isLoading = false
        loadTimestamp = nil
        onAdFailed?()
    }
    
    private func scheduleNextAttempt() {
        currentIndex += 1
        loadAd(at: currentIndex)
    }
}

// MARK: - InterstitialAdLoaderDelegate

extension YandexInterstitialService: InterstitialAdLoaderDelegate {
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: InterstitialAd) {
        let adUnitId = interstitialAd.adInfo?.adUnitId ?? "-"
        debugPrint("[ADS] [YandexInt] 加载成功: \(adUnitId)")
        isLoading = false
        loadTimestamp = nil
        currentAd = interstitialAd
        interstitialAd.delegate = self
        onAdReady?()
    }
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        let adUnitId = error.adUnitId ?? "-"
        debugPrint("[ADS] [YandexInt] 加载失败: \(adUnitId) - \(error.error.localizedDescription)")
        scheduleNextAttempt()
    }
}

// MARK: - InterstitialAdDelegate

extension YandexInterstitialService: InterstitialAdDelegate {
    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
        debugPrint("[ADS] [YandexInt] 展示失败: \(error.localizedDescription)")
        AdsManager.shared.isShowingAd = false
        currentAd = nil
        reload()
    }
    
    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
        debugPrint("[ADS] [YandexInt] 展示成功")
        AdsManager.shared.isShowingAd = true
        currentAd = nil
        reload(moment: AdMoment.closeAd)
    }
    
    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
        debugPrint("[ADS] [YandexInt] 关闭")
        AdsManager.shared.isShowingAd = false
        currentAd = nil
        onAdClosed?()
        reload()
    }
    
    func interstitialAdDidClick(_ interstitialAd: InterstitialAd) {
        debugPrint("[ADS] [YandexInt] 点击")
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didTrackImpressionWith impressionData: ImpressionData?) {
        debugPrint("[ADS] [YandexInt] 曝光")
    }
}

