import Testing
import Foundation
@testable import peek

struct TrustEvaluatorTests {

    // MARK: - .knownRisk

    @Test func flaggedURLReturnsKnownRisk() {
        let original = URL(string: "https://example.com")!
        let resolved = URL(string: "https://example.com")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: true) == .knownRisk)
    }

    @Test func flaggedShortenerStillReturnsKnownRisk() {
        let original = URL(string: "https://bit.ly/abc123")!
        let resolved = URL(string: "https://safe-looking-site.com")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: true) == .knownRisk)
    }

    // MARK: - .shortener

    @Test func knownShortenerReturnsShortenerBadge() {
        let original = URL(string: "https://bit.ly/abc123")!
        let resolved = URL(string: "https://github.com/boatnoah/peek")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false) == .shortener(resolvedDomain: "github.com"))
    }

    @Test func tcoShortenerReturnsShortenerBadge() {
        let original = URL(string: "https://t.co/xyz")!
        let resolved = URL(string: "https://nytimes.com/article")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false) == .shortener(resolvedDomain: "nytimes.com"))
    }

    @Test func tinyurlReturnsShortenerBadge() {
        let original = URL(string: "https://tinyurl.com/abc")!
        let resolved = URL(string: "https://apple.com")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false) == .shortener(resolvedDomain: "apple.com"))
    }

    // MARK: - .mismatch (including malformed URLs)

    @Test func malformedURLWithNoHostReturnsMismatch() {
        let original = URL(string: "not-a-url")!
        let resolved = URL(string: "also-not-a-url")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false) == .mismatch)
    }

    @Test func malformedResolvedURLReturnsMismatch() {
        let original = URL(string: "https://example.com")!
        let resolved = URL(string: "not-a-url")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false) == .mismatch)
    }



    @Test func differentDomainsReturnMismatch() {
        let original = URL(string: "https://google.com/page")!
        let resolved = URL(string: "https://evil-clone.com/page")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false) == .mismatch)
    }

    @Test func subdomainDifferenceReturnsMismatch() {
        let original = URL(string: "https://google.com")!
        let resolved = URL(string: "https://www.google.com")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false) == .mismatch)
    }

    @Test func httpResolvedURLReturnsMismatch() {
        let original = URL(string: "https://example.com")!
        let resolved = URL(string: "http://example.com")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false) == .mismatch)
    }

    // MARK: - .verified

    @Test func matchingHTTPSDomainsReturnVerified() {
        let original = URL(string: "https://github.com/boatnoah")!
        let resolved = URL(string: "https://github.com/boatnoah/peek")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false) == .verified)
    }

    @Test func caseInsensitiveDomainMatchReturnsVerified() {
        let original = URL(string: "https://GitHub.com/page")!
        let resolved = URL(string: "https://github.com/page")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false) == .verified)
    }
}
