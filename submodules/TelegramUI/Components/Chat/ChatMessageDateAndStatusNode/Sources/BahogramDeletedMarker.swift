import Foundation
import UIKit
import CoreText
import Display
import SwiftSignalKit

// Put by stringForMessageTimestampStatus in front of the date of a saved deleted message.
// bahogramDateAttributedString draws it as an inline trash icon.
public let bahogramDeletedMarker = "\u{E000}"

private final class BahogramDeletedIconRunDelegateData {
    let ascent: CGFloat
    let descent: CGFloat
    let width: CGFloat

    init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
        self.ascent = ascent
        self.descent = descent
        self.width = width
    }
}

private struct BahogramDeletedIcon {
    let image: UIImage
    let runDelegate: CTRunDelegate
}

// One icon per font: reusing the image and the run delegate keeps equal date strings
// equal, so TextNode keeps its cached layout.
private let bahogramDeletedIcons = Atomic<[UIFont: BahogramDeletedIcon]>(value: [:])

private func makeBahogramDeletedIcon(font: UIFont) -> BahogramDeletedIcon? {
    let configuration = UIImage.SymbolConfiguration(pointSize: floor(font.pointSize * 9.0 / 11.0), weight: .regular)
    guard let symbol = UIImage(systemName: "trash.fill", withConfiguration: configuration) else {
        return nil
    }
    let ascent = font.ascender
    let descent = -font.descender
    let baselineOffset = symbol.baselineOffsetFromBottom ?? 0.0

    // The symbol is drawn through UIKit: its cgImage has neither its alignment insets nor
    // its tint, and TextNode draws attachments from cgImage. TextNode centers the image on
    // the line box and moves it 1pt down, so a canvas of the line box plus 2pt starts at
    // the line top and the symbol sits on the text baseline. The canvas is rounded up to
    // whole points, so half of the extra height goes above the baseline.
    let canvasHeight = ascent + descent + 2.0
    let canvasSize = CGSize(width: ceil(symbol.size.width), height: ceil(canvasHeight))
    let baselineY = ascent + (canvasSize.height - canvasHeight) / 2.0
    guard let image = generateImage(canvasSize, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        UIGraphicsPushContext(context)
        symbol.draw(in: CGRect(origin: CGPoint(x: (size.width - symbol.size.width) / 2.0, y: baselineY + baselineOffset - symbol.size.height), size: symbol.size))
        UIGraphicsPopContext()
    })?.withRenderingMode(.alwaysTemplate) else {
        return nil
    }

    let data = Unmanaged.passRetained(BahogramDeletedIconRunDelegateData(ascent: ascent, descent: descent, width: image.size.width))
    var callbacks = CTRunDelegateCallbacks(
        version: kCTRunDelegateCurrentVersion,
        dealloc: { dataRef in
            Unmanaged<BahogramDeletedIconRunDelegateData>.fromOpaque(dataRef).release()
        },
        getAscent: { dataRef in
            return Unmanaged<BahogramDeletedIconRunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().ascent
        },
        getDescent: { dataRef in
            return Unmanaged<BahogramDeletedIconRunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().descent
        },
        getWidth: { dataRef in
            return Unmanaged<BahogramDeletedIconRunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().width
        }
    )
    guard let runDelegate = CTRunDelegateCreate(&callbacks, data.toOpaque()) else {
        data.release()
        return nil
    }
    return BahogramDeletedIcon(image: image, runDelegate: runDelegate)
}

private func bahogramDeletedIcon(font: UIFont) -> BahogramDeletedIcon? {
    if let icon = bahogramDeletedIcons.with({ $0[font] }) {
        return icon
    }
    guard let icon = makeBahogramDeletedIcon(font: font) else {
        return nil
    }
    // Another layout thread may have stored one meanwhile. Keep the stored icon, so all
    // date strings for this font share the same image and run delegate.
    return bahogramDeletedIcons.modify { current in
        if current[font] != nil {
            return current
        }
        var updated = current
        updated[font] = icon
        return updated
    }[font] ?? icon
}

// Date text for a TextNode with bahogramDeletedMarker turned into a trash icon and a space.
// TextNode reserves the icon's width through the run delegate, skips the placeholder glyph
// and draws the icon tinted with textColor wherever the marker ends up, so text that
// callers put in front of the date (views, "edited") no longer covers it. Both characters
// are no-break spaces: the icon stays with the time, and if TextNode draws the placeholder
// instead of the icon (it ignores attachments after a middle truncation) nothing shows.
public func bahogramDateAttributedString(_ text: String, font: UIFont, textColor: UIColor) -> NSAttributedString {
    let string = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor])
    let markerRange = (text as NSString).range(of: bahogramDeletedMarker)
    if markerRange.location == NSNotFound {
        return string
    }
    let replacement = NSMutableAttributedString()
    if let icon = bahogramDeletedIcon(font: font) {
        replacement.append(NSAttributedString(string: "\u{00A0}", attributes: [
            .font: font,
            .foregroundColor: textColor,
            .attachment: icon.image,
            NSAttributedString.Key(rawValue: kCTRunDelegateAttributeName as String): icon.runDelegate
        ]))
        replacement.append(NSAttributedString(string: "\u{00A0}", attributes: [.font: font, .foregroundColor: textColor]))
    }
    string.replaceCharacters(in: markerRange, with: replacement)
    return string
}
