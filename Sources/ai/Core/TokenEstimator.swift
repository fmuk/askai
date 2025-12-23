import Foundation

struct TokenEstimator {
    // Rough heuristic: ~4 characters per token
    // This is approximate since the actual tokenizer isn't exposed
    private static let charsPerToken: Double = 4.0

    static func estimate(_ text: String) -> Int {
        return Int(ceil(Double(text.count) / charsPerToken))
    }

    static func estimatePrompt(
        system: String?,
        history: [(user: String, assistant: String)],
        currentPrompt: String
    ) -> Int {
        var total = 0

        if let sys = system {
            total += estimate(sys)
        }

        for turn in history {
            total += estimate(turn.user)
            total += estimate(turn.assistant)
        }

        total += estimate(currentPrompt)

        return total
    }
}
