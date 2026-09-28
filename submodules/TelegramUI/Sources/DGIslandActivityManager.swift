import ActivityKit
import DGSimpleSettings
import Foundation

@available(iOS 16.2, *)
@MainActor
final class DGIslandActivityManager {
    static let shared = DGIslandActivityManager()

    private var observer: NSObjectProtocol?
    private var activity: Activity<DGIslandActivityAttributes>?

    private init() {
        self.observer = NotificationCenter.default.addObserver(forName: DGSimpleSettings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func setForeground(_ value: Bool) {
        if value {
            Task { await self.refresh() }
        }
    }

    private func refresh() async {
        let style = DGSimpleSettings.shared.islandStyle
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            self.activity = nil
            return
        }

        let content = ActivityContent(state: DGIslandActivityAttributes.ContentState(style: style), staleDate: nil)
        if let activity = self.activity ?? Activity<DGIslandActivityAttributes>.activities.first {
            self.activity = activity
            await activity.update(content)
        } else {
            do {
                self.activity = try Activity.request(attributes: DGIslandActivityAttributes(), content: content, pushType: nil)
            } catch {
                NSLog("Donutgram island activity could not start: %@", String(describing: error))
            }
        }
    }
}
