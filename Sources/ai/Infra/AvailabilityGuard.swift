import Foundation
import FoundationModels

@available(macOS 26.0, *)
struct AvailabilityGuard {
    static func check() throws {
        switch SystemLanguageModel.default.availability {
        case .available:
            return
        case .unavailable(.appleIntelligenceNotEnabled):
            throw CLIError.unavailable(
                "Apple Intelligence is not enabled. Enable it in System Settings → Apple Intelligence & Siri.",
                exitCode: ExitCode.unavailable
            )
        case .unavailable(.deviceNotEligible):
            throw CLIError.unavailable(
                "This device doesn't support Apple Intelligence. Apple Silicon Mac required.",
                exitCode: ExitCode.unavailable
            )
        case .unavailable(.modelNotReady):
            throw CLIError.unavailable(
                "Model assets are still downloading. Try again in a few minutes.",
                exitCode: ExitCode.assetsNotReady
            )
        case .unavailable(_):
            throw CLIError.unavailable(
                "Apple Intelligence is unavailable.",
                exitCode: ExitCode.unavailable
            )
        }
    }
}
