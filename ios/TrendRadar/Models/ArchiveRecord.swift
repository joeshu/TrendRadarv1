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
    var body: String?
    var capturedAt: Date
    var archivedAt: Date?
    var isFavorite: Bool
    var snapshotVersion: String?
    var contentSize: Int?
    var checksum: String?

    init(resource: ArchiveResource) {
        id = resource.id
        resourceID = resource.resourceID
        kind = resource.kind.rawValue
        title = resource.title
        source = resource.source
        urlString = resource.url?.absoluteString
        summary = resource.summary
        body = resource.body
        capturedAt = resource.capturedAt
        archivedAt = resource.archivedAt
        isFavorite = resource.isFavorite
        snapshotVersion = resource.snapshotVersion
        contentSize = resource.contentSize
        checksum = resource.checksum
    }

    func update(with resource: ArchiveResource) {
        resourceID = resource.resourceID
        kind = resource.kind.rawValue
        title = resource.title
        source = resource.source
        urlString = resource.url?.absoluteString
        summary = resource.summary
        body = resource.body
        capturedAt = resource.capturedAt
        archivedAt = resource.archivedAt
        isFavorite = resource.isFavorite
        snapshotVersion = resource.snapshotVersion
        contentSize = resource.contentSize
        checksum = resource.checksum
    }

    var asResource: ArchiveResource? {
        guard let resourceKind = ArchiveResourceKind(rawValue: kind) else { return nil }
        return ArchiveResource(resourceID: resourceID, kind: resourceKind, title: title, source: source, url: urlString.flatMap(URL.init(string:)), summary: summary, body: body, capturedAt: capturedAt, archivedAt: archivedAt, isFavorite: isFavorite, snapshotVersion: snapshotVersion, contentSize: contentSize, checksum: checksum)
    }
}
