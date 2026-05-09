import Foundation

enum TrustBadge: Equatable {
    case verified
    case mismatch
    case shortener(resolvedDomain: String)
    case knownRisk
}

private let knownShorteners: Set<String> = [
    "bit.ly", "t.co", "tinyurl.com", "ow.ly", "short.link",
    "goo.gl", "buff.ly", "ift.tt", "dlvr.it", "tiny.cc",
    "rb.gy", "cutt.ly", "shorturl.at"
]

enum TrustEvaluator {
    static func evaluate(originalURL: URL, resolvedURL: URL, isFlagged: Bool) -> TrustBadge {
        if isFlagged { return .knownRisk }

        let originalDomain = domain(from: originalURL)
        let resolvedDomain = domain(from: resolvedURL)

        guard !originalDomain.isEmpty, !resolvedDomain.isEmpty else {
            return .mismatch
        }

        if knownShorteners.contains(originalDomain) {
            return .shortener(resolvedDomain: resolvedDomain)
        }

        if originalDomain != resolvedDomain {
            return .mismatch
        }

        if resolvedURL.scheme?.lowercased() != "https" {
            return .mismatch
        }

        return .verified
    }

    private static func domain(from url: URL) -> String {
        url.host?.lowercased() ?? ""
    }
}
