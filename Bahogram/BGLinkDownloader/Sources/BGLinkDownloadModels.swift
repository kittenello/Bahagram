import Foundation

/// A remote file chosen by an extractor. Size and dimensions are what the service reported.
struct BGRemoteFile: Equatable {
    let url: URL
    let expectedSize: Int64?
    let width: Int
    let height: Int
}

/// A small JPEG rendered on device (video preview).
public struct BGJPEGImage {
    public let data: Data
    public let width: Int
    public let height: Int
}

/// JSON numbers or numeric strings as Int64: TikTok and YouTube send sizes as strings ("5272191").
/// Mirrors `int_value` in the Python reference (booleans are not numbers).
func bgIntValue(_ value: Any?) -> Int64? {
    if let number = value as? NSNumber {
        if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() {
            return nil
        }
        return number.int64Value
    }
    if let string = value as? String {
        return Int64(string.trimmingCharacters(in: .whitespaces))
    }
    return nil
}

/// Non-empty path segments ("/@/video/1" -> ["@", "video", "1"]).
func bgPathSegments(_ path: String) -> [String] {
    return path.split(separator: "/").map(String.init)
}

private let bgShortCodeCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
private let bgYouTubeIdCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")

/// Code of a vm./vt.tiktok.com or tiktok.com/t/ short link.
func bgIsShortCode(_ value: String) -> Bool {
    return !value.isEmpty && value.unicodeScalars.allSatisfy { bgShortCodeCharacters.contains($0) }
}

/// 11-character YouTube video id.
func bgIsYouTubeVideoId(_ value: String) -> Bool {
    return value.unicodeScalars.count == 11 && value.unicodeScalars.allSatisfy { bgYouTubeIdCharacters.contains($0) }
}

/// Numeric TikTok post id: 10-25 ASCII digits.
func bgIsTikTokItemId(_ value: String) -> Bool {
    let scalars = value.unicodeScalars
    return scalars.count >= 10 && scalars.count <= 25 && scalars.allSatisfy { $0.value >= 48 && $0.value <= 57 }
}
