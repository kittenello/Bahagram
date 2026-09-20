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
    let updateExperimentalFeatures: (Bool) -> Void
    let updateFeatureDescriptions: (Bool) -> Void

    init(
        openSpyMode: @escaping () -> Void,
        updateExperimentalFeatures: @escaping (Bool) -> Void,
        updateFeatureDescriptions: @escaping (Bool) -> Void
    ) {
        self.openSpyMode = openSpyMode
        self.updateExperimentalFeatures = updateExperimentalFeatures
        self.updateFeatureDescriptions = updateFeatureDescriptions
    }
}

private struct BGSettingsState: Equatable {
    var experimentalFeatures: Bool
    var showFeatureDescriptions: Bool
}

private enum BGSettingsSection: Int32 {
    case general
    case experimental
    case about
}

private enum BGSettingsEntry: ItemListNodeEntry {
    case generalHeader
    case spyMode
    case experimentalFeatures(Bool)
    case featureDescriptions(Bool)
    case generalInfo

    case experimentalHeader
    case experimentalInfo

    case aboutHeader
    case aboutInfo

    var section: ItemListSectionId {
        switch self {
        case .generalHeader, .spyMode, .experimentalFeatures, .featureDescriptions, .generalInfo:
            return BGSettingsSection.general.rawValue
        case .experimentalHeader, .experimentalInfo:
            return BGSettingsSection.experimental.rawValue
        case .aboutHeader, .aboutInfo:
            return BGSettingsSection.about.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .generalHeader:
            return 0
        case .spyMode:
            return 1
        case .experimentalFeatures:
            return 2
        case .featureDescriptions:
            return 3
        case .generalInfo:
            return 4
        case .experimentalHeader:
            return 10
        case .experimentalInfo:
            return 11
        case .aboutHeader:
            return 20
        case .aboutInfo:
            return 21
        }
    }

    static func < (lhs: BGSettingsEntry, rhs: BGSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BGSettingsArguments

        switch self {
        case .generalHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "BAHOGRAM",
                sectionId: self.section
            )
        case .spyMode:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: "Режим шпиона",
                label: "",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.openSpyMode()
                }
            )
        case let .experimentalFeatures(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: "Experimental Features",
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.updateExperimentalFeatures(value)
                }
            )
        case let .featureDescriptions(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: "Show Feature Descriptions",
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.updateFeatureDescriptions(value)
                }
            )
        case .generalInfo:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .markdown("Bahogram settings are stored separately from Telegram settings, so custom options can be added without mixing them into the upstream client."),
                sectionId: self.section
            )
        case .experimentalHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "EXPERIMENTAL",
                sectionId: self.section
            )
        case .experimentalInfo:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .markdown("Experimental Bahogram features will appear here. This section can be expanded independently as new modules are added."),
                sectionId: self.section
            )
        case .aboutHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "ABOUT",
                sectionId: self.section
            )
        case .aboutInfo:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .markdown("Bahogram is an unofficial client based on Telegram for iOS."),
                sectionId: self.section
            )
        }
    }
}

private func bgSettingsEntries(state: BGSettingsState) -> [BGSettingsEntry] {
    var entries: [BGSettingsEntry] = [
        .generalHeader,
        .spyMode,
        .experimentalFeatures(state.experimentalFeatures),
        .featureDescriptions(state.showFeatureDescriptions)
    ]

    if state.showFeatureDescriptions {
        entries.append(.generalInfo)
    }

    if state.experimentalFeatures {
        entries.append(.experimentalHeader)
        entries.append(.experimentalInfo)
    }

    entries.append(.aboutHeader)
    entries.append(.aboutInfo)

    return entries
}

