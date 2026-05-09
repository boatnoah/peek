import Foundation
@testable import peek

/// Drop-in test double for `LLMProvider`. Configure `stubbedResult` or `stubbedError`
/// before calling `cleanDescription`, then inspect `callCount` and `lastInput`
/// to assert on how the provider was used.
final class MockLLMProvider: LLMProvider {
    var stubbedResult: String = ""
    var stubbedError: Error?
    private(set) var callCount = 0
    private(set) var lastInput: String?

    func cleanDescription(_ raw: String) async throws -> String {
        callCount += 1
        lastInput = raw
        if let error = stubbedError { throw error }
        return stubbedResult
    }
}
