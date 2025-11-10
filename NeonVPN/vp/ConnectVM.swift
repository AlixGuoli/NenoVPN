import Foundation
import NetworkExtension

final class ConnectVM: ObservableObject {

    enum Stage { case disconnected, connecting, connected, failed }

    @Published var stage: Stage = .disconnected
    // 系统原始状态：仅记录，不直接用于 UI
    @Published var systemStatus: NEVPNStatus = .invalid
    // 结果页导航控制
    @Published var navigateToResult: Bool = false
    @Published var resultIsSuccess: Bool = false
    // 连接页导航控制
    @Published var showConnectingView: Bool = false
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
                        self.stage = .failed
                        self.userInitiated = false
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
            stage = .connecting // 过渡态，按钮禁用
            mgr.connection.stopVPNTunnel()
        default:
            break
        }
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
            // 若为用户主动触发，则由业务后续通知成功/失败，不立刻切 UI 成功
            if userInitiated {
                debugPrint("🟡 手动连接")
                notifyConnectSucceeded()
                break
            } else {
                debugPrint("🟡 自动连接")
                stage = .connected
            }
        case .disconnected, .invalid:
            debugPrint("🟡 连接断开，navigateToResult: \(navigateToResult)")
            stage = .disconnected
            userInitiated = false
            stopConnectionTimer()
            NetworkMonitor.shared.stopVPNConnection()
            historyManager.recordConnectionDisconnect() // 记录连接断开
        case .connecting:
            stage = .connecting
        case .disconnecting, .reasserting:
            stage = .connecting
        @unknown default:
            stage = .failed
            userInitiated = false
        }
    }

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
        resultIsSuccess = true
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
        resultIsSuccess = false
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
