import Foundation

struct SocialGraphNode: Identifiable, Equatable {
    let id: String
    let displayName: String
    let degree: Int
    let isTarget: Bool
    let isSource: Bool
}

struct SocialGraphEdge: Identifiable, Equatable {
    let id: String
    let from: String
    let to: String
}

struct SocialGraphSnapshot: Equatable {
    let sourceUser: String
    let nodes: [SocialGraphNode]
    let edges: [SocialGraphEdge]
    let generatedAt: Date
}
