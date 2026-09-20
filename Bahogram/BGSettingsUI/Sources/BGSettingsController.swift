import Foundation
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import BGSimpleSettings

private final class BGSettingsArguments {
    let openSpyMode: () -> Void
    let openChats: () -> Void
    let openAppearance: () -> Void
    let openSupport: () -> Void

    init(openSpyMode: @escaping () -> Void, openChats: @escaping () -> Void, openAppearance: @escaping () -> Void, openSupport: @escaping () -> Void) {
        self.openSpyMode = openSpyMode
        self.openChats = openChats
        self.openAppearance = openAppearance
        self.openSupport = openSupport
    }
}

private struct BGSettingsState: Equatable {
}

private enum BGSettingsSection: Int32 {
    case general
    case about
}

private enum BGSettingsEntry: ItemListNodeEntry {
    case generalHeader
    case spyMode
    case chats
    case appearance
    case support
    case aboutHeader
    case aboutInfo

    var section: ItemListSectionId {
        switch self {
        case .generalHeader, .spyMode, .chats, .appearance, .support:
            return BGSettingsSection.general.rawValue
        case .aboutHeader, .aboutInfo:
            return BGSettingsSection.about.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .generalHeader: return 0
        case .spyMode: return 1
        case .chats: return 2
        case .appearance: return 3
        case .support: return 4
        case .aboutHeader: return 10
        case .aboutInfo: return 11
        }
    }

    static func < (lhs: BGSettingsEntry, rhs: BGSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BGSettingsArguments
        switch self {
        case .generalHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "BAHOGRAM", sectionId: self.section)
        case .spyMode:
            return self.disclosureItem(presentationData: presentationData, title: "Режим шпиона", action: arguments.openSpyMode)
        case .chats:
            return self.disclosureItem(presentationData: presentationData, title: "Чаты", action: arguments.openChats)
        case .appearance:
            return self.disclosureItem(presentationData: presentationData, title: "Оформление", action: arguments.openAppearance)
        case .support:
            return self.disclosureItem(presentationData: presentationData, title: "Поддержка", action: arguments.openSupport)
        case .aboutHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ABOUT", sectionId: self.section)
        case .aboutInfo:
            return ItemListTextItem(presentationData: presentationData, text: .markdown("Bahogram is an unofficial client based on Telegram for iOS."), sectionId: self.section)
        }
    }

    private func disclosureItem(presentationData: ItemListPresentationData, title: String, action: @escaping () -> Void) -> ListViewItem {
        return ItemListDisclosureItem(
            presentationData: presentationData,
            systemStyle: .glass,
            title: title,
            label: "",
            sectionId: self.section,
            style: .blocks,
            disclosureStyle: .arrow,
            action: action
        )
    }
}

private func bgSettingsEntries(state: BGSettingsState) -> [BGSettingsEntry] {
    return [.generalHeader, .spyMode, .chats, .appearance, .support, .aboutHeader, .aboutInfo]
}

public func bgSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(BGSettingsState(), ignoreRepeated: true)
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = BGSettingsArguments(
        openSpyMode: { pushControllerImpl?(bgSpySettingsController(context: context)) },
        openChats: {
            pushControllerImpl?(bgPlaceholderSettingsController(context: context, title: "Чаты", description: "Настройки чатов Bahogram будут находиться в этом разделе."))
        },
        openAppearance: {
            pushControllerImpl?(bgPlaceholderSettingsController(context: context, title: "Оформление", description: "Настройки внешнего вида Bahogram будут находиться в этом разделе."))
        },
        openSupport: {
            pushControllerImpl?(bgPlaceholderSettingsController(context: context, title: "Поддержка", description: "Информация и способы связи с поддержкой Bahogram будут находиться здесь."))
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Bahogram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: bgSettingsEntries(state: state),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] pushedController in
        (controller?.navigationController as? NavigationController)?.pushViewController(pushedController)
    }
    return controller
}

private enum BGPlaceholderEntry: ItemListNodeEntry {
    case info(String)

    var section: ItemListSectionId { return 0 }
    var stableId: Int32 { return 0 }

    static func < (lhs: BGPlaceholderEntry, rhs: BGPlaceholderEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        }
    }
}

private func bgPlaceholderSettingsController(context: AccountContext, title: String, description: String) -> ViewController {
    let signal = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: [BGPlaceholderEntry.info(description)],
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, NSObject()))
    }
    return ItemListController(context: context, state: signal)
}

private final class BGSpySettingsArguments {
    let updateSaveDeletedMessages: (Bool) -> Void
    let updateSemiTransparentDeletedMessages: (Bool) -> Void
    let updateSaveEditHistory: (Bool) -> Void
    let updateSaveViewOnceMedia: (Bool) -> Void
    let updateSaveInBotChats: (Bool) -> Void

    init(
        updateSaveDeletedMessages: @escaping (Bool) -> Void,
        updateSemiTransparentDeletedMessages: @escaping (Bool) -> Void,
        updateSaveEditHistory: @escaping (Bool) -> Void,
        updateSaveViewOnceMedia: @escaping (Bool) -> Void,
        updateSaveInBotChats: @escaping (Bool) -> Void
    ) {
        self.updateSaveDeletedMessages = updateSaveDeletedMessages
        self.updateSemiTransparentDeletedMessages = updateSemiTransparentDeletedMessages
        self.updateSaveEditHistory = updateSaveEditHistory
        self.updateSaveViewOnceMedia = updateSaveViewOnceMedia
        self.updateSaveInBotChats = updateSaveInBotChats
    }
}

