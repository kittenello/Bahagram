import Foundation
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ItemListUI

private final class BahogramSettingsArguments {
}

private enum BahogramSettingsSection: Int32 {
    case main
}

private enum BahogramSettingsEntry: ItemListNodeEntry {
    case title
    case info

    var section: ItemListSectionId {
        return BahogramSettingsSection.main.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .title:
            return 0
        case .info:
            return 1
        }
    }

    static func <(lhs: BahogramSettingsEntry, rhs: BahogramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case .title:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "BAHOGRAM",
                sectionId: self.section
            )
        case .info:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .markdown("Bahogram settings and custom features will appear here."),
                sectionId: self.section
            )
        }
    }
}

func bahogramSettingsController(context: AccountContext) -> ViewController {
    let arguments = BahogramSettingsArguments()

    let signal = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Bahogram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )

        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: [
                BahogramSettingsEntry.title,
                BahogramSettingsEntry.info
            ],
            style: .blocks,
            animateChanges: false
        )

        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
