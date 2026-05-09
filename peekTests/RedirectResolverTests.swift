import Foundation
import Testing
@testable import peek

@Suite(.serialized)
struct RedirectResolverTests {

    @Test func directURLReturnsCleanedURLAndDomain() async throws {
        let url = URL(string: "https://example.com/article?id=42")!
        MockURLProtocol.setResponses([
            url: .ok()
        ])

        let resolved = try await makeResolver().resolve(url)

        #expect(resolved == ResolvedURL(
            finalURL: url,
            cleanedDomain: "example.com",
            isShortener: false
        ))
        #expect(MockURLProtocol.recordedMethods == ["HEAD"])
    }

    @Test func followsSingleRedirect() async throws {
        let original = URL(string: "https://example.com/start")!
        let destination = URL(string: "https://destination.com/final")!
        MockURLProtocol.setResponses([
            original: .redirect(to: destination),
            destination: .ok()
        ])

        let resolved = try await makeResolver().resolve(original)

        #expect(resolved.finalURL == destination)
        #expect(resolved.cleanedDomain == "destination.com")
        #expect(MockURLProtocol.recordedURLs == [original, destination])
        #expect(MockURLProtocol.recordedMethods == ["HEAD", "HEAD"])
    }

    @Test func followsChainedRedirects() async throws {
        let original = URL(string: "https://example.com/start")!
        let middle = URL(string: "https://middle.com/next")!
        let destination = URL(string: "https://destination.com/final")!
        MockURLProtocol.setResponses([
            original: .redirect(to: middle),
            middle: .redirect(to: destination),
            destination: .ok()
        ])

        let resolved = try await makeResolver().resolve(original)

        #expect(resolved.finalURL == destination)
        #expect(MockURLProtocol.recordedURLs == [original, middle, destination])
        #expect(MockURLProtocol.recordedMethods == ["HEAD", "HEAD", "HEAD"])
    }

    @Test func stripsUTMAndKnownTrackingParametersFromResolvedURL() async throws {
        let original = URL(string: "https://example.com/start")!
        let destination = URL(string: "https://example.com/article?utm_source=newsletter&id=42&fbclid=abc&utm_medium=email&gclid=def")!
        let cleaned = URL(string: "https://example.com/article?id=42")!
        MockURLProtocol.setResponses([
            original: .redirect(to: destination),
            destination: .ok()
        ])

        let resolved = try await makeResolver().resolve(original)

        #expect(resolved.finalURL == cleaned)
        #expect(resolved.cleanedDomain == "example.com")
    }

    @Test func detectsKnownShortenerFromOriginalURL() async throws {
        let original = URL(string: "https://bit.ly/abc123")!
        let destination = URL(string: "https://github.com/boatnoah/peek?utm_campaign=launch")!
        let cleaned = URL(string: "https://github.com/boatnoah/peek")!
        MockURLProtocol.setResponses([
            original: .redirect(to: destination),
            destination: .ok()
        ])

        let resolved = try await makeResolver().resolve(original)

        #expect(resolved.finalURL == cleaned)
        #expect(resolved.cleanedDomain == "github.com")
        #expect(resolved.isShortener)
    }

    @Test func similarButUnknownShortenerDomainDoesNotMatch() async throws {
        let original = URL(string: "https://bit.ly.evil.example/abc123")!
        let destination = URL(string: "https://github.com/boatnoah/peek")!
        MockURLProtocol.setResponses([
            original: .redirect(to: destination),
            destination: .ok()
        ])

        let resolved = try await makeResolver().resolve(original)

        #expect(resolved.finalURL == destination)
        #expect(resolved.cleanedDomain == "github.com")
        #expect(!resolved.isShortener)
    }

    private func makeResolver() -> RedirectResolver {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return RedirectResolver(configuration: configuration)
    }
}

private struct MockHTTPResponse {
    let statusCode: Int
    let headers: [String: String]

    static func ok() -> MockHTTPResponse {
        MockHTTPResponse(statusCode: 200, headers: [:])
    }

    static func redirect(to url: URL) -> MockHTTPResponse {
        MockHTTPResponse(statusCode: 302, headers: ["Location": url.absoluteString])
    }
}

private final class MockURLProtocol: URLProtocol {
    private static var responses: [URL: MockHTTPResponse] = [:]
    private static var requests: [URLRequest] = []

    static var recordedURLs: [URL] {
        requests.compactMap(\.url)
    }

    static var recordedMethods: [String] {
        requests.map { $0.httpMethod ?? "" }
    }

    static func setResponses(_ responses: [URL: MockHTTPResponse]) {
        self.responses = responses
        self.requests = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)

        guard
            let url = request.url,
            let mockResponse = Self.responses[url],
            let response = HTTPURLResponse(
                url: url,
                statusCode: mockResponse.statusCode,
                httpVersion: nil,
                headerFields: mockResponse.headers
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
