import Testing
@testable import peek

struct PreviewCacheTests {

    // MARK: - Miss / hit

    @Test func missReturnsNil() async {
        let cache = PreviewCache()
        #expect(await cache.get("https://example.com") == nil)
    }

    @Test func hitReturnsStoredResult() async {
        let cache = PreviewCache()
        let result = EnrichmentResult.stub(domain: "example.com")
        await cache.set("https://example.com", result: result)
        #expect(await cache.get("https://example.com") == result)
    }

    @Test func overwriteUpdatesValue() async {
        let cache = PreviewCache()
        let first = EnrichmentResult.stub(domain: "example.com")
        let second = EnrichmentResult.stub(domain: "updated.com")
        await cache.set("https://example.com", result: first)
        await cache.set("https://example.com", result: second)
        #expect(await cache.get("https://example.com") == second)
    }

    // MARK: - LRU eviction

    @Test func evictsLRUEntryAtCapacity() async {
        let cache = PreviewCache()
        let limit = PreviewCache.maxEntries

        for i in 0..<limit {
            await cache.set("https://url\(i).com", result: .stub(domain: "url\(i).com"))
        }

        // url0 is LRU — inserting one more should evict it
        await cache.set("https://overflow.com", result: .stub(domain: "overflow.com"))

        #expect(await cache.get("https://url0.com") == nil)
        #expect(await cache.get("https://overflow.com") != nil)
    }

    @Test func hitPromotesEntryAboveEviction() async {
        let cache = PreviewCache()
        let limit = PreviewCache.maxEntries

        for i in 0..<limit {
            await cache.set("https://url\(i).com", result: .stub(domain: "url\(i).com"))
        }

        // Promote url0 so url1 becomes LRU
        _ = await cache.get("https://url0.com")

        await cache.set("https://overflow.com", result: .stub(domain: "overflow.com"))

        #expect(await cache.get("https://url0.com") != nil)
        #expect(await cache.get("https://url1.com") == nil)
    }

    // MARK: - Concurrency

    @Test func concurrentWritesDoNotCrash() async {
        let cache = PreviewCache()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await cache.set("https://url\(i).com", result: .stub(domain: "url\(i).com"))
                }
            }
        }
    }

    @Test func concurrentReadsAndWritesDoNotCrash() async {
        let cache = PreviewCache()
        await cache.set("https://seed.com", result: .stub(domain: "seed.com"))

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask { _ = await cache.get("https://seed.com") }
                group.addTask { await cache.set("https://url\(i).com", result: .stub(domain: "url\(i).com")) }
            }
        }
    }
}

private extension EnrichmentResult {
    static func stub(domain: String) -> EnrichmentResult {
        EnrichmentResult(
            resolvedDomain: domain,
            trustBadge: .verified,
            title: nil,
            description: nil,
            faviconURL: nil
        )
    }
}
