//
//  YandexBannerService.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation
import UIKit
import YandexMobileAds

/// 负责加载与展示 Yandex Banner 广告。
final class YandexBannerService: NSObject {
    
    // MARK: - Callbacks
    var onContentReady: (() -> Void)?
    var onContentFailed: (() -> Void)?
    var onContentClicked: (() -> Void)?
    
    // MARK: - Private State
    private var mediaView: AdView?
    private var mediaKeys: [String] = []
    private var isRequesting = false
    private var requestTimestamp: Date?
    private var keyIndex = 0
    private var isReady = false
    private var clickHandler: (() -> Void)?
    
    // MARK: - Public Helpers
    var isPrepared: Bool { isReady && mediaView != nil }
    
    func clear() {
        mediaView = nil
        isReady = false
        isRequesting = false
        requestTimestamp = nil
        keyIndex = 0
    }
    
    func fetchContent() {
        guard canStartRequest() else {
            debugPrint("[ADS] [YandexBanner] 跳过加载，正在加载或已有缓存")
            return
        }
        
        extractMediaKeys()
        guard !mediaKeys.isEmpty else {
            debugPrint("[ADS] [YandexBanner] 无可用的广告 key")
            onContentFailed?()
            return
        }
        
        isRequesting = true
        requestTimestamp = Date()
        keyIndex = 0
        requestMedia(at: keyIndex)
    }
    
    func refresh() {
        clear()
        fetchContent()
    }
    
    func getMediaView() -> AdView? {
        return mediaView
    }
    
    func display(from controller: UIViewController) {
        guard let view = mediaView else {
            debugPrint("[ADS] [YandexBanner] 无广告可展示")
            onContentFailed?()
            return
        }
        debugPrint("[ADS] [YandexBanner] 展示成功")
        AdCoordinator.instance.isActive = true
        let overlay = BannerOverlayController(banner: view,
                                              penetration: AdVault.shared.penetration(),
                                              clickDelay: AdVault.shared.clickDelay())
        overlay.modalPresentationStyle = .fullScreen
        overlay.onDismiss = { [weak self] in
            debugPrint("[ADS] [YandexBanner] 关闭")
            AdCoordinator.instance.isActive = false
            // 每次展示结束后需要准备新广告
            self?.isReady = false
            self?.mediaView = nil
            self?.fetchContent()
        }
        clickHandler = { [weak overlay] in
            overlay?.notifyAdTapped()
        }
        controller.present(overlay, animated: true)
    }
    
    // MARK: - Internal Loading
    private func extractMediaKeys() {
        mediaKeys = AdVault.shared.banner()
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func canStartRequest() -> Bool {
        if isReady { return false }
        if isRequesting {
            guard let timestamp = requestTimestamp else { return false }
            return Date().timeIntervalSince(timestamp) > 100
        }
        return true
    }
    
    private func computeMediaSize() -> BannerAdSize {
        let width = UIScreen.main.bounds.width
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first
        let safeInsets = window?.safeAreaInsets ?? .zero
        let height = UIScreen.main.bounds.height - safeInsets.top - safeInsets.bottom
        return BannerAdSize.inlineSize(withWidth: width, maxHeight: height)
    }
    
    private func requestMedia(at index: Int) {
        guard index < mediaKeys.count else {
            debugPrint("[ADS] [YandexBanner] 加载失败: 所有 key 均失败")
            handleRequestFailure()
            return
        }
        
        // 超时检查（120秒）
        if let startTime = requestTimestamp, Date().timeIntervalSince(startTime) > 120 {
            debugPrint("[ADS] [YandexBanner] 加载超时")
            handleRequestFailure()
            return
        }
        
        let mediaId = mediaKeys[index]
        debugPrint("[ADS] [YandexBanner] 开始加载: \(mediaId)")
        
        let adSize = computeMediaSize()
        let view = AdView(adUnitID: mediaId, adSize: adSize)
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        view.loadAd()
        mediaView = view
    }
    
    private func handleRequestFailure() {
        isRequesting = false
        requestTimestamp = nil
        mediaView = nil
        onContentFailed?()
    }
    
    private func attemptNextKey() {
        keyIndex += 1
        requestMedia(at: keyIndex)
    }
}

// MARK: - AdViewDelegate

extension YandexBannerService: AdViewDelegate {
    func adViewDidLoad(_ adView: AdView) {
        debugPrint("[ADS] [YandexBanner] 加载成功: \(adView.adUnitID)")
        isReady = true
        isRequesting = false
        requestTimestamp = nil
        onContentReady?()
    }
    
    func adViewDidFailLoading(_ adView: AdView, error: Error) {
        debugPrint("[ADS] [YandexBanner] 加载失败: \(adView.adUnitID) - \(error.localizedDescription)")
        attemptNextKey()
    }
    
