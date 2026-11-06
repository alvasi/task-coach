import Foundation

enum ClaudeError: LocalizedError {
    case notFound
    case failed(String)
    case badOutput(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Couldn't find the claude CLI. Set its path in Settings."
        case .failed(let msg):
            if msg.localizedCaseInsensitiveContains("auth") || msg.localizedCaseInsensitiveContains("login") {
                return "Claude CLI isn't logged in (\(msg)). Open Terminal, run claude, then type /login."
            }
            return msg
        case .badOutput(let msg):
            return "Claude replied in an unexpected shape: \(msg)"
        }
    }
}

enum ClaudeRunner {
    /// The desktop app ships its CLI at a versioned path that changes on update,
    /// so look it up each time rather than caching it.
    static func locate(override: String?) -> String? {
        let fm = FileManager.default
        if let override, !override.isEmpty, fm.isExecutableFile(atPath: override) { return override }

        let home = fm.homeDirectoryForCurrentUser.path
        for candidate in ["\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude", "\(home)/.claude/local/claude"]
        where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }

        let desktopRoot = "\(home)/Library/Application Support/Claude/claude-code"
        guard let versions = try? fm.contentsOfDirectory(atPath: desktopRoot) else { return nil }
        let sorted = versions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
        for version in sorted {
            let versionDir = "\(desktopRoot)/\(version)"
            for build in (try? fm.contentsOfDirectory(atPath: versionDir)) ?? [] {
                let bin = "\(versionDir)/\(build)/claude.app/Contents/MacOS/claude"
                if fm.isExecutableFile(atPath: bin) { return bin }
            }
        }
        return nil
    }

    /// Runs one headless, tool-less claude turn and returns the structured JSON it produced.
    static func run(prompt: String, systemPrompt: String, schema: String, model: String,
                    claudePath: String?, timeout: TimeInterval = 240, label: String = "quiz") async throws -> Data {
        guard let bin = locate(override: claudePath) else { throw ClaudeError.notFound }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bin)
        process.currentDirectoryURL = Paths.work
        process.arguments = [
            "-p",
            "--output-format", "json",
            "--json-schema", schema,
            "--model", model,
            "--system-prompt", systemPrompt,
            "--no-session-persistence",
            "--strict-mcp-config",
            "--setting-sources", "",
            "--tools", "",
        ]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env

        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        // Read both pipes concurrently so a chatty stderr can't deadlock the child.
        async let outData = Task.detached { stdout.fileHandleForReading.readDataToEndOfFile() }.value
        async let errData = Task.detached { stderr.fileHandleForReading.readDataToEndOfFile() }.value

        stdin.fileHandleForWriting.write(Data(prompt.utf8))
        try? stdin.fileHandleForWriting.close()

        let timer = Task.detached {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if process.isRunning { process.terminate() }
        }
        let (out, err) = await (outData, errData)
        process.waitUntilExit()
        timer.cancel()

        guard let envelope = try? JSONSerialization.jsonObject(with: out) as? [String: Any] else {
            let errText = String(data: err, encoding: .utf8) ?? ""
            let outText = String(data: out, encoding: .utf8) ?? ""
            throw ClaudeError.failed(String((errText + outText).prefix(400)).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        UsageLog.append(label: label, model: model, envelope: envelope)
        if (envelope["is_error"] as? Bool) == true {
            throw ClaudeError.failed((envelope["result"] as? String) ?? "unknown error")
        }
        if let structured = envelope["structured_output"], !(structured is NSNull) {
            return try JSONSerialization.data(withJSONObject: structured)
        }
        // Fallback: the JSON came back as plain text, possibly fenced.
        if let text = envelope["result"] as? String, let data = extractJSON(text) {
            return data
        }
        throw ClaudeError.badOutput(String(describing: envelope["result"] ?? "nothing").prefix(200).description)
    }

    private static func extractJSON(_ text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        let slice = String(text[start...end])
        guard (try? JSONSerialization.jsonObject(with: Data(slice.utf8))) != nil else { return nil }
        return Data(slice.utf8)
    }
}

/// One line per Claude call in usage.jsonl, so token use can be measured rather than guessed.
enum UsageLog {
    static let file = Paths.support.appendingPathComponent("usage.jsonl")

    static func append(label: String, model: String, envelope: [String: Any]) {
        let usage = envelope["usage"] as? [String: Any] ?? [:]
        let entry: [String: Any] = [
            "at": ISO8601DateFormatter().string(from: Date()),
            "label": label,
            "model": model,
            "input": usage["input_tokens"] ?? 0,
            "cacheRead": usage["cache_read_input_tokens"] ?? 0,
            "cacheWrite": usage["cache_creation_input_tokens"] ?? 0,
            "output": usage["output_tokens"] ?? 0,
            "costUSD": envelope["total_cost_usd"] ?? 0,
            "ms": envelope["duration_ms"] ?? 0,
        ]
        guard var line = try? JSONSerialization.data(withJSONObject: entry) else { return }
        line.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: file)
        }
    }
}