public func bgSettingsController(context: AccountContext) -> ViewController {
    let initialState = BGSettingsState(
        experimentalFeatures: BGSimpleSettings.shared.experimentalFeatures,
        showFeatureDescriptions: BGSimpleSettings.shared.showFeatureDescriptions
    )

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)

    let updateState: ((BGSettingsState) -> BGSettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { current in
            return f(current)
        })
    }

    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = BGSettingsArguments(
        openSpyMode: {
            pushControllerImpl?(bgSpySettingsController(context: context))
        },
        updateExperimentalFeatures: { value in
            BGSimpleSettings.shared.experimentalFeatures = value
            updateState { current in
                var current = current
                current.experimentalFeatures = value
                return current
            }
        },
        updateFeatureDescriptions: { value in
            BGSimpleSettings.shared.showFeatureDescriptions = value
            updateState { current in
                var current = current
                current.showFeatureDescriptions = value
                return current
            }
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    )
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

private final class BGSpySettingsArguments {
    let updateSaveDeletedMessages: (Bool) -> Void
    let updateSaveEditHistory: (Bool) -> Void
    let updateSaveInBotChats: (Bool) -> Void

    init(
        updateSaveDeletedMessages: @escaping (Bool) -> Void,
        updateSaveEditHistory: @escaping (Bool) -> Void,
        updateSaveInBotChats: @escaping (Bool) -> Void
    ) {
        self.updateSaveDeletedMessages = updateSaveDeletedMessages
        self.updateSaveEditHistory = updateSaveEditHistory
        self.updateSaveInBotChats = updateSaveInBotChats
    }
}

private struct BGSpySettingsState: Equatable {
    var saveDeletedMessages: Bool
    var saveEditHistory: Bool
    var saveInBotChats: Bool
}

private enum BGSpySettingsSection: Int32 {
    case storage
}

private enum BGSpySettingsEntry: ItemListNodeEntry {
    case header
    case saveDeletedMessages(Bool)
    case saveEditHistory(Bool)
    case saveInBotChats(Bool)
    case info

    var section: ItemListSectionId {
        return BGSpySettingsSection.storage.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .saveDeletedMessages:
            return 1
        case .saveEditHistory:
            return 2
        case .saveInBotChats:
            return 3
        case .info:
            return 4
        }
    }

    static func < (lhs: BGSpySettingsEntry, rhs: BGSpySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BGSpySettingsArguments

        switch self {
        case .header:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "СОХРАНЕНИЕ СООБЩЕНИЙ",
                sectionId: self.section
            )
        case let .saveDeletedMessages(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: "Сохранять удаленные сообщения",
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.updateSaveDeletedMessages(value)
                }
            )
        case let .saveEditHistory(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: "Сохранять историю правок",
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.updateSaveEditHistory(value)
                }
            )
        case let .saveInBotChats(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: "Сохранять в чатах с ботами",
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.updateSaveInBotChats(value)
                }
            )
        case .info:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .markdown("Удаленные сообщения и история правок сохраняются локально на этом устройстве. 🗑 отмечает удаленное сообщение, ✎ — сообщение с сохраненной историей правок."),
                sectionId: self.section
            )
        }
    }
}

private func bgSpySettingsEntries(state: BGSpySettingsState) -> [BGSpySettingsEntry] {
    return [
        .header,
        .saveDeletedMessages(state.saveDeletedMessages),
        .saveEditHistory(state.saveEditHistory),
        .saveInBotChats(state.saveInBotChats),
        .info
    ]
}

public func bgSpySettingsController(context: AccountContext) -> ViewController {
    let initialState = BGSpySettingsState(
        saveDeletedMessages: BGSimpleSettings.shared.saveDeletedMessages,
        saveEditHistory: BGSimpleSettings.shared.saveEditHistory,
        saveInBotChats: BGSimpleSettings.shared.saveInBotChats
    )

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)

    let updateState: ((BGSpySettingsState) -> BGSpySettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { current in
            return f(current)
        })
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
        updateSaveEditHistory: { value in
            BGSimpleSettings.shared.saveEditHistory = value
            updateState { current in
                var current = current
                current.saveEditHistory = value
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

    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    )
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
