import Foundation

struct NewsNowService: Sendable {
    func fetch(sourceID: String, sourceName: String, expectedDomain: String? = nil, baseURL: String, latest: Bool = false) async throws -> [HotNewsItem] {
        let endpoint = try makeURL(sourceID: sourceID, baseURL: baseURL, latest: latest)
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 20
        request.setValue("TrendRadar/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        let payload = try JSONDecoder().decode(NewsNowResponse.self, from: data)
        return payload.items.compactMap { item in
            guard Self.isAllowed(url: item.url, expectedDomain: expectedDomain) else { return nil }
            let id = "\(sourceID):\(item.id)"
            return HotNewsItem(id: id, title: item.title, url: item.url, platformID: sourceID, platformName: sourceName, rank: 0, publishedAt: item.pubDate.map { Date(timeIntervalSince1970: Double($0) / 1000) }, extraInfo: item.extra?.info, topicKey: Self.topicKey(for: item.title), previousRank: nil, isRead: false, isFavorite: false)
        }
        .enumerated()
        .map { index, item in
            var ranked = item
            ranked.rank = index + 1
            return ranked
        }
    }

    static func isAllowed(url: URL?, expectedDomain: String?) -> Bool {
        guard let url, url.scheme?.lowercased() == "https" else { return false }
        guard let expectedDomain = expectedDomain?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !expectedDomain.isEmpty else { return true }
        guard let host = url.host?.lowercased() else { return false }
        return host == expectedDomain || host.hasSuffix(".\(expectedDomain)")
    }

    static func topicKey(for title: String) -> String {
        title.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    private func makeURL(sourceID: String, baseURL: String, latest: Bool) throws -> URL {
        let normalized = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: "\(normalized)/s") else { throw URLError(.badURL) }
        components.queryItems = [URLQueryItem(name: "source", value: sourceID)]
        if latest { components.queryItems?.append(URLQueryItem(name: "latest", value: "true")) }
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }
}
