import Foundation

nonisolated enum TrustBadge: Equatable, Sendable {
    case verified
    case mismatch
    case shortener(resolvedDomain: String)
    case knownRisk
}

nonisolated enum TrustEvaluator {
    static func evaluate(originalURL: URL, resolvedURL: URL, isFlagged: Bool, isShortener: Bool) -> TrustBadge {
        if isFlagged { return .knownRisk }

        let originalDomain = domain(from: originalURL)
        let resolvedDomain = domain(from: resolvedURL)

        guard !originalDomain.isEmpty, !resolvedDomain.isEmpty else {
            return .mismatch
        }

        if isShortener {
            return .shortener(resolvedDomain: resolvedDomain)
        }

        if !domainsMatch(originalDomain, resolvedDomain) {
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

    private static func domainsMatch(_ originalDomain: String, _ resolvedDomain: String) -> Bool {
        originalDomain == resolvedDomain ||
            isSubdomain(originalDomain, of: resolvedDomain) ||
            isSubdomain(resolvedDomain, of: originalDomain)
    }

    private static func isSubdomain(_ candidateDomain: String, of parentDomain: String) -> Bool {
        guard parentDomain.contains(".") else { return false }
        return candidateDomain.hasSuffix(".\(parentDomain)")
    }
}
