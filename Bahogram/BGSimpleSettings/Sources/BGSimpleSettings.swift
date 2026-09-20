import Foundation

public final class BGSimpleSettings {
    public static let shared = BGSimpleSettings()

    private enum Key {
        static let experimentalFeatures = "bahogram.experimentalFeatures"
        static let showFeatureDescriptions = "bahogram.showFeatureDescriptions"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Key.showFeatureDescriptions) == nil {
            defaults.set(true, forKey: Key.showFeatureDescriptions)
        }
    }

    public var experimentalFeatures: Bool {
        get {
            return self.defaults.bool(forKey: Key.experimentalFeatures)
        }
        set {
            self.defaults.set(newValue, forKey: Key.experimentalFeatures)
        }
    }

    public var showFeatureDescriptions: Bool {
        get {
            return self.defaults.bool(forKey: Key.showFeatureDescriptions)
        }
        set {
            self.defaults.set(newValue, forKey: Key.showFeatureDescriptions)
        }
    }
}
