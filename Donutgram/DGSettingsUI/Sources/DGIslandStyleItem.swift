import UIKit
import AsyncDisplayKit
import Display
import ItemListUI
import SwiftSignalKit
import TelegramPresentationData

final class DGIslandStyleItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let sectionId: ItemListSectionId
    let value: Int
    let updated: (Int) -> Void

    init(theme: PresentationTheme, sectionId: ItemListSectionId, value: Int, updated: @escaping (Int) -> Void) {
        self.theme = theme
        self.sectionId = sectionId
        self.value = value
        self.updated = updated
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = DGIslandStyleItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async { completion(node, { (nil, { _ in apply() }) }) }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? DGIslandStyleItemNode {
                let makeLayout = nodeValue.asyncLayout()
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async { completion(layout, { _ in apply() }) }
                }
            }
        }
    }
}

private final class DGIslandStyleItemNode: ListViewItemNode {
    private static let titles = ["Основной", "Пончик", "Мини"]
    private static let assets = ["Components/AppBadge", "Components/DonutIsland", "Components/MiniDonutIsland"]

    private var item: DGIslandStyleItem?
    private var layoutWidth: CGFloat = 0.0
    private var leftInset: CGFloat = 0.0
    private var rightInset: CGFloat = 0.0
    private var buttons: [UIButton] = []
    private var captions: [UILabel] = []

    init() {
        super.init(layerBacked: false)
    }

    override func didLoad() {
        super.didLoad()

        for index in 0 ..< Self.titles.count {
            let button = UIButton(type: .custom)
            button.tag = index
            button.layer.cornerRadius = 14.0
            button.layer.borderWidth = 2.0
            button.clipsToBounds = true
            button.imageView?.contentMode = .scaleAspectFit
            button.setImage(UIImage(bundleImageName: Self.assets[index]), for: .normal)
            button.addTarget(self, action: #selector(selected(_:)), for: .touchUpInside)
            self.view.addSubview(button)
            self.buttons.append(button)

            let caption = UILabel()
            caption.font = .systemFont(ofSize: 13.0)
            caption.textAlignment = .center
            caption.text = Self.titles[index]
            self.view.addSubview(caption)
            self.captions.append(caption)
        }

        self.updateControls()
    }

    func asyncLayout() -> (_ item: DGIslandStyleItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 208.0), insets: itemListNeighborsGroupedInsets(neighbors, params))
            return (layout, { [weak self] in
                self?.item = item
                self?.layoutWidth = params.width
                self?.leftInset = params.leftInset
                self?.rightInset = params.rightInset
                self?.updateControls()
            })
        }
    }

    private func updateControls() {
        guard let item else { return }

        self.backgroundColor = item.theme.list.itemBlocksBackgroundColor

        let horizontalPadding: CGFloat = 16.0
        let spacing: CGFloat = 12.0
        let availableWidth = max(0.0, self.layoutWidth - self.leftInset - self.rightInset - horizontalPadding * 2.0)
        let cardWidth = max(90.0, floor((availableWidth - spacing) / 2.0))
        let rowHeight: CGFloat = 94.0

        for index in 0 ..< self.buttons.count {
            let row = index / 2
            let column = index % 2
            let x = self.leftInset + horizontalPadding + CGFloat(column) * (cardWidth + spacing)
            let y = 12.0 + CGFloat(row) * rowHeight
            let selected = index == item.value

            let button = self.buttons[index]
            button.frame = CGRect(x: x, y: y, width: cardWidth, height: 64.0)
            button.imageEdgeInsets = UIEdgeInsets(top: 17.0, left: 12.0, bottom: 17.0, right: 12.0)
            button.backgroundColor = item.theme.list.itemSecondaryTextColor.withAlphaComponent(0.07)
            button.layer.borderColor = (selected ? item.theme.list.itemAccentColor : item.theme.list.itemSecondaryTextColor.withAlphaComponent(0.14)).cgColor
            button.accessibilityLabel = Self.titles[index]
            button.accessibilityTraits = selected ? [.button, .selected] : [.button]

            let caption = self.captions[index]
            caption.frame = CGRect(x: x, y: y + 68.0, width: cardWidth, height: 20.0)
            caption.textColor = selected ? item.theme.list.itemAccentColor : item.theme.list.itemSecondaryTextColor
        }
    }

    @objc private func selected(_ sender: UIButton) {
        self.item?.updated(sender.tag)
    }
}
