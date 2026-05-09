import Foundation

nonisolated enum TrustBadge: Equatable, Sendable {
    case verified
    case mismatch
    case shortener(resolvedDomain: String)
    case knownRisk
}

nonisolated enum TrustEvaluator {
    static func evaluate(originalURL: URL, resolvedURL: URL, isFlagged: Bool) -> TrustBadge {
        if isFlagged { return .knownRisk }

        let originalDomain = domain(from: originalURL)
        let resolvedDomain = domain(from: resolvedURL)

        guard !originalDomain.isEmpty, !resolvedDomain.isEmpty else {
            return .mismatch
        }

        if ShortenerDomains.contains(host: originalDomain) {
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
