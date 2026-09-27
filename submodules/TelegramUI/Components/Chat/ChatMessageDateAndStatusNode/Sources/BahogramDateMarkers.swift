import Foundation
import UIKit
import CoreText
import Display
import SwiftSignalKit

// Private-use markers put into the date text of a message. bahogramDateAttributedString draws
// each of them as an inline SF Symbol tinted like the date.

// In front of the date of a saved deleted message: an outline trash can.
public let bahogramDeletedMarker = "\u{E000}"
// In front of the date of an edited message: an outline pencil. It replaces "✎", which came
// from a fallback font and did not match the date's size and weight.
public let bahogramEditedMarker = "\u{E001}"

private let bahogramMarkerSymbols: [(marker: String, symbolName: String)] = [
    (bahogramDeletedMarker, "trash"),
    (bahogramEditedMarker, "pencil")
]

private final class BahogramInlineIconRunDelegateData {
    let ascent: CGFloat
    let descent: CGFloat
    let width: CGFloat

    init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
        self.ascent = ascent
        self.descent = descent
        self.width = width
    }
}

private struct BahogramInlineIconKey: Hashable {
    let symbolName: String
    let font: UIFont
}

private struct BahogramInlineIcon {
    let image: UIImage
    let runDelegate: CTRunDelegate
}

// One icon per symbol and font: reusing the image and the run delegate keeps equal date
// strings equal, so TextNode keeps its cached layout.
private let bahogramInlineIcons = Atomic<[BahogramInlineIconKey: BahogramInlineIcon]>(value: [:])

private func makeBahogramInlineIcon(symbolName: String, font: UIFont) -> BahogramInlineIcon? {
    let configuration = UIImage.SymbolConfiguration(pointSize: floor(font.pointSize * 9.0 / 11.0), weight: .regular)
    guard let symbol = UIImage(systemName: symbolName, withConfiguration: configuration) else {
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

    let data = Unmanaged.passRetained(BahogramInlineIconRunDelegateData(ascent: ascent, descent: descent, width: image.size.width))
    var callbacks = CTRunDelegateCallbacks(
        version: kCTRunDelegateCurrentVersion,
        dealloc: { dataRef in
            Unmanaged<BahogramInlineIconRunDelegateData>.fromOpaque(dataRef).release()
        },
        getAscent: { dataRef in
            return Unmanaged<BahogramInlineIconRunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().ascent
        },
        getDescent: { dataRef in
            return Unmanaged<BahogramInlineIconRunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().descent
        },
        getWidth: { dataRef in
            return Unmanaged<BahogramInlineIconRunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().width
        }
    )
    guard let runDelegate = CTRunDelegateCreate(&callbacks, data.toOpaque()) else {
        data.release()
        return nil
    }
    return BahogramInlineIcon(image: image, runDelegate: runDelegate)
}

private func bahogramInlineIcon(symbolName: String, font: UIFont) -> BahogramInlineIcon? {
    let key = BahogramInlineIconKey(symbolName: symbolName, font: font)
    if let icon = bahogramInlineIcons.with({ $0[key] }) {
        return icon
    }
    guard let icon = makeBahogramInlineIcon(symbolName: symbolName, font: font) else {
        return nil
    }
    // Another layout thread may have stored one meanwhile. Keep the stored icon, so all
    // date strings for this symbol and font share the same image and run delegate.
    return bahogramInlineIcons.modify { current in
        if current[key] != nil {
            return current
        }
        var updated = current
        updated[key] = icon
        return updated
    }[key] ?? icon
}

// Date text for a TextNode with every marker turned into its icon and a space.
// TextNode reserves the icon's width through the run delegate, skips the placeholder glyph
// and draws the icon tinted with textColor wherever the marker ends up, so text that
// callers put in front of the date (views, "edited") no longer covers it. Both characters
// are no-break spaces: the icon stays with the time, and if TextNode draws the placeholder
// instead of the icon (it ignores attachments after a middle truncation) nothing shows.
public func bahogramDateAttributedString(_ text: String, font: UIFont, textColor: UIColor) -> NSAttributedString {
    let string = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor])
    let nsText = text as NSString
    var markerRanges: [(range: NSRange, symbolName: String)] = []
    for (marker, symbolName) in bahogramMarkerSymbols {
        var searchLocation = 0
        while searchLocation < nsText.length {
            let range = nsText.range(of: marker, options: [], range: NSRange(location: searchLocation, length: nsText.length - searchLocation))
            if range.location == NSNotFound {
                break
            }
            markerRanges.append((range, symbolName))
            searchLocation = range.location + range.length
        }
    }
    // Replace from the end, so the ranges still to be replaced stay valid.
    for (range, symbolName) in markerRanges.sorted(by: { $0.range.location > $1.range.location }) {
        let replacement = NSMutableAttributedString()
        if let icon = bahogramInlineIcon(symbolName: symbolName, font: font) {
            replacement.append(NSAttributedString(string: "\u{00A0}", attributes: [
                .font: font,
                .foregroundColor: textColor,
                .attachment: icon.image,
                NSAttributedString.Key(rawValue: kCTRunDelegateAttributeName as String): icon.runDelegate
            ]))
            replacement.append(NSAttributedString(string: "\u{00A0}", attributes: [.font: font, .foregroundColor: textColor]))
        }
        string.replaceCharacters(in: range, with: replacement)
    }
    return string
}
