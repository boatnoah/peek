import Foundation

protocol LLMProvider {
    func cleanDescription(_ raw: String) async throws -> String
}
