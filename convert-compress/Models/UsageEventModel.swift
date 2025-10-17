import Foundation

struct UsageEventModel: Codable, Equatable {
    enum Kind: String, Codable {
        case imageConversion
        case pipelineApplied
    }

    let kind: Kind
    let date: Date
}
