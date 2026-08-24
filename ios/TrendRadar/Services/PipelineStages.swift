import Foundation

struct RefreshPipelineInput {
    let settings: AppSettings
    let trigger: RefreshTrigger
}

struct RefreshPipelineOutput {
    var items: [NewsItem]
    var hotNews: [HotNewsItem]
}

enum PipelineStageError: Error {
    case notImplemented
}

protocol RefreshPipelineStage {
    associatedtype Input
    associatedtype Output
    func execute(_ input: Input) async throws -> Output
}

struct CollectorStage: RefreshPipelineStage {
    func execute(_ input: RefreshPipelineInput) async throws -> [NewsItem] {
        try Task.checkCancellation()
        return []
    }
}

struct FilterStage: RefreshPipelineStage {
    func execute(_ input: [NewsItem]) async throws -> [NewsItem] {
        try Task.checkCancellation()
        return input
    }
}

struct PersistStage: RefreshPipelineStage {
    func execute(_ input: [NewsItem]) async throws -> [NewsItem] {
        try Task.checkCancellation()
        await LocalStore.shared.save(input)
        return input
    }
}
