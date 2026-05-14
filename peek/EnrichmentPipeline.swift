import Foundation

struct EnrichmentPipeline {
    private let cache: PreviewCache
    private let resolver: RedirectResolver
    private let threatChecker: any ThreatChecker
    private let metadataFetcher: any MetadataFetching
    private let llm: any LLMProvider

    init(
        cache: PreviewCache,
        resolver: RedirectResolver,
        threatChecker: any ThreatChecker,
        metadataFetcher: any MetadataFetching = MetadataFetcher(),
        llm: any LLMProvider
    ) {
        self.cache = cache
        self.resolver = resolver
        self.threatChecker = threatChecker
        self.metadataFetcher = metadataFetcher
        self.llm = llm
    }

    func enrich(_ url: URL) async -> EnrichmentResult {
        let key = url.absoluteString

        if let cached = await cache.get(key) {
            return cached
        }

        let resolved: ResolvedURL
        do {
            resolved = try await resolver.resolve(url)
        } catch {
            return EnrichmentResult(
                resolvedDomain: url.host?.lowercased() ?? "",
                trustBadge: .mismatch,
                title: nil,
                description: nil,
                faviconURL: nil
            )
        }

        async let threat = threatChecker.check(domain: resolved.cleanedDomain)
        async let metadata = metadataFetcher.fetch(resolved.finalURL)
        let (threatResult, meta) = await (threat, metadata)

        let cleanedDescription: String?
        if let raw = meta.description, !raw.isEmpty {
            cleanedDescription = try? await llm.cleanDescription(raw)
        } else {
            cleanedDescription = nil
        }

        let trustBadge = TrustEvaluator.evaluate(
            originalURL: url,
            resolvedURL: resolved.finalURL,
            isFlagged: threatResult == .flagged,
            isShortener: resolved.isShortener
        )

        let result = EnrichmentResult(
            resolvedDomain: resolved.cleanedDomain,
            trustBadge: trustBadge,
            title: meta.title,
            description: cleanedDescription,
            faviconURL: meta.faviconURL
        )

        await cache.set(key, result: result)
        return result
    }
}
