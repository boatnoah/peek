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
        metadataFetcher: any MetadataFetching = StubMetadataFetcher()
    ) -> EnrichmentPipeline {
        MockPipelineURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockPipelineURLProtocol.self]
        return EnrichmentPipeline(
            cache: cache,
            resolver: RedirectResolver(configuration: config),
            threatChecker: threatChecker,
            metadataFetcher: metadataFetcher,
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
        let metadataFetcher = StubMetadataFetcher(
            stubbedMetadata: PageMetadata(
                title: "Page Title",
                description: "Raw description.",
                faviconURL: nil
            )
        )
        let pipeline = makePipeline(
            cache: cache,
            threatChecker: threat,
            llm: llm,
            metadataFetcher: metadataFetcher
        )
        let result = await pipeline.enrich(url)

        #expect(result.resolvedDomain == "example.com")
        #expect(result.trustBadge == .verified)
        #expect(result.title == "Page Title")
        #expect(result.description == "A cleaned description.")
        #expect(threat.callCount == 1)
        #expect(llm.callCount == 1)
        #expect(llm.lastInput == "Raw description.")
        #expect(await metadataFetcher.fetchCallCount == 1)

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
        let pipeline = makePipeline(
            cache: PreviewCache(),
            llm: llm,
            metadataFetcher: StubMetadataFetcher(
                stubbedMetadata: PageMetadata(title: "Title Only", description: nil, faviconURL: nil)
            )
        )
        let result = await pipeline.enrich(url)

        #expect(result.description == nil)
        #expect(llm.callCount == 0)
        #expect(result.title == "Title Only")
    }

    // MARK: - Caching prevents repeat network calls

    @Test func secondCallReturnsCachedResultWithoutHittingNetwork() async {
        let cache = PreviewCache()
        let threat = MockThreatChecker()
        let metadataFetcher = StubMetadataFetcher()
        let pipeline = makePipeline(cache: cache, threatChecker: threat, metadataFetcher: metadataFetcher)

        _ = await pipeline.enrich(url)
        _ = await pipeline.enrich(url)

        #expect(threat.callCount == 1)
        #expect(await metadataFetcher.fetchCallCount == 1)
    }
}

// MARK: - Mock URL protocol

private actor StubMetadataFetcher: MetadataFetching {
    let stubbedMetadata: PageMetadata
    private(set) var fetchCallCount = 0

    init(stubbedMetadata: PageMetadata = PageMetadata(title: nil, description: nil, faviconURL: nil)) {
        self.stubbedMetadata = stubbedMetadata
    }

    func fetch(_ url: URL) async -> PageMetadata {
        fetchCallCount += 1
        return stubbedMetadata
    }
}

private final class MockPipelineURLProtocol: URLProtocol {
    private(set) static var requestCount = 0

    static func reset() {
        requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        let data = Data()
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
