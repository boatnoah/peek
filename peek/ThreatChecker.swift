import Foundation

enum ThreatResult: Equatable, Sendable {
    case clean
    case flagged
}

protocol ThreatChecker {
    func check(domain: String) async -> ThreatResult
}
