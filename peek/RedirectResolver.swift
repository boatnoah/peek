import Foundation

nonisolated struct ResolvedURL: Equatable, Sendable {
    let finalURL: URL
    let cleanedDomain: String
    let isShortener: Bool
}

nonisolated enum RedirectResolverError: Error, Equatable {
    case tooManyRedirects
    case invalidRedirectLocation
}

nonisolated final class RedirectResolver {
    private static let trackingQueryItemNames: Set<String> = [
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_term",
        "utm_content",
        "fbclid",
        "gclid"
    ]

    private let session: URLSession
    private let maxRedirects: Int
    private let redirectDelegate: RedirectSuppressingDelegate?

    convenience init(maxRedirects: Int = 10) {
        self.init(configuration: .ephemeral, maxRedirects: maxRedirects)
    }

    init(configuration: URLSessionConfiguration, maxRedirects: Int = 10) {
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let redirectDelegate = RedirectSuppressingDelegate()
        self.session = URLSession(configuration: configuration, delegate: redirectDelegate, delegateQueue: nil)
        self.maxRedirects = maxRedirects
        self.redirectDelegate = redirectDelegate
    }

    func resolve(_ url: URL) async throws -> ResolvedURL {
        let finalURL = try await followRedirects(from: url)
        let cleanedURL = Self.removingTrackingParameters(from: finalURL)

        return ResolvedURL(
            finalURL: cleanedURL,
            cleanedDomain: Self.domain(from: cleanedURL),
            isShortener: ShortenerDomains.contains(host: url.host)
        )
    }

    private func followRedirects(from url: URL) async throws -> URL {
        var currentURL = url

        for _ in 0..<maxRedirects {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "HEAD"
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let (_, response) = try await session.data(for: request)

            guard
                let httpResponse = response as? HTTPURLResponse,
                (300..<400).contains(httpResponse.statusCode)
            else {
                return response.url ?? currentURL
            }

            guard let location = httpResponse.value(forHTTPHeaderField: "Location") else {
                return response.url ?? currentURL
            }

            guard let nextURL = URL(string: location, relativeTo: currentURL)?.absoluteURL else {
                throw RedirectResolverError.invalidRedirectLocation
            }

            currentURL = nextURL
        }

        throw RedirectResolverError.tooManyRedirects
    }

    private static func removingTrackingParameters(from url: URL) -> URL {
        guard
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
        else {
            return url
        }

        let filteredItems = queryItems.filter { item in
            !trackingQueryItemNames.contains(item.name.lowercased())
        }
        components.queryItems = filteredItems.isEmpty ? nil : filteredItems

        return components.url ?? url
    }

    private static func domain(from url: URL) -> String {
        url.host?.lowercased() ?? ""
    }
}

nonisolated private final class RedirectSuppressingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
