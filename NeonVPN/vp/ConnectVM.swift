import Foundation
import NetworkExtension

final class ConnectVM: ObservableObject {

    enum Stage { case disconnected, connecting, connected, failed }
    
    enum ResultType {
        case success    // 连接成功
        case failed     // 连接失败
        case disconnected  // 断开成功
    }

    @Published var stage: Stage = .disconnected
    // 系统原始状态：仅记录，不直接用于 UI
    @Published var systemStatus: NEVPNStatus = .invalid
    // 结果页导航控制
    @Published var navigateToResult: Bool = false
    @Published var resultType: ResultType = .failed
    // 连接页导航控制
    @Published var showConnectingView: Bool = false
    // 断开确认弹窗
    @Published var showDisconnectConfirm: Bool = false
    // 连接时间统计
    @Published var connectionDuration: TimeInterval = 0
    @Published var formattedDuration: String = "00:00:00"
    // 对齐旧实现：系统态 state -> didSet 触发统一映射入口
    @Published var state: NEVPNStatus = .invalid {
        didSet {
            guard oldValue != state else { return }
            applyStateToUI(state)
        }
    }

    private var manager: NETunnelProviderManager?
    private let config = Config()
    private var userInitiated: Bool = false // 是否用户主动发起连接
    private var connectionStartTime: Date?
    private var timer: Timer?
    private let connectionTimeKey = "connectionStartTime"
    private let historyManager = ConnectionHistoryManager.shared

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(onSystemStatus), name: .NEVPNStatusDidChange, object: nil)
        bootstrap()
        setupTimer()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }

    // MARK: - Public API

    func beginSession() {
        // 发起连接；进行中时直接返回
        guard stage != .connecting else { return }
        stage = .connecting
        userInitiated = true
        
        Task {
            // 第一步：获取服务配置
            try? await loadService()
            
            // 继续连接逻辑
            loadOrCreateManager { [weak self] mgr in
            guard let self = self, let mgr = mgr else { self?.stage = .failed; return }
            self.enableAndReload(mgr) { ok in
                guard ok else { self.stage = .failed; return }
                // 延迟 3 秒后再开始实际连接，用于展示"处理中"过程
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    // 在3秒延迟后记录连接开始时间
                    let selectedServer = UserDefaults.standard.string(forKey: "selectedServerCode") ?? "auto"
                    let serverName = self.getServerDisplayName(for: selectedServer)
                    self.historyManager.recordConnectionStart(server: serverName)
                    
                    do {
                        try mgr.connection.startVPNTunnel()
                    } catch {
                        debugPrint("[CONNECT] startVPNTunnel 失败: \(error)")
                    }
                }
            }
            }
        }
    }

    func endSession() {
        // 断开连接；进行中时直接返回
        guard stage != .connecting else { return }
        guard let mgr = manager else { return }
        switch mgr.connection.status {
        case .connected, .connecting, .reasserting:
            // 显示确认弹窗
            showDisconnectConfirm = true
        default:
            break
        }
    }
    
    /// 确认断开连接
    func confirmDisconnect() {
        guard let mgr = manager else { return }
        showDisconnectConfirm = false
        stage = .connecting // 过渡态，按钮禁用
        mgr.connection.stopVPNTunnel()
        resultType = .disconnected
        navigateToResult = true
    }
    
    /// 取消断开连接
    func cancelDisconnect() {
        showDisconnectConfirm = false
    }

    // MARK: - Private

    private func bootstrap() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] list, _ in
            guard let self = self else { return }
            self.manager = list?.first
            let s = self.manager?.connection.status ?? .invalid
            DispatchQueue.main.async {
                self.systemStatus = s
                self.state = s // 首帧触发一次映射
                // 如果系统已连接，恢复连接时间
                if s == .connected {
                    self.restoreConnectionTime()
                }
            }
        }
    }

    @objc private func onSystemStatus() {
        let s = manager?.connection.status ?? .invalid
        systemStatus = s
        // 常规路径：仅更新系统态，由 didSet 统一映射
        state = s
    }

    // 统一映射入口（对齐旧实现 applyStateToUI）
    private func applyStateToUI(_ newState: NEVPNStatus) {
        debugPrint("🟡 applyStateToUI: \(newState), userInitiated: \(userInitiated), navigateToResult: \(navigateToResult)")
        switch newState {
        case .connected:
            // 若为用户主动触发，先探测网络，再通知成功/失败
            if userInitiated {
                debugPrint("🟡 手动连接，开始探测网络")
                checkConnectivity()
            } else {
                debugPrint("🟡 自动连接")
                stage = .connected
            }
        case .disconnected, .invalid:
            debugPrint("🟡 连接断开，navigateToResult: \(navigateToResult)")
            if userInitiated {
                // 用户主动连接失败，需要关闭连接页并弹出结果页
                notifyConnectFailed()
            } else if resultType == .disconnected {
                // 用户手动断开，显示断开成功结果页
                stage = .disconnected
                userInitiated = false
                stopConnectionTimer()
                NetworkMonitor.shared.stopVPNConnection()
                historyManager.recordConnectionDisconnect() // 记录连接断开
                navigateToResult = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showConnectingView = false
                }
            } else {
                // 自动断开或其他情况
                stage = .disconnected
                userInitiated = false
                stopConnectionTimer()
                NetworkMonitor.shared.stopVPNConnection()
                historyManager.recordConnectionDisconnect() // 记录连接断开
            }
        case .connecting:
            stage = .connecting
        case .disconnecting, .reasserting:
            stage = .connecting
        @unknown default:
            stage = .failed
            userInitiated = false
        }
    }


    // 无表驱动：使用 applyStateToUI 保持可读逻辑

    
    // MARK: - 连接时间统计
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateConnectionDuration()
        }
    }
    
    private func startConnectionTimer() {
        connectionStartTime = Date()
        UserDefaults.standard.set(connectionStartTime, forKey: connectionTimeKey)
    }
    
    private func stopConnectionTimer() {
        connectionStartTime = nil
        connectionDuration = 0
        formattedDuration = "00:00:00"
        UserDefaults.standard.removeObject(forKey: connectionTimeKey)
    }
    
    private func updateConnectionDuration() {
        guard stage == .connected else { return }
        
        let startTime: Date
        if let savedTime = connectionStartTime {
            startTime = savedTime
        } else if let savedTime = UserDefaults.standard.object(forKey: connectionTimeKey) as? Date {
            startTime = savedTime
            connectionStartTime = savedTime
        } else {
            return
        }
        
        connectionDuration = Date().timeIntervalSince(startTime)
        formattedDuration = formatDuration(connectionDuration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // 恢复连接时间（app重启后调用）
    func restoreConnectionTime() {
        guard stage == .connected else { return }
        
        if let savedTime = UserDefaults.standard.object(forKey: connectionTimeKey) as? Date {
            connectionStartTime = savedTime
            updateConnectionDuration()
        }
    }
    
    // MARK: - 历史记录通知方法
    
    func notifyConnectSucceeded() {
        stage = .connected
        userInitiated = false
        startConnectionTimer()
        NetworkMonitor.shared.startVPNConnection()
        TrafficStatsManager.shared.simulateVPNTraffic()
        historyManager.recordConnectionSuccess() // 记录连接成功
        resultType = .success
        // 先显示结果页，再关闭连接页，实现无缝衔接
        navigateToResult = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showConnectingView = false
        }
    }
    
    func notifyConnectFailed() {
        if let mgr = manager {
            switch mgr.connection.status {
            case .connected, .connecting, .reasserting:
                mgr.connection.stopVPNTunnel()
            default:
                break
            }
        }
        stage = .failed
        userInitiated = false
        stopConnectionTimer()
        NetworkMonitor.shared.stopVPNConnection()
        historyManager.recordConnectionFailure() // 记录连接失败
        resultType = .failed
        // 先显示结果页，再关闭连接页，实现无缝衔接
        navigateToResult = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showConnectingView = false
        }
    }
    
    // MARK: - 结果页管理
    
    func closeResultPage() {
        navigateToResult = false
    }
    
    // MARK: - 连接页管理
    
    func closeConnectingView() {
        showConnectingView = false
    }
    
    // MARK: - 辅助方法
    
    private func getServerDisplayName(for code: String) -> String {
        switch code {
        case "auto": return LocalizedText("auto_node")
        case "us": return "United States"
        case "uk": return "United Kingdom"
        case "sg": return "Singapore"
        case "jp": return "Japan"
        case "de": return "Germany"
        case "nl": return "Netherlands"
        case "ca": return "Canada"
        case "au": return "Australia"
        default: return "Unknown"
        }
    }
}

