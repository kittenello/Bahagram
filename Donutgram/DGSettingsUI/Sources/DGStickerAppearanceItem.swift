import UIKit
import AsyncDisplayKit
import Display
import ItemListUI
import SwiftSignalKit
import TelegramPresentationData
import DGSimpleSettings

final class DGStickerAppearanceItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let sectionId: ItemListSectionId
    let shapePicker: Bool
    let size: Int
    let hideTime: Bool
    let replyOptions: Int
    let shape: Int
    let updated: (String) -> Void

    init(theme: PresentationTheme, sectionId: ItemListSectionId, shapePicker: Bool, size: Int, hideTime: Bool, replyOptions: Int, shape: Int, updated: @escaping (String) -> Void) {
        self.theme = theme
        self.sectionId = sectionId
        self.shapePicker = shapePicker
        self.size = size
        self.hideTime = hideTime
        self.replyOptions = replyOptions
        self.shape = shape
        self.updated = updated
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        Queue.mainQueue().async {
            let node = DGStickerAppearanceItemNode()
            let (layout, apply) = node.layout(self, params: params)
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            completion(node, { (nil, { _ in apply() }) })
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let node = node() as? DGStickerAppearanceItemNode else { return }
            let (layout, apply) = node.layout(self, params: params)
            completion(layout, { _ in apply() })
        }
    }
}

private final class DGStickerAppearanceItemNode: ListViewItemNode {
    private var item: DGStickerAppearanceItem?
    private let block = UIView()
    private let title = UILabel()
    private let small = UILabel()
    private let large = UILabel()
    private let slider = UISlider()
    private let reset = UIButton(type: .system)
    private let preview = UIView()
    private let sticker = UIImageView()
    private let time = UILabel()
    private let reply = UIView()
    private let replyBackground = UIView()
    private let replyLine = UIView()
    private let replyAuthor = UILabel()
    private let replyText = UILabel()
    private let replyPattern = UILabel()
    private var shapeButtons: [UIButton] = []

    init() { super.init(layerBacked: false) }

