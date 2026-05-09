import Foundation

nonisolated enum ShortenerDomains {
    private static let knownDomains: Set<String> = [
        "bit.ly", "t.co", "tinyurl.com", "ow.ly", "short.link",
        "goo.gl", "buff.ly", "ift.tt", "dlvr.it", "tiny.cc",
        "rb.gy", "cutt.ly", "shorturl.at"
    ]

    static func contains(host: String?) -> Bool {
        guard let host else { return false }

        let lowercasedHost = host.lowercased()
        let normalizedHost = lowercasedHost.hasPrefix("www.")
            ? String(lowercasedHost.dropFirst(4))
            : lowercasedHost
        return knownDomains.contains(normalizedHost)
    }
}
