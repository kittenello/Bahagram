import Foundation

/// What a TikTok post contains: one video (file + duration in seconds) or a photo carousel.
enum BGTikTokItem: Equatable {
    case video(BGRemoteFile, Double)
    case photos([BGRemoteFile])
}

/// Reads a TikTok post straight from tiktok.com, without third-party services. Mirrors `tiktok_item_id`,
/// `tiktok_page_url` and `tiktok_parse_page` in the Python reference.
enum BGTikTokExtractor {
    static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
    private static let rehydrationMarker = "<script id=\"__UNIVERSAL_DATA_FOR_REHYDRATION__\""

    static func itemId(fromPathSegments segments: [String]) -> String? {
        if segments.count >= 3 && segments[0].hasPrefix("@") && (segments[1] == "video" || segments[1] == "photo") && bgIsTikTokItemId(segments[2]) {
            return segments[2]
        }
        if segments.count == 2 && segments[0] == "v" && segments[1].hasSuffix(".html") {
            let candidate = String(segments[1].dropLast(5))
            if bgIsTikTokItemId(candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Item id of a post link or of the page a short link redirected to; nil for the home page (expired link).
    static func itemId(from url: URL) -> String? {
        if let itemId = BGTikTokExtractor.itemId(fromPathSegments: bgPathSegments(url.path)) {
            return itemId
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let shared = components?.queryItems?.first(where: { $0.name == "share_item_id" })?.value, bgIsTikTokItemId(shared) {
            return shared
        }
        return nil
    }

    /// One page serves videos and photo posts; "/photo/<id>" has no data and the author name is not needed.
    static func pageURL(itemId: String) -> URL? {
        return URL(string: "https://www.tiktok.com/@/video/\(itemId)")
    }

    static func pageRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(BGTikTokExtractor.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    /// CDN requests need the page's cookies (same BGMediaFetcher) and a tiktok.com referer, otherwise 403.
    static func mediaRequest(_ url: URL) -> URLRequest {
        var request = BGTikTokExtractor.pageRequest(url)
        request.setValue("https://www.tiktok.com/", forHTTPHeaderField: "Referer")
        return request
    }

    static func parsePage(_ html: String) -> Result<BGTikTokItem, BGLinkDownloadError> {
        guard let marker = html.range(of: BGTikTokExtractor.rehydrationMarker),
              let openEnd = html[marker.upperBound...].firstIndex(of: ">") else {
            return .failure(.tiktokNoData)
        }
        let jsonStart = html.index(after: openEnd)
        guard let close = html.range(of: "</script>", range: jsonStart ..< html.endIndex),
              let data = String(html[jsonStart ..< close.lowerBound]).data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any],
              let scope = root["__DEFAULT_SCOPE__"] as? [String: Any],
              let detail = scope["webapp.video-detail"] as? [String: Any] else {
            return .failure(.tiktokNoData)
        }
        let status = bgIntValue(detail["statusCode"]) ?? 0
        if status == 10204 {
            return .failure(.tiktokNotFound)
        }
        if status == 10222 {
            return .failure(.tiktokPrivate)
        }
        if status != 0 {
            return .failure(.tiktokStatus(Int(status)))
        }
        guard let itemInfo = detail["itemInfo"] as? [String: Any], let item = itemInfo["itemStruct"] as? [String: Any] else {
            return .failure(.tiktokNoData)
        }
        if let imagePost = item["imagePost"] as? [String: Any] {
            var files: [BGRemoteFile] = []
            for entry in (imagePost["images"] as? [Any]) ?? [] {
                guard let image = entry as? [String: Any],
                      let imageURL = image["imageURL"] as? [String: Any],
                      let first = (imageURL["urlList"] as? [Any])?.first as? String,
                      let url = URL(string: first) else {
                    return .failure(.tiktokNoData)
                }
                files.append(BGRemoteFile(url: url, expectedSize: nil, width: Int(bgIntValue(image["imageWidth"]) ?? 0), height: Int(bgIntValue(image["imageHeight"]) ?? 0)))
            }
            if files.isEmpty {
                return .failure(.tiktokNoData)
            }
            return .success(.photos(files))
        }
        let video = (item["video"] as? [String: Any]) ?? [:]
        let duration = Double(bgIntValue(video["duration"]) ?? 0)
        var best: (bitrate: Int64, file: BGRemoteFile)?
        for entry in (video["bitrateInfo"] as? [Any]) ?? [] {
            guard let variant = entry as? [String: Any],
                  let codec = variant["CodecType"] as? String, codec.lowercased().hasPrefix("h264"),
                  let play = variant["PlayAddr"] as? [String: Any],
                  let first = (play["UrlList"] as? [Any])?.first as? String,
                  let url = URL(string: first) else {
                continue
            }
            let bitrate = bgIntValue(variant["Bitrate"]) ?? 0
            if let current = best, current.bitrate >= bitrate {
                continue
            }
            best = (bitrate, BGRemoteFile(url: url, expectedSize: bgIntValue(play["DataSize"]), width: Int(bgIntValue(play["Width"]) ?? 0), height: Int(bgIntValue(play["Height"]) ?? 0)))
        }
        if let best {
            return .success(.video(best.file, duration))
        }
        if let playAddr = video["playAddr"] as? String, !playAddr.isEmpty, let url = URL(string: playAddr) {
            return .success(.video(BGRemoteFile(url: url, expectedSize: nil, width: Int(bgIntValue(video["width"]) ?? 0), height: Int(bgIntValue(video["height"]) ?? 0)), duration))
        }
        return .failure(.tiktokNoData)
    }

    /// Short links (vm./vt./t/) are followed first: they redirect to "/@/video/<id>" or to the home page when expired.
    static func resolve(_ url: URL, fetcher: BGMediaFetcher, completion: @escaping (Result<BGTikTokItem, BGLinkDownloadError>) -> Void) {
        if let itemId = BGTikTokExtractor.itemId(from: url) {
            BGTikTokExtractor.fetchItem(itemId: itemId, fetcher: fetcher, completion: completion)
            return
        }
        fetcher.fetchData(BGTikTokExtractor.pageRequest(url), completion: { result in
            switch result {
            case let .failure(error):
                completion(.failure(error))
            case let .success(response):
                guard let finalURL = response.url, let itemId = BGTikTokExtractor.itemId(from: finalURL) else {
                    completion(.failure(.tiktokLinkExpired))
                    return
                }
                BGTikTokExtractor.fetchItem(itemId: itemId, fetcher: fetcher, completion: completion)
            }
        })
    }

    private static func fetchItem(itemId: String, fetcher: BGMediaFetcher, completion: @escaping (Result<BGTikTokItem, BGLinkDownloadError>) -> Void) {
        guard let url = BGTikTokExtractor.pageURL(itemId: itemId) else {
            completion(.failure(.tiktokNoData))
            return
        }
        fetcher.fetchData(BGTikTokExtractor.pageRequest(url), completion: { result in
            switch result {
            case let .failure(error):
                completion(.failure(error))
            case let .success(response):
                completion(BGTikTokExtractor.parsePage(String(decoding: response.data, as: UTF8.self)))
            }
        })
    }
}