    func adViewDidClick(_ adView: AdView) {
        debugPrint("[ADS] [YandexBanner] 点击")
        clickHandler?()
        onContentClicked?()
    }
}

// MARK: - Overlay Controller

final class BannerOverlayController: UIViewController {
    
    private let mediaContent: UIView
    private let penetrationValue: Int
    private let delayValue: Int
    
    private var canPenetrate = false
    private var canDelay = false
    private var remainingSeconds = 6
    private var closeButtonContainer = UIView()
    private var closeButtonLabel = UILabel()
    private var countdownTimer: Timer?
    private var wasTapped = false
    
    var onDismiss: (() -> Void)?
    
    init(banner: UIView, penetration: Int, clickDelay: Int) {
        self.mediaContent = banner
        self.penetrationValue = penetration
        self.delayValue = clickDelay
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        attachNotificationObserver()
        evaluateFlags()
        constructViewHierarchy()
        configureCloseButton()
        startCountdown()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        countdownTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    func notifyAdTapped() {
        wasTapped = true
    }
    
    // MARK: - Private Setup
    
    private func evaluateFlags() {
        let randomPenetration = Int.random(in: 1...100)
        let randomDelay = Int.random(in: 1...100)
        
        canPenetrate = self.penetrationValue >= randomPenetration
        canDelay = self.delayValue >= randomDelay
        
        debugPrint("[ADS] [YandexBanner] 穿透阈值: \(self.penetrationValue) | 随机值: \(randomPenetration)")
        debugPrint("[ADS] [YandexBanner] 延迟阈值: \(self.delayValue) | 随机值: \(randomDelay)")
    }
    
    private func constructViewHierarchy() {
        view.backgroundColor = .white
        view.addSubview(mediaContent)
        mediaContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mediaContent.topAnchor.constraint(equalTo: view.topAnchor),
            mediaContent.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mediaContent.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mediaContent.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func configureCloseButton() {
        closeButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        closeButtonContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButtonContainer.layer.cornerRadius = 10
        view.addSubview(closeButtonContainer)
        
        closeButtonLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButtonLabel.textColor = .white
        closeButtonLabel.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        closeButtonLabel.textAlignment = .center
        closeButtonContainer.addSubview(closeButtonLabel)
        
        NSLayoutConstraint.activate([
            closeButtonContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            closeButtonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            closeButtonLabel.topAnchor.constraint(equalTo: closeButtonContainer.topAnchor, constant: 4),
            closeButtonLabel.leadingAnchor.constraint(equalTo: closeButtonContainer.leadingAnchor, constant: 10),
            closeButtonLabel.bottomAnchor.constraint(equalTo: closeButtonContainer.bottomAnchor, constant: -4),
            closeButtonLabel.trailingAnchor.constraint(equalTo: closeButtonContainer.trailingAnchor, constant: -10),
            closeButtonLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        closeButtonLabel.text = String(format: LocalizedText("Skip_Ad_Time"), remainingSeconds)
        
        let interactionEnabled = !canPenetrate
        closeButtonLabel.isUserInteractionEnabled = interactionEnabled
        closeButtonContainer.isUserInteractionEnabled = interactionEnabled
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeButtonTapped))
        closeButtonLabel.addGestureRecognizer(tapGesture)
    }
    
    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.updateCountdown(timer)
        }
    }
    
    // MARK: - Countdown Logic
    
    private func updateCountdown(_ timer: Timer) {
        let hasTimeRemaining = remainingSeconds > 0
        
        if hasTimeRemaining {
            remainingSeconds -= 1
            updateCloseButtonText()
        } else {
            closeButtonLabel.isUserInteractionEnabled = true
            closeButtonContainer.isUserInteractionEnabled = true
            updateCloseButtonText()
            timer.invalidate()
        }
    }
    
    private func activateCloseButton() {
        let shouldEnable = !canDelay || !canPenetrate
        
        if shouldEnable {
            closeButtonLabel.isUserInteractionEnabled = true
            closeButtonContainer.isUserInteractionEnabled = true
        }
    }
    
    private func updateCloseButtonText() {
        let timeExpired = remainingSeconds <= 0
        
        if timeExpired {
            activateCloseButton()
            closeButtonLabel.text = LocalizedText("Skip_Ad")
        } else {
            closeButtonLabel.text = String(format: LocalizedText("Skip_Ad_Time"), remainingSeconds)
        }
    }
    
    // MARK: - User Interaction
    
    @objc private func closeButtonTapped() {
        let canSkip = remainingSeconds <= 1
        if canSkip {
            closePresenter()
        }
    }
    
    private func closePresenter() {
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }
    
    // MARK: - Notifications
    
    private func attachNotificationObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleForegroundEvent),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }
    
    @objc private func handleForegroundEvent() {
        guard wasTapped else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.closePresenter()
        }
    }
}

