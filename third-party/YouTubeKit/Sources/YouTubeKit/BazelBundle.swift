import Foundation

extension Bundle {
    static var module: Bundle {
        guard let url = Bundle.main.url(forResource: "YouTubeKitResources", withExtension: "bundle"),
              let bundle = Bundle(url: url) else {
            return .main
        }
        return bundle
    }
}
