import Foundation

actor SafeBrowsingClient: ThreatChecker {
    private nonisolated static let lookupURL = URL(string: "https://safebrowsing.googleapis.com/v4/threatMatches:find")!

    private let apiKey: String?
    private let session: URLSession
    private let ttl: TimeInterval
    private var cache: [String: CachedResult] = [:]

    init(apiKey: String?, session: URLSession = .shared, ttl: TimeInterval = 3600) {
        self.apiKey = apiKey?.isEmpty == false ? apiKey : nil
        self.session = session
        self.ttl = ttl
    }

    func check(domain: String) async -> ThreatResult {
        if let cached = cache[domain], !cached.isExpired {
            return cached.result
        }

        let result = await lookup(domain: domain)
        cache[domain] = CachedResult(result: result, ttl: ttl)
        return result
    }

    private func lookup(domain: String) async -> ThreatResult {
        guard let apiKey else { return .clean }

        guard let request = makeRequest(domain: domain, apiKey: apiKey) else { return .clean }

        guard
            let (data, response) = try? await session.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return .clean }

        return parseResponse(data: data)
    }

    private func makeRequest(domain: String, apiKey: String) -> URLRequest? {
        var components = URLComponents(url: Self.lookupURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else { return nil }

        let body: [String: Any] = [
            "client": ["clientId": "peek", "clientVersion": "1.0"],
            "threatInfo": [
                "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE"],
                "platformTypes": ["ANY_PLATFORM"],
                "threatEntryTypes": ["URL"],
                "threatEntries": [["url": "https://\(domain)/"]]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        return request
    }

    private func parseResponse(data: Data) -> ThreatResult {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let matches = json["matches"] as? [[String: Any]],
            !matches.isEmpty
        else { return .clean }
        return .flagged
    }

    private struct CachedResult {
        let result: ThreatResult
        let expiresAt: Date

        init(result: ThreatResult, ttl: TimeInterval) {
            self.result = result
            self.expiresAt = Date().addingTimeInterval(ttl)
        }

        var isExpired: Bool { Date() >= expiresAt }
    }
}
