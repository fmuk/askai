import Foundation

/// Manages conversation transcript with optional persistence
struct SessionManager {
    struct Turn: Codable {
        let timestamp: Date
        let user: String
        let assistant: String
    }

    /// Save transcript to JSONL file
    static func save(
        transcript: [(user: String, assistant: String)],
        to path: String
    ) throws {
        let url = URL(fileURLWithPath: path)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        var jsonlContent = ""

        for turn in transcript {
            let turnData = Turn(timestamp: Date(), user: turn.user, assistant: turn.assistant)
            let data = try encoder.encode(turnData)
            if let jsonString = String(data: data, encoding: .utf8) {
                // JSONL format: one JSON object per line
                let compactJSON = jsonString.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "  ", with: "")
                jsonlContent += compactJSON + "\n"
            }
        }

        try jsonlContent.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Load transcript from JSONL file
    static func load(from path: String) throws -> [(user: String, assistant: String)] {
        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var transcript: [(String, String)] = []

        for line in content.split(separator: "\n") {
            if let data = line.data(using: .utf8),
               let turn = try? decoder.decode(Turn.self, from: data) {
                transcript.append((user: turn.user, assistant: turn.assistant))
            }
        }

        return transcript
    }
}

/// In-memory conversation transcript
struct ConversationSession {
    private(set) var transcript: [(user: String, assistant: String)] = []
    let system: String?

    init(system: String? = nil) {
        self.system = system
    }

    mutating func addTurn(user: String, assistant: String) {
        transcript.append((user: user, assistant: assistant))
    }

    func getTurns() -> [(user: String, assistant: String)] {
        return transcript
    }

    func isEmpty() -> Bool {
        return transcript.isEmpty
    }

    func count() -> Int {
        return transcript.count
    }
}
