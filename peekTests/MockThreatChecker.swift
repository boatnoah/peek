import Foundation
@testable import peek

final class MockThreatChecker: ThreatChecker {
    var stubbedResult: ThreatResult = .clean
    private(set) var callCount = 0
    private(set) var lastDomain: String?

    func check(domain: String) async -> ThreatResult {
        callCount += 1
        lastDomain = domain
        return stubbedResult
    }
}
