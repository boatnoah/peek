import Foundation

protocol LLMProvider: Sendable {
    func cleanDescription(_ raw: String) async throws -> String
}