// MARK: - VPN 配置管理
extension ConnectVM {
    private func loadOrCreateManager(completion: @escaping (NETunnelProviderManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] list, _ in
            if let mgr = list?.first {
                self?.manager = mgr
                completion(mgr)
                return
            }
            // 新建（按之前做法：不设置 providerBundleIdentifier）
            let mgr = NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.serverAddress = self?.config.displayName
            // 可选：传参给扩展（使用非直观键名）
            // proto.providerConfiguration = ["x_cfg": ["p": "v1"]]

            mgr.protocolConfiguration = proto
            mgr.localizedDescription = self?.config.displayName
            mgr.isEnabled = true
            mgr.saveToPreferences { error in
                guard error == nil else { completion(nil); return }
                mgr.loadFromPreferences { error in
                    guard error == nil else { completion(nil); return }
                    self?.manager = mgr
                    completion(mgr)
                }
            }
        }
    }

    private func enableAndReload(_ mgr: NETunnelProviderManager, completion: @escaping (Bool) -> Void) {
        mgr.isEnabled = true
        mgr.saveToPreferences { error in
            guard error == nil else { completion(false); return }
            mgr.loadFromPreferences { error in
                completion(error == nil)
            }
        }
    }
    
    private struct Config { let displayName = "VPN Fly" }
}

