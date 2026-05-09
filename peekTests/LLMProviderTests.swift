import Testing
import Foundation
@testable import peek

// MockGeminiProtocol uses static state; serialized prevents data races across tests
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

    // MARK: - Request construction

    @Test func requestIsConstructedCorrectly() async throws {
        MockGeminiProtocol.setResponse(.ok(text: "cleaned"))
        let apiKey = "test-api-key-12345"
        let provider = GeminiProvider(apiKey: apiKey, session: makeMockSession())
        _ = try await provider.cleanDescription("Some description.")

        let req = try #require(MockGeminiProtocol.lastRequest)

        // HTTP method must be POST
        #expect(req.httpMethod == "POST")

        // URL must point at the correct model endpoint with no query string
        let url = try #require(req.url)
        #expect(url.absoluteString.contains("gemini-2.0-flash:generateContent"))
        #expect(url.query == nil, "API key must not appear in the URL query string")

        // Required headers must be present and correct
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(req.value(forHTTPHeaderField: "x-goog-api-key") == apiKey)
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

    private(set) static var lastRequest: URLRequest?

    static func setResponse(_ r: MockGeminiResponse) {
        response = r
        error = nil
        requestCount = 0
        lastRequest = nil
    }

    static func setError(_ err: Error) {
        error = err
        requestCount = 0
        lastRequest = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        Self.lastRequest = request

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