private struct BGSpySettingsState: Equatable {
    var saveDeletedMessages: Bool
    var semiTransparentDeletedMessages: Bool
    var saveEditHistory: Bool
    var saveViewOnceMedia: Bool
    var saveInBotChats: Bool
}

private enum BGSpySettingsEntry: ItemListNodeEntry {
    case header
    case saveDeletedMessages(Bool)
    case semiTransparentDeletedMessages(Bool)
    case saveEditHistory(Bool)
    case saveViewOnceMedia(Bool)
    case saveInBotChats(Bool)
    case info

    var section: ItemListSectionId { return 0 }

    var stableId: Int32 {
        switch self {
        case .header: return 0
        case .saveDeletedMessages: return 1
        case .semiTransparentDeletedMessages: return 2
        case .saveEditHistory: return 3
        case .saveViewOnceMedia: return 4
        case .saveInBotChats: return 5
        case .info: return 6
        }
    }

    static func < (lhs: BGSpySettingsEntry, rhs: BGSpySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BGSpySettingsArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "СОХРАНЕНИЕ СООБЩЕНИЙ", sectionId: self.section)
        case let .saveDeletedMessages(value):
            return self.switchItem(presentationData: presentationData, title: "Сохранять удаленки", value: value, updated: arguments.updateSaveDeletedMessages)
        case let .semiTransparentDeletedMessages(value):
            return self.switchItem(presentationData: presentationData, title: "Полупрозрачные удаленки", value: value, updated: arguments.updateSemiTransparentDeletedMessages)
        case let .saveEditHistory(value):
            return self.switchItem(presentationData: presentationData, title: "Сохранять историю правок", value: value, updated: arguments.updateSaveEditHistory)
        case let .saveViewOnceMedia(value):
            return self.switchItem(presentationData: presentationData, title: "Сохранять одноразки", value: value, updated: arguments.updateSaveViewOnceMedia)
        case let .saveInBotChats(value):
            return self.switchItem(presentationData: presentationData, title: "Сохранять в чатах с ботами", value: value, updated: arguments.updateSaveInBotChats)
        case .info:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .markdown("Удаленки, история правок и одноразовые медиа сохраняются локально на этом устройстве. Сохранённые одноразки открываются и сохраняются как обычные фото и видео."),
                sectionId: self.section
            )
        }
    }

    private func switchItem(presentationData: ItemListPresentationData, title: String, value: Bool, updated: @escaping (Bool) -> Void) -> ListViewItem {
        return ItemListSwitchItem(
            presentationData: presentationData,
            systemStyle: .glass,
            title: title,
            value: value,
            sectionId: self.section,
            style: .blocks,
            updated: updated
        )
    }
}

private func bgSpySettingsEntries(state: BGSpySettingsState) -> [BGSpySettingsEntry] {
    var entries: [BGSpySettingsEntry] = [.header, .saveDeletedMessages(state.saveDeletedMessages)]
    if state.saveDeletedMessages {
        entries.append(.semiTransparentDeletedMessages(state.semiTransparentDeletedMessages))
    }
    entries.append(contentsOf: [
        .saveEditHistory(state.saveEditHistory),
        .saveViewOnceMedia(state.saveViewOnceMedia),
        .saveInBotChats(state.saveInBotChats),
        .info
    ])
    return entries
}

public func bgSpySettingsController(context: AccountContext) -> ViewController {
    let initialState = BGSpySettingsState(
        saveDeletedMessages: BGSimpleSettings.shared.saveDeletedMessages,
        semiTransparentDeletedMessages: BGSimpleSettings.shared.semiTransparentDeletedMessages,
        saveEditHistory: BGSimpleSettings.shared.saveEditHistory,
        saveViewOnceMedia: BGSimpleSettings.shared.saveViewOnceMedia,
        saveInBotChats: BGSimpleSettings.shared.saveInBotChats
    )
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((BGSpySettingsState) -> BGSpySettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { current in f(current) })
    }

    let arguments = BGSpySettingsArguments(
        updateSaveDeletedMessages: { value in
            BGSimpleSettings.shared.saveDeletedMessages = value
            updateState { current in
                var current = current
                current.saveDeletedMessages = value
                return current
            }
        },
        updateSemiTransparentDeletedMessages: { value in
            BGSimpleSettings.shared.semiTransparentDeletedMessages = value
            updateState { current in
                var current = current
                current.semiTransparentDeletedMessages = value
                return current
            }
        },
        updateSaveEditHistory: { value in
            BGSimpleSettings.shared.saveEditHistory = value
            updateState { current in
                var current = current
                current.saveEditHistory = value
                return current
            }
        },
        updateSaveViewOnceMedia: { value in
            BGSimpleSettings.shared.saveViewOnceMedia = value
            updateState { current in
                var current = current
                current.saveViewOnceMedia = value
                return current
            }
        },
        updateSaveInBotChats: { value in
            BGSimpleSettings.shared.saveInBotChats = value
            updateState { current in
                var current = current
                current.saveInBotChats = value
                return current
            }
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Режим шпиона"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: bgSpySettingsEntries(state: state),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }
    return ItemListController(context: context, state: signal)
}