    override func didLoad() {
        super.didLoad()
        self.view.addSubview(block)
        block.layer.cornerRadius = 22.0
        block.clipsToBounds = true
        for subview in [title, small, large, slider, reset, preview] as [UIView] { block.addSubview(subview) }
        preview.addSubview(sticker)
        sticker.addSubview(time)
        preview.addSubview(reply)
        reply.addSubview(replyBackground)
        replyBackground.addSubview(replyLine)
        replyBackground.addSubview(replyPattern)
        replyBackground.addSubview(replyAuthor)
        replyBackground.addSubview(replyText)
        title.font = .systemFont(ofSize: 15, weight: .medium)
        small.font = .systemFont(ofSize: 12)
        large.font = .systemFont(ofSize: 12)
        small.text = "Маленький"
        large.text = "Большой"
        large.textAlignment = .right
        slider.minimumValue = 1
        slider.maximumValue = 20
        slider.isContinuous = true
        slider.disablesInteractiveTransitionGestureRecognizer = true
        slider.accessibilityLabel = "Размер стикеров"
        slider.addTarget(self, action: #selector(sizeChanged), for: .valueChanged)
        reset.setImage(UIImage(systemName: "arrow.counterclockwise"), for: .normal)
        reset.accessibilityLabel = "Сбросить настройки стикеров"
        reset.addTarget(self, action: #selector(resetPressed), for: .touchUpInside)
        time.text = "21:20 ✓✓"
        time.font = .systemFont(ofSize: 11)
        time.textColor = .white
        time.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        time.layer.cornerRadius = 7
        time.clipsToBounds = true
        time.textAlignment = .center
        reply.layer.cornerRadius = 14
        replyBackground.layer.cornerRadius = 5
        replyLine.layer.cornerRadius = 1.5
        replyAuthor.text = "Donutgram"
        replyAuthor.font = .systemFont(ofSize: 13, weight: .semibold)
        replyText.text = "😺 Стикер\nТак выглядит ответ на стикер"
        replyText.font = .systemFont(ofSize: 13)
        replyText.numberOfLines = 2
        replyPattern.text = "✨  ✨"
        replyPattern.font = .systemFont(ofSize: 24)
        replyPattern.textAlignment = .right
        for (index, text) in ["По умолчанию", "Закруглённая", "Сообщение"].enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitle(text, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 11)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.7
            button.addTarget(self, action: #selector(shapePressed(_:)), for: .touchUpInside)
            block.addSubview(button)
            shapeButtons.append(button)
        }
    }

    func layout(_ item: DGStickerAppearanceItem, params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> Void) {
        let width = max(100, params.width - params.leftInset - params.rightInset)
        let scale = item.size <= 11 ? 0.25 + Double(item.size - 1) * 0.075 : 1 + Double(item.size - 11) / 12
        let side = min(min(184 * CGFloat(scale), max(32, params.width - 100)), 340)
        let height: CGFloat = item.shapePicker ? 100 : side + 208
        let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: height), insets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))
        return (layout, { [weak self] in
            guard let self else { return }
            self.view.backgroundColor = .clear
            self.item = item
            self.block.frame = CGRect(x: params.leftInset, y: 0, width: width, height: height)
            self.block.backgroundColor = item.theme.list.itemBlocksBackgroundColor
            let accent = item.theme.list.itemAccentColor
            let text = item.theme.list.itemPrimaryTextColor
            self.title.text = "Размер стикеров  \(item.size)"
            self.title.textColor = accent
            self.title.frame = CGRect(x: 16, y: 12, width: width - 70, height: 24)
            self.reset.frame = CGRect(x: width - 48, y: 8, width: 40, height: 36)
            self.reset.tintColor = accent
            self.small.textColor = item.theme.list.itemSecondaryTextColor
            self.large.textColor = item.theme.list.itemSecondaryTextColor
            self.small.frame = CGRect(x: 16, y: 42, width: 100, height: 18)
            self.large.frame = CGRect(x: width - 116, y: 42, width: 100, height: 18)
            if !self.slider.isTracking { self.slider.value = Float(item.size) }
            self.slider.accessibilityValue = "\(item.size)"
            self.slider.minimumTrackTintColor = accent
            self.slider.frame = CGRect(x: 16, y: 64, width: width - 32, height: 32)
            self.preview.frame = CGRect(x: 12, y: 106, width: width - 24, height: side + 90)
            self.preview.backgroundColor = item.theme.list.blocksBackgroundColor
            self.preview.layer.cornerRadius = 12
            self.sticker.frame = CGRect(x: width - 40 - side, y: 8, width: side, height: side)
            let radius: CGFloat = item.shape == 0 ? 0 : (item.shape == 1 ? 12 : 22)
            self.sticker.layer.cornerRadius = radius
            self.sticker.clipsToBounds = true
            // A square sample makes corner and size changes visible even for transparent sticker artwork.
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256))
            self.sticker.image = renderer.image { _ in
                accent.withAlphaComponent(0.25).setFill()
                UIBezierPath(rect: CGRect(x: 0, y: 0, width: 256, height: 256)).fill()
                ("😺" as NSString).draw(in: CGRect(x: 30, y: 30, width: 210, height: 210), withAttributes: [.font: UIFont.systemFont(ofSize: 172)])
            }
            self.time.isHidden = item.hideTime
            self.time.frame = CGRect(x: max(0, side - 70), y: max(0, side - 22), width: min(68, side), height: 20)
            self.reply.frame = CGRect(x: 8, y: side + 22, width: min(width - 48, 280), height: 58)
            self.reply.backgroundColor = item.theme.list.itemBlocksBackgroundColor
            self.replyBackground.frame = self.reply.bounds.insetBy(dx: 6, dy: 5)
            self.replyBackground.backgroundColor = item.replyOptions & 4 != 0 ? accent.withAlphaComponent(0.12) : .clear
            self.replyLine.frame = CGRect(x: 0, y: 0, width: 3, height: self.replyBackground.bounds.height)
            self.replyLine.backgroundColor = item.replyOptions & 1 != 0 ? accent : text
            self.replyPattern.frame = CGRect(x: 0, y: 0, width: self.replyBackground.bounds.width - 8, height: 38)
            self.replyPattern.alpha = item.replyOptions & 2 != 0 ? 0.16 : 0
            self.replyAuthor.textColor = item.replyOptions & 1 != 0 ? accent : text
            self.replyAuthor.frame = CGRect(x: 8, y: 0, width: self.replyBackground.bounds.width - 16, height: 17)
            self.replyText.textColor = text
            self.replyText.frame = CGRect(x: 8, y: 17, width: self.replyBackground.bounds.width - 16, height: 31)
            for view in [self.title, self.small, self.large, self.slider, self.reset, self.preview] as [UIView] { view.isHidden = item.shapePicker }
            for (index, button) in self.shapeButtons.enumerated() {
                button.isHidden = !item.shapePicker
                button.frame = CGRect(x: 12 + CGFloat(index) * (width - 24) / 3, y: 12, width: (width - 36) / 3, height: 76)
                button.backgroundColor = item.theme.list.blocksBackgroundColor
                button.setTitleColor(index == item.shape ? accent : text, for: .normal)
                button.layer.cornerRadius = index == 0 ? 3 : (index == 1 ? 12 : 22)
                button.layer.borderWidth = index == item.shape ? 2 : 0
                button.layer.borderColor = accent.cgColor
                button.accessibilityTraits = index == item.shape ? [.button, .selected] : .button
            }
        })
    }

    @objc private func sizeChanged() {
        guard let item else { return }
        let size = min(20, max(1, Int(slider.value.rounded())))
        if size != item.size { item.updated("stickerSize:\(size)") }
    }
    @objc private func resetPressed() { item?.updated("resetStickerAppearance") }
    @objc private func shapePressed(_ sender: UIButton) { item?.updated("stickerShape:\(sender.tag)") }
}
