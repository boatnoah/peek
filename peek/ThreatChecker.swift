import Foundation

enum ThreatResult: Equatable, Sendable {
    case clean
    case flagged
}

protocol ThreatChecker: Sendable {
    func check(domain: String) async -> ThreatResult
}
