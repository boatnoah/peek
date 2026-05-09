import Testing
import Foundation
@testable import peek

@Suite(.serialized)
struct LLMProviderTests {

    // MARK: - Empty passthrough

    @Test func emptyDescriptionIsReturnedUnchanged() async throws {
        MockGeminiProtocol.setResponse(.ok(text: "should not be called"))
        let provider = GeminiProvider(apiKey: "test-key", session: makeMockSession())
        let result = try await provider.cleanDescription("")
        #expect(result == "")
        #expect(MockGeminiProtocol.requestCount == 0)
    }

    // MARK: - Successful API call

    @Test func nonEmptyDescriptionIsCleanedViaAPI() async throws {
        let cleaned = "A short plain-English description."
        MockGeminiProtocol.setResponse(.ok(text: cleaned))
        let provider = GeminiProvider(apiKey: "test-key", session: makeMockSession())
        let result = try await provider.cleanDescription("Some raw og:description text.")
        #expect(result == cleaned)
        #expect(MockGeminiProtocol.requestCount == 1)
    }

    @Test func responseTextIsTrimmed() async throws {
        MockGeminiProtocol.setResponse(.ok(text: "  Trimmed sentence.  "))
        let provider = GeminiProvider(apiKey: "test-key", session: makeMockSession())
        let result = try await provider.cleanDescription("Raw description.")
        #expect(result == "Trimmed sentence.")
    }

    // MARK: - HTTP errors

    @Test func nonOKStatusCodeThrowsHTTPError() async throws {
        MockGeminiProtocol.setResponse(.httpError(statusCode: 429))
        let provider = GeminiProvider(apiKey: "test-key", session: makeMockSession())
        await #expect(throws: GeminiProviderError.httpError(429)) {
            try await provider.cleanDescription("Some description.")
        }
    }

    // MARK: - Malformed response

    @Test func malformedResponseBodyThrowsUnexpectedResponse() async throws {
        MockGeminiProtocol.setResponse(.malformed)
        let provider = GeminiProvider(apiKey: "test-key", session: makeMockSession())
        await #expect(throws: GeminiProviderError.unexpectedResponse) {
            try await provider.cleanDescription("Some description.")
        }
    }

    // MARK: - Network error

    @Test func networkErrorPropagates() async throws {
        MockGeminiProtocol.setError(URLError(.notConnectedToInternet))
        let provider = GeminiProvider(apiKey: "test-key", session: makeMockSession())
        await #expect(throws: URLError.self) {
            try await provider.cleanDescription("Some description.")
        }
    }

    // MARK: - Helpers

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockGeminiProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - Mock URL protocol

private enum MockGeminiResponse {
    case ok(text: String)
    case httpError(statusCode: Int)
    case malformed
}

private final class MockGeminiProtocol: URLProtocol {
    private static var response: MockGeminiResponse = .ok(text: "")
    private static var error: Error?
    private(set) static var requestCount = 0

    static func setResponse(_ r: MockGeminiResponse) {
        response = r
        error = nil
        requestCount = 0
    }

    static func setError(_ err: Error) {
        error = err
        requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1

        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        switch Self.response {
        case .ok(let text):
            let body: [String: Any] = [
                "candidates": [[
                    "content": [
                        "parts": [["text": text]]
                    ]
                ]]
            ]
            let data = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)

        case .httpError(let statusCode):
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)

        case .malformed:
            let data = Data("not-json".utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
