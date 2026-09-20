import Foundation

public final class BGSimpleSettings {
    public static let shared = BGSimpleSettings()

    private enum Key {
        static let saveDeletedMessages = "bahogram.spy.saveDeletedMessages"
        static let semiTransparentDeletedMessages = "bahogram.spy.semiTransparentDeletedMessages"
        static let saveEditHistory = "bahogram.spy.saveEditHistory"
        static let saveViewOnceMedia = "bahogram.spy.saveViewOnceMedia"
        static let saveInBotChats = "bahogram.spy.saveInBotChats"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Key.saveDeletedMessages) == nil {
            defaults.set(true, forKey: Key.saveDeletedMessages)
        }
        if defaults.object(forKey: Key.semiTransparentDeletedMessages) == nil {
            defaults.set(false, forKey: Key.semiTransparentDeletedMessages)
        }
        if defaults.object(forKey: Key.saveEditHistory) == nil {
            defaults.set(true, forKey: Key.saveEditHistory)
        }
        if defaults.object(forKey: Key.saveViewOnceMedia) == nil {
            defaults.set(false, forKey: Key.saveViewOnceMedia)
        }
        if defaults.object(forKey: Key.saveInBotChats) == nil {
            defaults.set(false, forKey: Key.saveInBotChats)
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

    public var semiTransparentDeletedMessages: Bool {
        get {
            return self.defaults.bool(forKey: Key.semiTransparentDeletedMessages)
        }
        set {
            self.defaults.set(newValue, forKey: Key.semiTransparentDeletedMessages)
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

    public var saveViewOnceMedia: Bool {
        get {
            return self.defaults.bool(forKey: Key.saveViewOnceMedia)
        }
        set {
            self.defaults.set(newValue, forKey: Key.saveViewOnceMedia)
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
