import Foundation

struct EnrichmentResult: Equatable, Sendable {
    let resolvedDomain: String
    let trustBadge: TrustBadge
    let title: String?
    let description: String?
    let faviconURL: URL?
}
