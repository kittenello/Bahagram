import AccountContext
import Display
import ItemListUI
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData

private enum BahogramEditHistoryEntry: ItemListNodeEntry {
    case messages

    var section: ItemListSectionId { return 0 }
    var stableId: Int32 { return 0 }
    static func < (lhs: BahogramEditHistoryEntry, rhs: BahogramEditHistoryEntry) -> Bool { return false }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let data = arguments as! BahogramEditHistoryData
        let current = data.context.sharedContext.currentPresentationData.with { $0 }
        return ThemeSettingsChatPreviewItem(
            context: data.context,
            systemStyle: .glass,
            theme: current.theme,
            componentTheme: current.theme,
            strings: current.strings,
            sectionId: self.section,
            fontSize: current.chatFontSize,
            chatBubbleCorners: current.chatBubbleCorners,
            wallpaper: current.chatWallpaper,
            dateTimeFormat: current.dateTimeFormat,
            nameDisplayOrder: current.nameDisplayOrder,
            messageItems: data.messages
        )
    }
}

private final class BahogramEditHistoryData {
    let context: AccountContext
    let messages: [ChatPreviewMessageItem]

    init(context: AccountContext, messages: [ChatPreviewMessageItem]) {
        self.context = context
        self.messages = messages
    }
}

/// Read-only snapshots. These are local revisions; opening this screen never sends a message.
public func bahogramEditHistoryController(context: AccountContext, revisions: [BahogramMessageRevision], currentText: String, currentTimestamp: Int32, incoming: Bool) -> ViewController {
    let snapshots = revisions.map { ($0.text, $0.timestamp) } + [(currentText, currentTimestamp)]
    let data = BahogramEditHistoryData(context: context, messages: snapshots.map { text, timestamp in
        ChatPreviewMessageItem(outgoing: !incoming, reply: nil, text: text.isEmpty ? "‹пустое сообщение›" : text, timestamp: timestamp, nameColor: .preset(.blue), backgroundEmojiId: nil)
    })
    let state = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let listPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: listPresentationData, title: .text("История правок"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: listPresentationData, entries: [BahogramEditHistoryEntry.messages], style: .blocks, animateChanges: false)
        return (controllerState, (listState, data))
    }
    let controller = ItemListController(context: context, state: state)
    controller.alwaysSynchronous = true
    return controller
}
