import Foundation
import Darwin
import Postbox
import SwiftSignalKit

private func hasActiveVpnInterface() -> Bool {
    var interfaces: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&interfaces) == 0 else { return false }
    defer { freeifaddrs(interfaces) }
    var cursor = interfaces
    while let interface = cursor {
        let value = interface.pointee
        let name = String(cString: value.ifa_name)
        if let address = value.ifa_addr,
           address.pointee.sa_family == UInt8(AF_INET) || address.pointee.sa_family == UInt8(AF_INET6),
           value.ifa_flags & UInt32(IFF_UP) != 0,
           ["utun", "ipsec", "ppp", "tun", "tap"].contains(where: { name.hasPrefix($0) }) {
            if address.pointee.sa_family == UInt8(AF_INET6) {
                var ipv6 = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_in6.self).pointee.sin6_addr
                let linkLocalOrUnspecified = withUnsafeBytes(of: &ipv6) { bytes -> Bool in
                    return bytes.allSatisfy { $0 == 0 } || (bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80)
                }
                if linkLocalOrUnspecified {
                    cursor = value.ifa_next
                    continue
                }
            }
            return true
        }
        cursor = value.ifa_next
    }
    return false
}

private final class ManagedProxyAutomation {
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let network: Network
    private let disposables = DisposableSet()
    private let healthDisposable = MetaDisposable()
    private let updateDisposable = MetaDisposable()
    private var timer: SwiftSignalKit.Timer?
    private var settings = ProxySettings.defaultSettings
    private var networkType: NetworkType = .none
    private var connectionStatus: ConnectionStatus = .waitingForNetwork
    private var foreground = false
    private var failureSince: TimeInterval?
    private var healthContext: ProxyServersStatuses?
    private var health: [ProxyServerSettings: ProxyServerStatus] = [:]

    init(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network, foreground: Signal<Bool, NoError>) {
        self.accountManager = accountManager
        self.network = network
        self.disposables.add((accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
        |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self else { return }
            let settings = data.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) ?? .defaultSettings
            if settings.activeServer != self.settings.activeServer || settings.servers != self.settings.servers || settings.autoSwitch != self.settings.autoSwitch || settings.autoSwitchDelay != self.settings.autoSwitchDelay || settings.enabled != self.settings.enabled || settings.automaticallyDisabled != self.settings.automaticallyDisabled {
                self.resetFailure()
            }
            self.settings = settings
            self.tick()
        }))
        self.disposables.add((currentNetworkType() |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else { return }
            if self.networkType != value { self.resetFailure() }
            self.networkType = value
            self.tick()
        }))
        self.disposables.add((network.connectionStatus |> deliverOnMainQueue).start(next: { [weak self] value in
            self?.connectionStatus = value
            self?.tick()
        }))
        self.disposables.add((foreground |> distinctUntilChanged |> deliverOnMainQueue).start(next: { [weak self] value in
            self?.foreground = value
            if !value { self?.resetFailure() }
            self?.tick()
        }))
        let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in self?.tick() }, queue: .mainQueue())
        self.timer = timer
        timer.start()
    }

    deinit {
        self.timer?.invalidate()
        self.disposables.dispose()
        self.healthDisposable.dispose()
        self.updateDisposable.dispose()
    }

    private func resetFailure() {
        self.failureSince = nil
        self.healthDisposable.set(nil)
        self.healthContext = nil
        self.health = [:]
    }

    private func startHealthCheck() {
        let context = ProxyServersStatuses(network: self.network, servers: .single(self.settings.servers))
        self.healthContext = context
        self.healthDisposable.set((context.statuses() |> deliverOnMainQueue).start(next: { [weak self] value in self?.health = value }))
    }

    private func tick() {
        let mask = self.settings.disableOnNetworks
        var suppressed = mask & 1 != 0 && hasActiveVpnInterface()
        switch self.networkType {
        case .wifi: suppressed = suppressed || mask & 4 != 0
        #if os(iOS)
        case .cellular: suppressed = suppressed || mask & 2 != 0
        #endif
        case .none: break
        }
        if suppressed != self.settings.automaticallyDisabled {
            let expectedMask = mask
            self.updateDisposable.set(updateProxySettingsInteractively(accountManager: self.accountManager, { current in
                var current = current
                if current.disableOnNetworks == expectedMask { current.automaticallyDisabled = suppressed }
                return current
            }).start())
            self.resetFailure()
            return
        }
        guard self.foreground, self.settings.autoSwitch, self.settings.enabled, !suppressed,
              self.settings.servers.count > 1, self.networkType != .none else {
            self.resetFailure()
            return
        }
        switch self.connectionStatus {
        case .online, .updating:
            self.resetFailure()
            return
        case .connecting, .waitingForNetwork: break
        }
        let now = ProcessInfo.processInfo.systemUptime
        if self.failureSince == nil {
            self.failureSince = now
            self.startHealthCheck()
            return
        }
        guard now - (self.failureSince ?? now) >= Double(self.settings.autoSwitchDelay) else { return }
        let candidates = self.settings.servers.compactMap { server -> (ProxyServerSettings, Double)? in
            guard server != self.settings.activeServer, case let .available(ping)? = self.health[server] else { return nil }
            return (server, ping)
        }.sorted { $0.1 < $1.1 }
        if let candidate = candidates.first?.0 {
            let previousServer = self.settings.activeServer
            self.updateDisposable.set(updateProxySettingsInteractively(accountManager: self.accountManager, { current in
                var current = current
                if current.enabled && current.autoSwitch && !current.automaticallyDisabled && current.activeServer == previousServer && current.servers.contains(candidate) {
                    current.activeServer = candidate
                }
                return current
            }).start())
        }
        // Retry unavailable lists with fresh pings, without reconnecting a working server.
        self.failureSince = now
        self.startHealthCheck()
    }
}

func managedProxyAutomation(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network, foreground: Signal<Bool, NoError>) -> Disposable {
    let manager = QueueLocalObject<ManagedProxyAutomation>(queue: .mainQueue(), generate: {
        return ManagedProxyAutomation(accountManager: accountManager, network: network, foreground: foreground)
    })
    return ActionDisposable { manager.with { _ in } }
}
