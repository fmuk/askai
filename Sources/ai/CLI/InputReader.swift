import Foundation

struct InputReader {
    static func resolve(prompt: String?, useStdin: Bool) throws -> String {
        // 1. Command-line argument
        if let prompt = prompt {
            return prompt
        }

        // 2. stdin
        if useStdin {
            var input = ""
            while let line = readLine() {
                input += line + "\n"
            }
            return input.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 3. Interactive
        print("> ", terminator: "")
        fflush(stdout)

        var lines: [String] = []
        while let line = readLine() {
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    static func readREPLInput() -> String? {
        print("> ", terminator: "")
        fflush(stdout)
        return readLine()
    }
}
