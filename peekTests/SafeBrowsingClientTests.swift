import Testing
import Foundation
@testable import peek

@Suite(.serialized)
struct SafeBrowsingClientTests {

    // MARK: - API key handling

    @Test func nilApiKeyReturnsClean() async {
        MockSafeBrowsingProtocol.setResponse(.flagged)
        let client = SafeBrowsingClient(apiKey: nil, session: makeMockSession())
        #expect(await client.check(domain: "evil.com") == .clean)
        #expect(MockSafeBrowsingProtocol.requestCount == 0)
    }

    @Test func emptyApiKeyReturnsClean() async {
        MockSafeBrowsingProtocol.setResponse(.flagged)
        let client = SafeBrowsingClient(apiKey: "", session: makeMockSession())
        #expect(await client.check(domain: "evil.com") == .clean)
        #expect(MockSafeBrowsingProtocol.requestCount == 0)
    }

    // MARK: - Clean / flagged results

    @Test func cleanResponseReturnsClean() async {
        MockSafeBrowsingProtocol.setResponse(.clean)
        let client = SafeBrowsingClient(apiKey: "test-key", session: makeMockSession())
        #expect(await client.check(domain: "safe.com") == .clean)
    }

    @Test func flaggedResponseReturnsFlagged() async {
        MockSafeBrowsingProtocol.setResponse(.flagged)
        let client = SafeBrowsingClient(apiKey: "test-key", session: makeMockSession())
        #expect(await client.check(domain: "evil.com") == .flagged)
    }

    @Test func networkErrorReturnsClean() async {
        MockSafeBrowsingProtocol.setError(URLError(.notConnectedToInternet))
        let client = SafeBrowsingClient(apiKey: "test-key", session: makeMockSession())
        #expect(await client.check(domain: "unreachable.com") == .clean)
    }

    // MARK: - Caching

    @Test func secondCheckWithinTTLHitsCache() async {
        MockSafeBrowsingProtocol.setResponse(.flagged)
        let client = SafeBrowsingClient(apiKey: "test-key", session: makeMockSession())
        _ = await client.check(domain: "evil.com")
        _ = await client.check(domain: "evil.com")
        #expect(MockSafeBrowsingProtocol.requestCount == 1)
    }

    @Test func differentDomainsEachHitNetwork() async {
        MockSafeBrowsingProtocol.setResponse(.clean)
        let client = SafeBrowsingClient(apiKey: "test-key", session: makeMockSession())
        _ = await client.check(domain: "first.com")
        _ = await client.check(domain: "second.com")
        #expect(MockSafeBrowsingProtocol.requestCount == 2)
    }

    @Test func expiredCacheEntryHitsNetworkAgain() async {
        MockSafeBrowsingProtocol.setResponse(.clean)
        let client = SafeBrowsingClient(apiKey: "test-key", session: makeMockSession(), ttl: -1)
        _ = await client.check(domain: "example.com")
        _ = await client.check(domain: "example.com")
        #expect(MockSafeBrowsingProtocol.requestCount == 2)
    }

    // MARK: - Helpers

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockSafeBrowsingProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - Mock

private final class MockSafeBrowsingProtocol: URLProtocol {
    private static var response: ThreatResult = .clean
    private static var error: Error?
    private(set) static var requestCount = 0

    static func setResponse(_ result: ThreatResult) {
        response = result
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

        let body: [String: Any]
        switch Self.response {
        case .clean:
            body = [:]
        case .flagged:
            body = ["matches": [["threatType": "MALWARE"]]]
        }

        let data = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
