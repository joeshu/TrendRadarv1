import Foundation

struct NewsCrawler: Sendable {
    func fetch(feed: RSSFeed) async throws -> [NewsItem] {
        let (data, response) = try await URLSession.shared.data(from: feed.url)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try parse(data: data, feed: feed)
    }

    func parse(data: Data, feed: RSSFeed) throws -> [NewsItem] {
        let parser = RSSParser(feed: feed)
        parser.parse(data)
        if let error = parser.error { throw error }
        return parser.items
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
        currentElement = elementName.lowercased()
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
        let element = elementName.lowercased()
        guard currentItem != nil else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).decodedHTML
        switch element {
        case "title": currentItem?.title = value
        case "link":
            if !value.isEmpty { currentItem?.link = value }
        case "description", "summary", "content": currentItem?.summary = value
        case "pubdate", "published", "updated": currentItem?.dateText = value
        case "item", "entry":
            guard let item = currentItem else { return }
            if !item.title.isEmpty {
                let url = URL(string: item.link)
                let id = url?.absoluteString ?? "\(feed.id):\(item.title)"
                items.append(NewsItem(id: id, title: item.title, source: feed.name, url: url, publishedAt: item.date, summary: item.summary))
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
