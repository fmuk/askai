import Foundation

enum CLIError: Error {
    case unavailable(String, exitCode: Int32)
    case invalidInput(String)
    case timeout
    case generationFailed(String, exitCode: Int32)

    var localizedDescription: String {
        switch self {
        case .unavailable(let message, _):
            return message
        case .invalidInput(let message):
            return message
        case .timeout:
            return "Operation timed out"
        case .generationFailed(let message, _):
            return message
        }
    }
}

enum ExitCode {
    static let success: Int32 = 0
    static let generalError: Int32 = 1
    static let usageError: Int32 = 2
    static let unavailable: Int32 = 10
    static let assetsNotReady: Int32 = 11
    static let unsupportedLanguage: Int32 = 12
    static let generationFailed: Int32 = 20
    static let timeout: Int32 = 21
    static let guardrail: Int32 = 22
    static let contextExceeded: Int32 = 23
}
