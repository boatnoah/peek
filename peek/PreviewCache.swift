import Foundation

actor PreviewCache {
    static let maxEntries = 200

    private var store: [String: EnrichmentResult] = [:]
    private var order: [String] = []

    func get(_ url: String) -> EnrichmentResult? {
        guard let result = store[url] else { return nil }
        promote(url)
        return result
    }

    func set(_ url: String, result: EnrichmentResult) {
        if store[url] != nil {
            promote(url)
        } else {
            if store.count >= Self.maxEntries {
                let lru = order.removeFirst()
                store.removeValue(forKey: lru)
            }
            order.append(url)
        }
        store[url] = result
    }

    private func promote(_ url: String) {
        if let index = order.firstIndex(of: url) {
            order.remove(at: index)
            order.append(url)
        }
    }
}
