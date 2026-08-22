import Foundation

struct NewsNowService: Sendable {
    func fetch(sourceID: String, sourceName: String, expectedDomain: String? = nil, baseURL: String, latest: Bool = false) async throws -> [HotNewsItem] {
        let endpoint = try makeURL(sourceID: sourceID, baseURL: baseURL, latest: latest)
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 20
        request.setValue("TrendRadar/1.0", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw NetworkFetchError.transport(error)
        }
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw NetworkFetchError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let payload = try JSONDecoder().decode(NewsNowResponse.self, from: data)
        let filteredItems: [NewsNowItem] = payload.items.filter { item in
            Self.isAllowed(url: item.url, expectedDomain: expectedDomain)
        }
        return filteredItems.enumerated().map { index, item in
            let id = "\(sourceID):\(item.id)"
            return HotNewsItem(id: id, title: item.title, url: item.url, platformID: sourceID, platformName: sourceName, rank: index + 1, publishedAt: item.pubDate.map { Date(timeIntervalSince1970: Double($0) / 1000) }, extraInfo: item.extra?.info, topicKey: Self.topicKey(for: item.title), previousRank: nil, isRead: false, isFavorite: false)
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
        let endpoint = normalized.hasSuffix("/s") ? normalized : "\(normalized)/s"
        guard var components = URLComponents(string: endpoint) else { throw URLError(.badURL) }
        components.queryItems = [URLQueryItem(name: "id", value: sourceID)]
        if latest { components.queryItems?.append(URLQueryItem(name: "latest", value: "true")) }
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }
}
