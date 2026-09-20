import Foundation

public final class BGSimpleSettings {
    public static let shared = BGSimpleSettings()

    private enum Key {
        static let experimentalFeatures = "bahogram.experimentalFeatures"
        static let showFeatureDescriptions = "bahogram.showFeatureDescriptions"

        static let saveDeletedMessages = "bahogram.spy.saveDeletedMessages"
        static let saveEditHistory = "bahogram.spy.saveEditHistory"
        static let saveInBotChats = "bahogram.spy.saveInBotChats"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Key.showFeatureDescriptions) == nil {
            defaults.set(true, forKey: Key.showFeatureDescriptions)
        }
        if defaults.object(forKey: Key.saveDeletedMessages) == nil {
            defaults.set(true, forKey: Key.saveDeletedMessages)
        }
        if defaults.object(forKey: Key.saveEditHistory) == nil {
            defaults.set(true, forKey: Key.saveEditHistory)
        }
        if defaults.object(forKey: Key.saveInBotChats) == nil {
            defaults.set(false, forKey: Key.saveInBotChats)
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

    public var saveDeletedMessages: Bool {
        get {
            return self.defaults.bool(forKey: Key.saveDeletedMessages)
        }
        set {
            self.defaults.set(newValue, forKey: Key.saveDeletedMessages)
        }
    }

    public var saveEditHistory: Bool {
        get {
            return self.defaults.bool(forKey: Key.saveEditHistory)
        }
        set {
            self.defaults.set(newValue, forKey: Key.saveEditHistory)
        }
    }

    public var saveInBotChats: Bool {
        get {
            return self.defaults.bool(forKey: Key.saveInBotChats)
        }
        set {
            self.defaults.set(newValue, forKey: Key.saveInBotChats)
        }
    }
}
