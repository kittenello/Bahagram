import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit
import BGSimpleSettings

private typealias SignalKitTimer = SwiftSignalKit.Timer


private final class AccountPresenceManagerImpl {
    private let queue: Queue
    private let network: Network
    let isPerformingUpdate = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private var shouldKeepOnlinePresenceDisposable: Disposable?
    private let currentRequestDisposable = MetaDisposable()
    private var onlineTimer: SignalKitTimer?
    private var offlineTimer: SignalKitTimer?
    private var settingsObserver: NSObjectProtocol?
    
    private var wasOnline: Bool = false
    
    init(queue: Queue, shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network) {
        self.queue = queue
        self.network = network
        
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

        self.settingsObserver = NotificationCenter.default.addObserver(forName: BGSimpleSettings.didChangeNotification, object: BGSimpleSettings.shared, queue: nil, using: { [weak self] _ in
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
    }

    private func requestOfflinePresence() {
        let request = self.network.request(Api.functions.account.updateStatus(offline: .boolTrue))
        self.isPerformingUpdate.set(true)
        self.currentRequestDisposable.set((request
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> deliverOn(self.queue)).start(completed: { [weak self] in
            self?.isPerformingUpdate.set(false)
        }))
    }
    
    private func updatePresence(_ isOnline: Bool) {
        let ghost = BGSimpleSettings.shared
        let effectiveOnline = isOnline && !(ghost.ghostModeEnabled && !ghost.ghostSendOnline)
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
                let timer = SignalKitTimer(timeout: 3.0, repeat: true, completion: { [weak self] in
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
        |> deliverOn(self.queue)).start(completed: { [weak self] in
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
    
    init(shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return AccountPresenceManagerImpl(queue: queue, shouldKeepOnlinePresence: shouldKeepOnlinePresence, network: network)
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
