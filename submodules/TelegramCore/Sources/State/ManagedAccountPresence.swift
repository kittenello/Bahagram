import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit
import DGSimpleSettings

private typealias SignalKitTimer = SwiftSignalKit.Timer


private final class AccountPresenceManagerImpl {
    private let queue: Queue
    private let network: Network
    private let accountId: Int64
    let isPerformingUpdate = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private var shouldKeepOnlinePresenceDisposable: Disposable?
    private let currentRequestDisposable = MetaDisposable()
    private var onlineTimer: SignalKitTimer?
    private var offlineTimer: SignalKitTimer?
    private var settingsObserver: NSObjectProtocol?
    private var offlineRequestObserver: NSObjectProtocol?
    
    private var wasOnline: Bool = false
    private var lastAcknowledgedPresenceOnline: Bool = false
    
    init(queue: Queue, shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network, accountId: Int64) {
        self.queue = queue
        self.network = network
        self.accountId = accountId
        
        self.shouldKeepOnlinePresenceDisposable = (shouldKeepOnlinePresence
        |> distinctUntilChanged
        |> deliverOn(self.queue)).start(next: { [weak self] value in
            guard let `self` = self else {
                return
            }
            if self.wasOnline != value {
                self.wasOnline = value
                self.updatePresence(value)
            }
        })

        self.settingsObserver = NotificationCenter.default.addObserver(forName: DGSimpleSettings.didChangeNotification, object: DGSimpleSettings.shared, queue: nil, using: { [weak self] _ in
            guard let self else {
                return
            }
            self.queue.async { [weak self] in
                guard let self else {
                    return
                }
                // UserDefaults changes are independent from the foreground
                // signal. Re-evaluate immediately so enabling ghost mode while
                // the app is active sends an offline packet right away.
                self.updatePresence(self.wasOnline)
            }
        })
        self.offlineRequestObserver = NotificationCenter.default.addObserver(forName: DGSimpleSettings.requestOfflineNotification, object: DGSimpleSettings.shared, queue: nil, using: { [weak self] _ in
            self?.queue.async { [weak self] in
                self?.requestOfflinePresence()
            }
        })
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.shouldKeepOnlinePresenceDisposable?.dispose()
        self.currentRequestDisposable.dispose()
        self.onlineTimer?.invalidate()
        self.offlineTimer?.invalidate()
        if let settingsObserver = self.settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        if let offlineRequestObserver = self.offlineRequestObserver {
            NotificationCenter.default.removeObserver(offlineRequestObserver)
        }
    }

    private func recordAcknowledgedPresence(isOnline: Bool, timestamp: Int32) {
        if isOnline || self.lastAcknowledgedPresenceOnline {
            DGSimpleSettings.shared.setLastOnlineTimestamp(timestamp, accountId: self.accountId)
        }
        // Repeated offline requests must keep the original last-seen time.
        self.lastAcknowledgedPresenceOnline = isOnline
    }

    private func requestOfflinePresence() {
        let timestamp = Int32(Date().timeIntervalSince1970)
        let request = self.network.request(Api.functions.account.updateStatus(offline: .boolTrue))
        self.isPerformingUpdate.set(true)
        self.currentRequestDisposable.set((request
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> deliverOn(self.queue)).start(next: { [weak self] result in
            if case .boolTrue = result {
                self?.recordAcknowledgedPresence(isOnline: false, timestamp: timestamp)
            }
        }, completed: { [weak self] in
            self?.isPerformingUpdate.set(false)
        }))
    }
    
    private func updatePresence(_ isOnline: Bool) {
        let ghost = DGSimpleSettings.shared
        let effectiveOnline = isOnline && !ghost.ghostHidesOnline
        let timestamp = Int32(Date().timeIntervalSince1970)
        let request: Signal<Api.Bool, MTRpcError>
        if effectiveOnline {
            self.offlineTimer?.invalidate()
            self.offlineTimer = nil
            let timer = SignalKitTimer(timeout: 30.0, repeat: false, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updatePresence(true)
            }, queue: self.queue)
            self.onlineTimer = timer
            timer.start()
            request = self.network.request(Api.functions.account.updateStatus(offline: .boolFalse))
        } else {
            self.onlineTimer?.invalidate()
            self.onlineTimer = nil
            let keepForcingOffline = ghost.ghostModeEnabled && ghost.ghostAutomaticOffline
            if keepForcingOffline && self.offlineTimer == nil {
                let timer = SignalKitTimer(timeout: 1.0, repeat: true, completion: { [weak self] in
                    self?.requestOfflinePresence()
                }, queue: self.queue)
                self.offlineTimer = timer
                timer.start()
            } else if !keepForcingOffline {
                self.offlineTimer?.invalidate()
                self.offlineTimer = nil
            }
            request = self.network.request(Api.functions.account.updateStatus(offline: .boolTrue))
        }
        self.isPerformingUpdate.set(true)
        self.currentRequestDisposable.set((request
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> deliverOn(self.queue)).start(next: { [weak self] result in
            if case .boolTrue = result {
                self?.recordAcknowledgedPresence(isOnline: effectiveOnline, timestamp: timestamp)
            }
        }, completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isPerformingUpdate.set(false)
        }))
    }
}

final class AccountPresenceManager {
    private let queue = Queue()
    private let impl: QueueLocalObject<AccountPresenceManagerImpl>
    
    init(shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network, accountId: Int64) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return AccountPresenceManagerImpl(queue: queue, shouldKeepOnlinePresence: shouldKeepOnlinePresence, network: network, accountId: accountId)
        })
    }
    
    func isPerformingUpdate() -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.isPerformingUpdate.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
}
