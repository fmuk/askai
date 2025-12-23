import Foundation

struct ContextManager {
    // Apple Intelligence on-device model has a 4096 token context window
    static let maxContextTokens = 4096
    static let defaultSystemBudget = 500
    static let defaultHistoryBudget = 2048
    static let defaultPromptBudget = 1000
    static let defaultResponseBudget = 548

    let systemBudget: Int
    let historyBudget: Int

    init(systemBudget: Int = defaultSystemBudget,
         historyBudget: Int = defaultHistoryBudget) {
        self.systemBudget = systemBudget
        self.historyBudget = historyBudget
    }

    /// Build context by including as much history as fits within the budget
    func buildContext(
        system: String?,
        history: [(user: String, assistant: String)],
        currentPrompt: String
    ) -> (includedHistory: [(user: String, assistant: String)], truncated: Bool) {

        // Estimate tokens for system instruction
        var systemTokens = 0
        if let sys = system {
            systemTokens = TokenEstimator.estimate(sys)
            // If system instruction exceeds budget, that's a problem but we'll include it anyway
        }

        // Estimate tokens for current prompt
        let promptTokens = TokenEstimator.estimate(currentPrompt)

        // Calculate available budget for history
        let availableForHistory = historyBudget

        // Include as many recent turns as fit within budget
        var includedHistory: [(String, String)] = []
        var historyTokens = 0

        // Iterate from most recent to oldest
        for turn in history.reversed() {
            let turnTokens = TokenEstimator.estimate(turn.user) +
                           TokenEstimator.estimate(turn.assistant)

            if historyTokens + turnTokens <= availableForHistory {
                includedHistory.insert(turn, at: 0)
                historyTokens += turnTokens
            } else {
                // No more room for older turns
                break
            }
        }

        let wasTruncated = includedHistory.count < history.count

        return (includedHistory, wasTruncated)
    }

    /// Estimate total tokens in the context
    func estimateTotal(
        system: String?,
        history: [(user: String, assistant: String)],
        currentPrompt: String
    ) -> Int {
        return TokenEstimator.estimatePrompt(
            system: system,
            history: history,
            currentPrompt: currentPrompt
        )
    }
}
