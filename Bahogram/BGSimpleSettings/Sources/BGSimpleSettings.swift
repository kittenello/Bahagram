import Foundation

public final class BGSimpleSettings {
    public static let shared = BGSimpleSettings()
    public static let didChangeNotification = Notification.Name("bahogram.settings.didChange")

    private enum Key {
        static let saveDeletedMessages = "bahogram.spy.saveDeletedMessages"
        static let semiTransparentDeletedMessages = "bahogram.spy.semiTransparentDeletedMessages"
        static let saveEditHistory = "bahogram.spy.saveEditHistory"
        static let saveViewOnceMedia = "bahogram.spy.saveViewOnceMedia"
        static let saveInBotChats = "bahogram.spy.saveInBotChats"

        static let ghostModeEnabled = "bahogram.ghost.enabled"
        static let ghostReadMessages = "bahogram.ghost.readMessages"
        static let ghostReadStories = "bahogram.ghost.readStories"
        static let ghostSendOnline = "bahogram.ghost.sendOnline"
        static let ghostSendTyping = "bahogram.ghost.sendTyping"
        static let ghostAutomaticOffline = "bahogram.ghost.automaticOffline"
        static let ghostReadOnAction = "bahogram.ghost.readOnAction"
        static let ghostUseScheduledMessages = "bahogram.ghost.useScheduledMessages"
        static let ghostSendWithoutSound = "bahogram.ghost.sendWithoutSound"
        static let ghostSuggestForStories = "bahogram.ghost.suggestForStories"
        static let bypassForwardRestrictions = "bahogram.spy.bypassForwardRestrictions"
        static let visualPhoneEnabled = "bahogram.profile.visualPhoneEnabled"
        static let visualPhoneNumber = "bahogram.profile.visualPhoneNumber"

        static let hideTabBar = "bahogram.appearance.hideTabBar"
        static let showContactsTab = "bahogram.appearance.showContactsTab"
        static let showCallsTab = "bahogram.appearance.showCallsTab"
        static let wideTabBar = "bahogram.appearance.wideTabBar"
        static let showProfileId = "bahogram.appearance.showProfileId"
        static let showDc = "bahogram.appearance.showDc"
        static let showRegistrationDate = "bahogram.appearance.showRegistrationDate"
        static let showChatCreationDate = "bahogram.appearance.showChatCreationDate"
        static let confirmCalls = "bahogram.appearance.confirmCalls"
        static let disableAds = "bahogram.appearance.disableAds"

        static let onlyAddedStickers = "bahogram.chats.onlyAddedStickers"
        static let infiniteRecentStickers = "bahogram.chats.infiniteRecentStickers"
        static let hiddenReactions = "bahogram.chats.hiddenReactions"
        static let removeMessageTails = "bahogram.chats.removeMessageTails"
        static let hideShareButton = "bahogram.chats.hideShareButton"
        static let disableColoredReplies = "bahogram.chats.disableColoredReplies"
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
        let enabledByDefault = [Key.ghostReadMessages, Key.ghostReadStories, Key.ghostSendOnline, Key.ghostSendTyping, Key.showContactsTab, Key.showCallsTab, Key.showProfileId]
        for key in enabledByDefault where defaults.object(forKey: key) == nil {
            defaults.set(true, forKey: key)
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

    private func bool(_ key: String) -> Bool { self.defaults.bool(forKey: key) }
    private func setBool(_ value: Bool, _ key: String) {
        if self.defaults.object(forKey: key) != nil && self.defaults.bool(forKey: key) == value {
            return
        }
        self.defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: BGSimpleSettings.didChangeNotification, object: self)
    }
    private func integer(_ key: String) -> Int { self.defaults.integer(forKey: key) }
    private func setInteger(_ value: Int, _ key: String) { self.defaults.set(value, forKey: key) }
    private func string(_ key: String) -> String { self.defaults.string(forKey: key) ?? "" }
    private func setString(_ value: String, _ key: String) { self.defaults.set(value, forKey: key) }

