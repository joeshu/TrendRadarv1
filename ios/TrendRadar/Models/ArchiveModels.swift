import Foundation

enum ArchiveResourceKind: String, Codable, CaseIterable, Sendable {
    case hotlist
    case rss
    case report
}

struct ArchiveResource: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let resourceID: String
    let kind: ArchiveResourceKind
    var title: String
    var source: String
    var url: URL?
    var summary: String?
    var capturedAt: Date
    var isFavorite: Bool

    init(resourceID: String, kind: ArchiveResourceKind, title: String, source: String, url: URL? = nil, summary: String? = nil, capturedAt: Date = Date(), isFavorite: Bool = true) {
        self.resourceID = resourceID
        self.kind = kind
        self.id = "\(kind.rawValue):\(resourceID)"
        self.title = title
        self.source = source
        self.url = url
        self.summary = summary
        self.capturedAt = capturedAt
        self.isFavorite = isFavorite
    }
}
