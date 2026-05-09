import Testing
import Foundation
@testable import peek

// MARK: - Parsing tests (no network)

struct MetadataFetcherParsingTests {
    private let base = URL(string: "https://example.com")!

    @Test func ogTitleTakesPriorityOverTitleTag() {
        let html = """
        <head>
          <title>Plain Title</title>
          <meta property="og:title" content="OG Title">
        </head>
        """
        #expect(MetadataFetcher.parse(html: html, baseURL: base).title == "OG Title")
    }

    @Test func fallsBackToTitleTagWhenOgTitleAbsent() {
        let html = "<head><title>  Page Title  </title></head>"
        #expect(MetadataFetcher.parse(html: html, baseURL: base).title == "Page Title")
    }

    @Test func titleIsNilWhenBothTagsAbsent() {
        let html = "<head></head>"
        #expect(MetadataFetcher.parse(html: html, baseURL: base).title == nil)
    }

    @Test func ogDescriptionExtracted() {
        let html = "<head><meta property=\"og:description\" content=\"A great article.\"></head>"
        #expect(MetadataFetcher.parse(html: html, baseURL: base).description == "A great article.")
    }

    @Test func descriptionIsNilWhenAbsent() {
        let html = "<head><title>Title</title></head>"
        #expect(MetadataFetcher.parse(html: html, baseURL: base).description == nil)
    }

    @Test func faviconExtractedFromLinkTag() {
        let html = "<head><link rel=\"icon\" href=\"/static/favicon.png\"></head>"
        let expected = URL(string: "https://example.com/static/favicon.png")!
        #expect(MetadataFetcher.parse(html: html, baseURL: base).faviconURL == expected)
    }

    @Test func faviconExtractedFromReversedLinkAttributes() {
        let html = "<head><link href=\"/img/icon.ico\" rel=\"icon\"></head>"
        let expected = URL(string: "https://example.com/img/icon.ico")!
        #expect(MetadataFetcher.parse(html: html, baseURL: base).faviconURL == expected)
    }

    @Test func faviconExtractedFromShortcutIcon() {
        let html = "<head><link rel=\"shortcut icon\" href=\"/favicon.ico\"></head>"
        let expected = URL(string: "https://example.com/favicon.ico")!
        #expect(MetadataFetcher.parse(html: html, baseURL: base).faviconURL == expected)
    }

    @Test func faviconFallsBackToRootFaviconIco() {
        let html = "<head><title>No icon link</title></head>"
        let expected = URL(string: "https://example.com/favicon.ico")!
        #expect(MetadataFetcher.parse(html: html, baseURL: base).faviconURL == expected)
    }

    @Test func absoluteFaviconURLPreserved() {
        let html = "<head><link rel=\"icon\" href=\"https://cdn.example.com/icon.png\"></head>"
        let expected = URL(string: "https://cdn.example.com/icon.png")!
        #expect(MetadataFetcher.parse(html: html, baseURL: base).faviconURL == expected)
    }

    @Test func contentAttributeBeforePropertyAttributeParsed() {
        let html = "<head><meta content=\"Reversed\" property=\"og:title\"></head>"
        #expect(MetadataFetcher.parse(html: html, baseURL: base).title == "Reversed")
    }
}

// MARK: - Network tests

@Suite(.serialized)
struct MetadataFetcherNetworkTests {
    private let base = URL(string: "https://example.com")!

    @Test func fetchReturnsMetadataFromHTML() async {
        let html = """
        <html><head>
          <title>Fallback</title>
          <meta property="og:title" content="Network Title">
          <meta property="og:description" content="Network Desc">
          <link rel="icon" href="/favicon.png">
        </head><body>should not be read</body></html>
        """
        MockHTMLProtocol.setResponse(url: base, html: html)
        let fetcher = MetadataFetcher(session: makeMockSession())
        let result = await fetcher.fetch(base)
        #expect(result.title == "Network Title")
        #expect(result.description == "Network Desc")
        #expect(result.faviconURL == URL(string: "https://example.com/favicon.png"))
    }

    @Test func fetchReturnsAllNilsOnNetworkError() async {
        MockHTMLProtocol.setError(url: base, error: URLError(.notConnectedToInternet))
        let fetcher = MetadataFetcher(session: makeMockSession())
        let result = await fetcher.fetch(base)
        #expect(result == PageMetadata(title: nil, description: nil, faviconURL: nil))
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockHTMLProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - Mock

private final class MockHTMLProtocol: URLProtocol {
    private static var responses: [URL: Result<String, Error>] = [:]

    static func setResponse(url: URL, html: String) { responses = [url: .success(html)] }
    static func setError(url: URL, error: Error) { responses = [url: .failure(error)] }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        switch Self.responses[url] {
        case .success(let html):
            let data = Data(html.utf8)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
        }
    }

    override func stopLoading() {}
}
