import Foundation

struct CoordinationResult: Identifiable, Codable, Hashable {
    var id: String
    var requestId: String
    var rankedCandidates: [CoordinatedTimeCandidate]
    var bestCandidate: CoordinatedTimeCandidate?
    var generatedAt: Date

    init(
        id: String = UUID().uuidString,
        requestId: String,
        rankedCandidates: [CoordinatedTimeCandidate],
        bestCandidate: CoordinatedTimeCandidate?,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.requestId = requestId
        self.rankedCandidates = rankedCandidates
        self.bestCandidate = bestCandidate
        self.generatedAt = generatedAt
    }
}
