import Foundation

/// Unified errors emitted by refresh pipeline stages.
enum PipelineError: Error, Sendable {
    case collectorFailed(String)
    case filterFailed(String)
    case persistFailed(String)
    case reportFailed(String)
    case deliveryFailed(String)
}
