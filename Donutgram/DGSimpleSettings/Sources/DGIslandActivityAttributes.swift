import ActivityKit

@available(iOS 16.1, *)
public struct DGIslandActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var style: Int

        public init(style: Int) {
            self.style = style
        }
    }

    public init() {
    }
}
