import Testing
import Foundation
@testable import peek

struct TrustEvaluatorTests {

    // MARK: - .knownRisk

    @Test func flaggedURLReturnsKnownRisk() {
        let original = URL(string: "https://example.com")!
        let resolved = URL(string: "https://example.com")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: true, isShortener: false) == .knownRisk)
    }

    @Test func flaggedShortenerStillReturnsKnownRisk() {
        let original = URL(string: "https://links.example/abc123")!
        let resolved = URL(string: "https://safe-looking-site.com")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: true, isShortener: true) == .knownRisk)
    }

    // MARK: - .shortener

    @Test func shortenerFlagReturnsShortenerBadge() {
        let original = URL(string: "https://links.example/abc123")!
        let resolved = URL(string: "https://github.com/boatnoah/peek")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false, isShortener: true) == .shortener(resolvedDomain: "github.com"))
    }

    // MARK: - .mismatch (including malformed URLs)

    @Test func malformedURLWithNoHostReturnsMismatch() {
        let original = URL(string: "not-a-url")!
        let resolved = URL(string: "also-not-a-url")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false, isShortener: false) == .mismatch)
    }

    @Test func malformedResolvedURLReturnsMismatch() {
        let original = URL(string: "https://example.com")!
        let resolved = URL(string: "not-a-url")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false, isShortener: false) == .mismatch)
    }



    @Test func differentDomainsReturnMismatch() {
        let original = URL(string: "https://google.com/page")!
        let resolved = URL(string: "https://evil-clone.com/page")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false, isShortener: false) == .mismatch)
    }

    @Test func similarSuffixDomainsReturnMismatch() {
        let original = URL(string: "https://example.com")!
        let resolved = URL(string: "https://fakeexample.com")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false, isShortener: false) == .mismatch)
    }

    @Test func httpResolvedURLReturnsMismatch() {
        let original = URL(string: "https://example.com")!
        let resolved = URL(string: "http://example.com")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false, isShortener: false) == .mismatch)
    }

    // MARK: - .verified

    @Test func matchingHTTPSDomainsReturnVerified() {
        let original = URL(string: "https://github.com/boatnoah")!
        let resolved = URL(string: "https://github.com/boatnoah/peek")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false, isShortener: false) == .verified)
    }

    @Test func caseInsensitiveDomainMatchReturnsVerified() {
        let original = URL(string: "https://GitHub.com/page")!
        let resolved = URL(string: "https://github.com/page")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false, isShortener: false) == .verified)
    }

    @Test func nakedToWWWRedirectReturnsVerified() {
        let original = URL(string: "https://google.com")!
        let resolved = URL(string: "https://www.google.com")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false, isShortener: false) == .verified)
    }

    @Test func subdomainToParentDomainRedirectReturnsVerified() {
        let original = URL(string: "https://shop.brand.com")!
        let resolved = URL(string: "https://brand.com")!
        #expect(TrustEvaluator.evaluate(originalURL: original, resolvedURL: resolved, isFlagged: false, isShortener: false) == .verified)
    }
}
