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
    private var item: DGIslandStyleItem?
    private var layoutWidth: CGFloat = 0
    private var buttons: [UIButton] = []
    private var captions: [UILabel] = []

    init() {
        super.init(layerBacked: false)
    }

    override func didLoad() {
        super.didLoad()
        for index in 0 ..< 3 {
            let button = UIButton(type: .custom)
            button.tag = index
            button.layer.cornerRadius = 18
            button.layer.borderWidth = 2
            button.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.65
            button.addTarget(self, action: #selector(selected(_:)), for: .touchUpInside)
            self.view.addSubview(button)
            self.buttons.append(button)

            let caption = UILabel()
            caption.font = .systemFont(ofSize: 12)
            caption.textAlignment = .center
            caption.text = ["Основной", "Пончик", "Мини"][index]
            self.view.addSubview(caption)
            self.captions.append(caption)
        }
        self.updateControls()
    }

    func asyncLayout() -> (_ item: DGIslandStyleItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 116), insets: itemListNeighborsGroupedInsets(neighbors, params))
            return (layout, { [weak self] in
                self?.item = item
                self?.layoutWidth = params.width
                self?.updateControls()
            })
        }
    }

    private func updateControls() {
        guard let item else { return }
        self.backgroundColor = item.theme.list.itemBlocksBackgroundColor
        let spacing: CGFloat = 9
        let cardWidth = max(65, (self.layoutWidth - 32 - spacing * 2) / 3)
        for index in 0 ..< self.buttons.count {
            let button = self.buttons[index]
            let x = 16 + CGFloat(index) * (cardWidth + spacing)
            button.frame = CGRect(x: x, y: 13, width: cardWidth, height: 69)
            button.setTitle(["◉ DONUTGRAM", "🍩 DONUT", "🍩"][index], for: .normal)
            button.backgroundColor = index == 1 ? UIColor(red: 0.32, green: 0.12, blue: 0.24, alpha: 1) : .black
            button.setTitleColor(index == 1 ? UIColor(red: 1, green: 0.77, blue: 0.85, alpha: 1) : .white, for: .normal)
            button.layer.borderColor = (index == item.value ? item.theme.list.itemAccentColor : UIColor.clear).cgColor
            button.accessibilityLabel = self.captions[index].text
            button.accessibilityTraits = index == item.value ? [.button, .selected] : [.button]
            self.captions[index].frame = CGRect(x: x, y: 85, width: cardWidth, height: 20)
            self.captions[index].textColor = index == item.value ? item.theme.list.itemAccentColor : item.theme.list.itemSecondaryTextColor
        }
    }

    @objc private func selected(_ sender: UIButton) {
        self.item?.updated(sender.tag)
    }
}