// MARK: - 服务配置扩展
private extension ConnectVM {
    /// 加载服务配置
    func loadService() async throws {
        var encryptedConfig = await NetCenter.shared.getServiceEndpoint()
        //encryptedConfig = nil
        if encryptedConfig == nil || encryptedConfig?.isEmpty == true {
            debugPrint("[CONNECT] 请求服务配置失败，尝试从 UserDefaults 读取")
            encryptedConfig = ServiceVault.shared.load()
            
            if encryptedConfig == nil || encryptedConfig?.isEmpty == true {
                debugPrint("[CONNECT] !!! UserDefaults 中也没有服务配置")
                return
            }
            
            debugPrint("[CONNECT] 使用 UserDefaults 中的服务配置")
            ServiceVault.shared.currentConfig = encryptedConfig!
            ServiceVault.shared.isFromRequest = false
        } else {
            debugPrint("[CONNECT] 使用请求到的服务配置")
            ServiceVault.shared.currentConfig = encryptedConfig!
            ServiceVault.shared.isFromRequest = true
        }
        
        guard let payload = encryptedConfig else {
            debugPrint("[CONNECT] !!! 服务配置为空")
            return
        }
        
        guard let decryptedConfig = NetProfile.Sec.reveal(payload) else {
            debugPrint("[CONNECT] !!! 服务配置解密失败")
            return
        }
        
        debugPrint("[CONNECT] 解密后的服务配置: \(decryptedConfig)")
        
        // 解析配置，提取节点信息
        parseNetConfig(input: decryptedConfig, isValid: ServiceVault.shared.isFromRequest)
        
        // 保存到 Group，供 PacketTunnel 使用
        try await ConnectConfigHandler.shared.savedGroupServiceConfig(serviceConfig: decryptedConfig)
    }
    
    /// 解析服务配置，提取节点
    func parseNetConfig(input: String?, isValid: Bool) {
        guard let data = input?.data(using: .utf8) else { return }
        
        do {
            let parsed = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            let bounds = parsed?["outbounds"] as? [[String: Any]]
            
            bounds?.forEach { bound in
                let config = bound["settings"] as? [String: Any]
                let nodes = config?["vnext"] as? [[String: Any]]
                
                nodes?.forEach { node in
                    if let ip = node["address"] as? String {
                        let finalIp = isValid ? ip : "f\(ip)"
                        ServiceVault.shared.ipService = finalIp
                    }
                }
            }
        } catch {
            debugPrint("[CONNECT] 解析服务配置失败: \(error)")
        }
    }
    
    /// 检查网络连通性
    func checkConnectivity() {
        Task {
            let isConnected = await NetCenter.shared.checkConnectivity()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if isConnected {
                    debugPrint("[CONNECT] 网络探测成功")
                    self.notifyConnectSucceeded()
                } else {
                    debugPrint("[CONNECT] 网络探测失败")
                    self.notifyConnectFailed()
                }
            }
        }
    }
}
