import Foundation
import SwiftData

@Model
final class ArchiveRecord {
    @Attribute(.unique) var id: String
    var resourceID: String
    var kind: String
    var title: String
    var source: String
    var urlString: String?
    var summary: String?
    var capturedAt: Date
    var isFavorite: Bool

    init(resource: ArchiveResource) {
        id = resource.id
        resourceID = resource.resourceID
        kind = resource.kind.rawValue
        title = resource.title
        source = resource.source
        urlString = resource.url?.absoluteString
        summary = resource.summary
        capturedAt = resource.capturedAt
        isFavorite = resource.isFavorite
    }

    func update(with resource: ArchiveResource) {
        resourceID = resource.resourceID
        kind = resource.kind.rawValue
        title = resource.title
        source = resource.source
        urlString = resource.url?.absoluteString
        summary = resource.summary
        capturedAt = resource.capturedAt
        isFavorite = resource.isFavorite
    }

    var asResource: ArchiveResource? {
        guard let resourceKind = ArchiveResourceKind(rawValue: kind) else { return nil }
        return ArchiveResource(resourceID: resourceID, kind: resourceKind, title: title, source: source, url: urlString.flatMap(URL.init(string:)), summary: summary, capturedAt: capturedAt, isFavorite: isFavorite)
    }
}
