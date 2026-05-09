import Foundation

final class MetadataFetcher {
    static let bodyCap = 65_536  // 64 KB hard cap
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(_ url: URL) async -> PageMetadata {
        guard let html = try? await loadHead(from: url) else {
            return PageMetadata(title: nil, description: nil, faviconURL: nil)
        }
        return Self.parse(html: html, baseURL: url)
    }

    // Internal so tests can drive parsing directly without network.
    static func parse(html: String, baseURL: URL) -> PageMetadata {
        PageMetadata(
            title: metaContent("og:title", in: html) ?? titleTag(in: html),
            description: metaContent("og:description", in: html),
            faviconURL: faviconHref(in: html, baseURL: baseURL)
                ?? URL(string: "/favicon.ico", relativeTo: baseURL)?.absoluteURL
        )
    }

    private func loadHead(from url: URL) async throws -> String {
        let (stream, _) = try await session.bytes(for: URLRequest(url: url))
        var buffer = Data()

        for try await byte in stream {
            buffer.append(byte)
            if buffer.count >= Self.bodyCap { break }
            // Stop once we've seen </head> — no need to read the body.
            if buffer.count >= 7 {
                let tail = buffer.suffix(7)
                if let s = String(bytes: tail, encoding: .utf8), s.lowercased() == "</head>" { break }
            }
        }

        return String(decoding: buffer, as: UTF8.self)
    }

    // MARK: - Parsing helpers

    // Matches <meta property="P" content="V"> and <meta content="V" property="P">
    private static func metaContent(_ property: String, in html: String) -> String? {
        let escapedProp = NSRegularExpression.escapedPattern(for: property)
        let patterns = [
            "(?i)<meta[^>]+property=[\"']\(escapedProp)[\"'][^>]+content=[\"']([^\"'<>]+)[\"']",
            "(?i)<meta[^>]+content=[\"']([^\"'<>]+)[\"'][^>]+property=[\"']\(escapedProp)[\"']"
        ]
        return firstCapture(patterns: patterns, in: html)
    }

    // Falls back to <title> text when og:title is absent.
    private static func titleTag(in html: String) -> String? {
        firstCapture(patterns: ["(?i)<title[^>]*>([^<]+)</title>"], in: html)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    // Prefers <link rel="icon"> href; accepts "shortcut icon" too.
    private static func faviconHref(in html: String, baseURL: URL) -> URL? {
        let patterns = [
            "(?i)<link[^>]+rel=[\"'][^\"']*icon[^\"']*[\"'][^>]+href=[\"']([^\"'<>]+)[\"']",
            "(?i)<link[^>]+href=[\"']([^\"'<>]+)[\"'][^>]+rel=[\"'][^\"']*icon[^\"']*[\"']"
        ]
        guard let href = firstCapture(patterns: patterns, in: html) else { return nil }
        return URL(string: href, relativeTo: baseURL)?.absoluteURL
    }

    private static func firstCapture(patterns: [String], in html: String) -> String? {
        let nsHTML = html as NSString
        let fullRange = NSRange(location: 0, length: nsHTML.length)
        for pattern in patterns {
            guard
                let regex = try? NSRegularExpression(pattern: pattern),
                let match = regex.firstMatch(in: html, range: fullRange),
                let range = Range(match.range(at: 1), in: html)
            else { continue }
            return String(html[range])
        }
        return nil
    }
}