    public var ghostModeEnabled: Bool {
        get {
            return bool(Key.ghostModeEnabled)
        }
        set {
            // Match AyuGram's master toggle: enabling ghost mode immediately
            // enables every privacy guard unless the user changes it afterwards.
            // This also makes upgrading from the old permissive defaults safe.
            ghostReadMessages = !newValue
            ghostReadStories = !newValue
            ghostSendOnline = !newValue
            ghostSendTyping = !newValue
            ghostAutomaticOffline = newValue
            setBool(newValue, Key.ghostModeEnabled)
        }
    }
    public var ghostReadMessages: Bool { get { bool(Key.ghostReadMessages) } set { setBool(newValue, Key.ghostReadMessages) } }
    public var ghostReadStories: Bool { get { bool(Key.ghostReadStories) } set { setBool(newValue, Key.ghostReadStories) } }
    public var ghostSendOnline: Bool { get { bool(Key.ghostSendOnline) } set { setBool(newValue, Key.ghostSendOnline) } }
    public var ghostSendTyping: Bool { get { bool(Key.ghostSendTyping) } set { setBool(newValue, Key.ghostSendTyping) } }
    public var ghostAutomaticOffline: Bool { get { bool(Key.ghostAutomaticOffline) } set { setBool(newValue, Key.ghostAutomaticOffline) } }
    public var ghostReadOnAction: Bool { get { bool(Key.ghostReadOnAction) } set { setBool(newValue, Key.ghostReadOnAction) } }
    public var ghostUseScheduledMessages: Bool { get { bool(Key.ghostUseScheduledMessages) } set { setBool(newValue, Key.ghostUseScheduledMessages) } }
    public var ghostSendWithoutSound: Int { get { integer(Key.ghostSendWithoutSound) } set { setInteger(newValue, Key.ghostSendWithoutSound) } }
    public var ghostSuggestForStories: Bool { get { bool(Key.ghostSuggestForStories) } set { setBool(newValue, Key.ghostSuggestForStories) } }
    public var bypassForwardRestrictions: Bool { get { bool(Key.bypassForwardRestrictions) } set { setBool(newValue, Key.bypassForwardRestrictions) } }
    public var visualPhoneEnabled: Bool { get { bool(Key.visualPhoneEnabled) } set { setBool(newValue, Key.visualPhoneEnabled) } }
    public var visualPhoneNumber: String { get { string(Key.visualPhoneNumber) } set { setString(newValue, Key.visualPhoneNumber) } }

    public var hideTabBar: Bool { get { bool(Key.hideTabBar) } set { setBool(newValue, Key.hideTabBar) } }
    public var showContactsTab: Bool { get { bool(Key.showContactsTab) } set { setBool(newValue, Key.showContactsTab) } }
    public var showCallsTab: Bool { get { bool(Key.showCallsTab) } set { setBool(newValue, Key.showCallsTab) } }
    public var wideTabBar: Bool { get { bool(Key.wideTabBar) } set { setBool(newValue, Key.wideTabBar) } }
    public var showProfileId: Bool { get { bool(Key.showProfileId) } set { setBool(newValue, Key.showProfileId) } }
    public var showDc: Bool { get { bool(Key.showDc) } set { setBool(newValue, Key.showDc) } }
    public var showRegistrationDate: Bool { get { bool(Key.showRegistrationDate) } set { setBool(newValue, Key.showRegistrationDate) } }
    public var showChatCreationDate: Bool { get { bool(Key.showChatCreationDate) } set { setBool(newValue, Key.showChatCreationDate) } }
    public var confirmCalls: Bool { get { bool(Key.confirmCalls) } set { setBool(newValue, Key.confirmCalls) } }
    public var disableAds: Bool { get { bool(Key.disableAds) } set { setBool(newValue, Key.disableAds) } }

    public var onlyAddedStickers: Bool { get { bool(Key.onlyAddedStickers) } set { setBool(newValue, Key.onlyAddedStickers) } }
    public var infiniteRecentStickers: Bool { get { bool(Key.infiniteRecentStickers) } set { setBool(newValue, Key.infiniteRecentStickers) } }
    public var hiddenReactions: Int { get { integer(Key.hiddenReactions) } set { setInteger(newValue, Key.hiddenReactions) } }
    public var removeMessageTails: Bool { get { bool(Key.removeMessageTails) } set { setBool(newValue, Key.removeMessageTails) } }
    public var hideShareButton: Bool { get { false } set { } }
    public var disableColoredReplies: Bool { get { bool(Key.disableColoredReplies) } set { setBool(newValue, Key.disableColoredReplies) } }
}
