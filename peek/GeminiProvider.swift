import Foundation

enum GeminiProviderError: Error, Equatable {
    case httpError(Int)
    case unexpectedResponse
}

struct GeminiProvider: LLMProvider {
    private static let endpoint = URL(
        string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    )!

    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func cleanDescription(_ raw: String) async throws -> String {
        guard !raw.isEmpty else { return raw }

        // Truncate to guard against prompt-injection via a hostile og:description.
        let safeRaw = String(raw.prefix(500))

        let prompt = """
            Rewrite the following website description as a single plain-English sentence. \
            Return only the sentence, no extra text.\n\n\(safeRaw)
            """

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15  // generous ceiling for a single-turn LLM call over a good connection
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw GeminiProviderError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try parseResponse(data: data)
    }

    private func parseResponse(data: Data) throws -> String {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw GeminiProviderError.unexpectedResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
