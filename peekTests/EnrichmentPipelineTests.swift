import Testing
import Foundation
@testable import peek

// MockPipelineURLProtocol uses static state; serialized prevents data races across tests.
@Suite(.serialized)
struct EnrichmentPipelineTests {
    private let url = URL(string: "https://example.com/article")!

    // MARK: - Helpers

    private func makePipeline(
        cache: PreviewCache,
        threatChecker: any ThreatChecker = MockThreatChecker(),
        llm: any LLMProvider = MockLLMProvider(),
        html: String = ""
    ) -> EnrichmentPipeline {
        MockPipelineURLProtocol.reset(html: html)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockPipelineURLProtocol.self]
        return EnrichmentPipeline(
            cache: cache,
            resolver: RedirectResolver(configuration: config),
            threatChecker: threatChecker,
            metadataFetcher: MetadataFetcher(session: URLSession(configuration: config)),
            llm: llm
        )
    }

    // MARK: - Cache hit

    @Test func cacheHitSkipsAllDownstreamCalls() async {
        let cache = PreviewCache()
        let threat = MockThreatChecker()
        let llm = MockLLMProvider()
        let cached = EnrichmentResult(
            resolvedDomain: "example.com",
            trustBadge: .verified,
            title: "Cached Title",
            description: nil,
            faviconURL: nil
        )
        await cache.set(url.absoluteString, result: cached)

        let pipeline = makePipeline(cache: cache, threatChecker: threat, llm: llm)
        let result = await pipeline.enrich(url)

        #expect(result == cached)
        #expect(threat.callCount == 0)
        #expect(llm.callCount == 0)
        #expect(MockPipelineURLProtocol.requestCount == 0)
    }

    // MARK: - Full pipeline

    @Test func cacheMissRunsFullPipelineAndCachesResult() async {
        let cache = PreviewCache()
        let threat = MockThreatChecker()
        let llm = MockLLMProvider()
        llm.stubbedResult = "A cleaned description."
        let html = """
        <head>
          <meta property="og:title" content="Page Title">
          <meta property="og:description" content="Raw description.">
        </head>
        """
        let pipeline = makePipeline(cache: cache, threatChecker: threat, llm: llm, html: html)
        let result = await pipeline.enrich(url)

        #expect(result.resolvedDomain == "example.com")
        #expect(result.trustBadge == .verified)
        #expect(result.title == "Page Title")
        #expect(result.description == "A cleaned description.")
        #expect(threat.callCount == 1)
        #expect(llm.callCount == 1)
        #expect(llm.lastInput == "Raw description.")

        let cached = await cache.get(url.absoluteString)
        #expect(cached == result)
    }

    // MARK: - knownRisk overrides everything

    @Test func flaggedDomainReturnsKnownRisk() async {
        let threat = MockThreatChecker()
        threat.stubbedResult = .flagged
        let pipeline = makePipeline(cache: PreviewCache(), threatChecker: threat)
        let result = await pipeline.enrich(url)
        #expect(result.trustBadge == .knownRisk)
    }

    // MARK: - Missing og:description

    @Test func missingDescriptionLeavesDescriptionNilAndSkipsLLM() async {
        let llm = MockLLMProvider()
        let html = "<head><meta property=\"og:title\" content=\"Title Only\"></head>"
        let pipeline = makePipeline(cache: PreviewCache(), llm: llm, html: html)
        let result = await pipeline.enrich(url)

        #expect(result.description == nil)
        #expect(llm.callCount == 0)
        #expect(result.title == "Title Only")
    }

    // MARK: - Caching prevents repeat network calls

    @Test func secondCallReturnsCachedResultWithoutHittingNetwork() async {
        let cache = PreviewCache()
        let threat = MockThreatChecker()
        let pipeline = makePipeline(cache: cache, threatChecker: threat)

        _ = await pipeline.enrich(url)
        _ = await pipeline.enrich(url)

        #expect(threat.callCount == 1)
    }
}

// MARK: - Mock URL protocol

private final class MockPipelineURLProtocol: URLProtocol {
    private static var html: String = ""
    private(set) static var requestCount = 0

    static func reset(html: String = "") {
        Self.html = html
        requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        let data = Data(Self.html.utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
