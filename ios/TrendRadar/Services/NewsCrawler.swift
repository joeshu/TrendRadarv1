import Foundation

struct NewsCrawler: Sendable {
    func fetch(feed: RSSFeed) async throws -> [NewsItem] {
        return try await NetworkRetrying.perform(attempts: feed.retryCount) {
            var request = URLRequest(url: feed.url)
            request.timeoutInterval = TimeInterval(feed.requestTimeout)
            request.setValue(feed.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml;q=0.9, */*;q=0.1", forHTTPHeaderField: "Accept")
            for (name, value) in feed.requestHeaders { request.setValue(value, forHTTPHeaderField: name) }
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw NetworkFetchError.transport(error)
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw NetworkFetchError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
            }

            return try parse(data: data, feed: feed)
        }
    }

    func parse(data: Data, feed: RSSFeed) throws -> [NewsItem] {
        let parser = RSSParser(feed: feed)
        parser.parse(data)
        if let error = parser.error { throw error }
        return parser.items.map { item in
            var cleaned = item
            cleaned.summary = TextSanitizer.plainText(item.summary)
            cleaned.body = TextSanitizer.plainText(item.body)
            return cleaned
        }
    }
}

enum NetworkFetchError: LocalizedError {
    case httpStatus(Int)
    case transport(Error)

    var isRetryable: Bool {
        switch self {
        case .httpStatus(let statusCode):
            return statusCode == 408 || statusCode == 429 || (500...599).contains(statusCode)
        case .transport(let error):
            guard let urlError = error as? URLError else { return true }
            return urlError.code != .cancelled
        }
    }

    var errorDescription: String? {
        switch self {
        case .httpStatus(let statusCode):
            return statusCode > 0 ? "服务器返回 HTTP \(statusCode)" : "服务器响应无效"
        case .transport(let error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet: return "设备当前没有互联网连接"
                case .timedOut: return "请求超时"
                case .cannotFindHost, .dnsLookupFailed: return "无法解析服务器地址"
                case .secureConnectionFailed: return "安全连接失败"
                case .cancelled: return "请求已取消"
                default: return "网络请求失败（\(urlError.code.rawValue)）"
                }
            }
            return "网络请求失败：\(error.localizedDescription)"
        }
    }
}

enum NetworkRetrying {
    static func perform<T: Sendable>(
        attempts: Int = 3,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch {
                attempt += 1
                guard let networkError = error as? NetworkFetchError,
                      attempt < max(1, attempts),
                      networkError.isRetryable else {
                    throw error
                }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 400_000_000)
            }
        }
    }
}

private final class RSSParser: NSObject, XMLParserDelegate {
    let feed: RSSFeed
    var items: [NewsItem] = []
    var error: Error?

    private var currentElement = ""
    private var currentItem: ParsedItem?
    private var text = ""

    init(feed: RSSFeed) {
        self.feed = feed
    }

    func parse(_ data: Data) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        parser.parse()
        error = parser.parserError
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = (qName ?? elementName).lowercased()
        text = ""
        if currentElement == "item" || currentElement == "entry" {
            currentItem = ParsedItem()
        } else if currentElement == "link", currentItem != nil,
                  let href = attributeDict["href"], !href.isEmpty {
            currentItem?.link = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let element = (qName ?? elementName).lowercased()
        guard currentItem != nil else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).decodedHTML
        switch element {
        case "title": currentItem?.title = value
        case "link":
            if !value.isEmpty { currentItem?.link = value }
        case "description", "summary": currentItem?.summary = value
        case "content", "content:encoded": currentItem?.body = value
        case "author", "dc:creator": currentItem?.author = value
        case "pubdate", "published", "updated": currentItem?.dateText = value
        case "item", "entry":
            guard let item = currentItem else { return }
            if !item.title.isEmpty {
                let url = URL(string: item.link)
                let id = url?.absoluteString ?? "\(feed.id):\(item.title)"
                items.append(NewsItem(id: id, title: item.title, source: feed.name, url: url, publishedAt: item.date, summary: item.summary, author: item.author, body: item.body))
            }
            currentItem = nil
        default: break
        }
        currentElement = ""
        text = ""
    }
}

private struct ParsedItem {
    var title = ""
    var link = ""
    var summary: String?
    var body: String?
    var author: String?
    var dateText = ""

    var date: Date? {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formats.lazy.compactMap { format in
            formatter.dateFormat = format
            return formatter.date(from: dateText)
        }.first
    }
}

private extension String {
    var decodedHTML: String {
        replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
