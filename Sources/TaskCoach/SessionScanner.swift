import Foundation

/// Reads Claude Code transcripts (~/.claude/projects/*/*.jsonl) and turns them into tasks.
final class SessionScanner {
    private struct CacheEntry { var mtime: Date; var info: SessionInfo }
    private var cache: [String: CacheEntry] = [:]

    private static let linearURL = try! NSRegularExpression(pattern: #"linear\.app/[^/\s]+/issue/([A-Za-z][A-Za-z0-9]{0,9}-\d{1,6})"#)
    private static let looseTicket = try! NSRegularExpression(pattern: #"(?i)\b([a-z][a-z0-9]{1,9})-(\d{1,6})\b"#)

    func scan(lookbackDays: Int) -> [SessionInfo] {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-Double(lookbackDays) * 86_400)
        guard let projects = try? fm.contentsOfDirectory(at: Paths.claudeProjects, includingPropertiesForKeys: nil) else { return [] }

        var out: [SessionInfo] = []
        for project in projects {
            // Only top-level transcripts; subagent transcripts live in nested folders.
            guard let files = try? fm.contentsOfDirectory(at: project, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                guard let mtime = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                      mtime >= cutoff else { continue }
                if let hit = cache[file.path], hit.mtime == mtime {
                    out.append(hit.info)
                    continue
                }
                if let info = parseMetadata(file: file, mtime: mtime) {
                    cache[file.path] = CacheEntry(mtime: mtime, info: info)
                    out.append(info)
                }
            }
        }
        return out
    }

    private func parseMetadata(file: URL, mtime: Date) -> SessionInfo? {
        guard let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { return nil }
        var title: String?
        var firstPrompt: String?
        var branch: String?
        var turns = 0
        var tickets: [String: Int] = [:]

        for line in data.split(separator: 0x0A) {
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let type = obj["type"] as? String else { continue }
            if (obj["isSidechain"] as? Bool) == true { continue }
            if let b = obj["gitBranch"] as? String, !b.isEmpty, b != "HEAD" { branch = b }

            switch type {
            case "custom-title":
                title = obj["customTitle"] as? String
            case "user":
                guard let text = Self.humanText(obj) else { continue }
                if firstPrompt == nil { firstPrompt = text }
                for id in Self.matches(Self.linearURL, in: text) { tickets[id.uppercased(), default: 0] += 3 }
            case "assistant":
                turns += 1
                let blocks = ((obj["message"] as? [String: Any])?["content"] as? [[String: Any]]) ?? []
                for block in blocks where (block["type"] as? String) == "tool_use" {
                    let name = block["name"] as? String ?? ""
                    if name.hasSuffix("get_issue"), let id = (block["input"] as? [String: Any])?["id"] as? String {
                        tickets[id.uppercased(), default: 0] += 3
                    }
                }
            default:
                break
            }
        }
        guard turns >= 3 else { return nil }

        let branchCandidate = branch.flatMap { Self.matches(Self.looseTicket, in: $0).first?.uppercased() }
        let ranked = tickets.sorted { $0.value > $1.value }.map(\.key)
        let fallbackTitle = firstPrompt.map { String($0.prefix(70)) } ?? "Untitled session"

        return SessionInfo(
            id: file.deletingPathExtension().lastPathComponent,
            path: file,
            title: title ?? fallbackTitle,
            branch: branch,
            lastModified: mtime,
            assistantTurns: turns,
            ticketIds: ranked,
            branchTicketCandidate: branchCandidate
        )
    }

    /// Groups sessions into tasks: one per Linear ticket, otherwise one per session.
    static func group(_ sessions: [SessionInfo], linear: [LinearIssue]) -> [TaskItem] {
        // A branch like "feature/ai-1680-x" only counts when its prefix is a team key we've
        // seen elsewhere, so "sprint-89" or "utf-8" don't become fake tickets.
        var knownPrefixes = Set(sessions.flatMap(\.ticketIds).compactMap { $0.split(separator: "-").first.map(String.init) })
        knownPrefixes.formUnion(linear.compactMap { $0.identifier.split(separator: "-").first.map(String.init) })

        var byKey: [String: TaskItem] = [:]
        for issue in linear {
            byKey[issue.identifier] = TaskItem(key: issue.identifier, ticketId: issue.identifier, title: issue.title,
                                               sessions: [], lastActivity: .distantPast, linear: issue)
        }
        for s in sessions {
            var ticket = s.ticketIds.first
            if ticket == nil, let cand = s.branchTicketCandidate,
               let prefix = cand.split(separator: "-").first, knownPrefixes.contains(String(prefix)) {
                ticket = cand
            }
            let key = ticket ?? "session:\(s.id)"
            var item = byKey[key] ?? TaskItem(key: key, ticketId: ticket, title: s.title, sessions: [],
                                              lastActivity: .distantPast, linear: nil)
            item.sessions.append(s)
            if s.lastModified > item.lastActivity {
                item.lastActivity = s.lastModified
                if item.linear == nil { item.title = s.title }
            }
            byKey[key] = item
        }
        return byKey.values
            .map { var t = $0; t.sessions.sort { $0.lastModified > $1.lastModified }; return t }
            .sorted { $0.lastActivity > $1.lastActivity }
    }

    // MARK: - Digest for the quiz prompt

    /// A compact, readable version of a transcript: what was asked, what Claude said and did,
    /// and any Linear ticket it fetched. Tool output is mostly dropped; it's huge and low-signal.
    static func digest(of session: SessionInfo, maxChars: Int) -> String {
        guard let data = try? Data(contentsOf: session.path, options: .mappedIfSafe) else { return "" }
        var parts: [String] = []
        var toolNames: [String: String] = [:]

        for line in data.split(separator: 0x0A) {
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let type = obj["type"] as? String else { continue }
            if (obj["isSidechain"] as? Bool) == true { continue }

            if type == "user" {
                if let text = humanText(obj) {
                    parts.append("ENGINEER: " + String(text.prefix(1500)))
                    continue
                }
                let blocks = ((obj["message"] as? [String: Any])?["content"] as? [[String: Any]]) ?? []
                for block in blocks where (block["type"] as? String) == "tool_result" {
                    guard let useId = block["tool_use_id"] as? String, let name = toolNames[useId],
                          name.hasSuffix("get_issue") || name.hasSuffix("list_comments") else { continue }
                    parts.append("[Linear ticket data]: " + String(flattenToolResult(block["content"]).prefix(4000)))
                }
            } else if type == "assistant" {
                let blocks = ((obj["message"] as? [String: Any])?["content"] as? [[String: Any]]) ?? []
                for block in blocks {
                    switch block["type"] as? String {
                    case "text":
                        if let t = block["text"] as? String, !t.isEmpty { parts.append("CLAUDE: " + String(t.prefix(1500))) }
                    case "tool_use":
                        let name = block["name"] as? String ?? "tool"
                        if let id = block["id"] as? String { toolNames[id] = name }
                        if let summary = toolSummary(name: name, input: block["input"] as? [String: Any] ?? [:]) {
                            parts.append(summary)
                        }
                    default:
                        break
                    }
                }
            }
        }

        let header = "### Session \"\(session.title)\"" + (session.branch.map { " (branch \($0))" } ?? "")
        let body = parts.joined(separator: "\n")
        guard body.count > maxChars else { return header + "\n" + body }
        // Keep the opening (where the task is stated) and the most recent work.
        let headLen = maxChars / 4
        let head = body.prefix(headLen)
        let tail = body.suffix(maxChars - headLen)
        return header + "\n" + head + "\n[... middle of session omitted ...]\n" + tail
    }

    private static func toolSummary(name: String, input: [String: Any]) -> String? {
        func s(_ key: String) -> String? { input[key] as? String }
        switch name {
        case "Edit", "Write", "MultiEdit", "NotebookEdit":
            return s("file_path").map { "[edited \($0)]" }
        case "Read":
            return s("file_path").map { "[read \($0)]" }
        case "Bash":
            guard let cmd = s("command") else { return nil }
            return "[ran: \(cmd.prefix(160))]"
        case "Grep", "Glob":
            return s("pattern").map { "[searched for \($0.prefix(80))]" }
        case "Agent", "Task":
            return s("description").map { "[delegated: \($0)]" }
        default:
            if name.hasPrefix("mcp__") {
                let short = name.split(separator: "__").last.map(String.init) ?? name
                return "[used \(short)]"
            }
            return nil
        }
    }

    private static func flattenToolResult(_ content: Any?) -> String {
        if let s = content as? String { return s }
        if let arr = content as? [[String: Any]] {
            return arr.compactMap { $0["text"] as? String }.joined(separator: "\n")
        }
        return ""
    }

    /// Text the engineer actually typed, skipping tool results and injected system text.
    static func humanText(_ obj: [String: Any]) -> String? {
        if let origin = obj["turnOrigin"] as? String, origin != "human" { return nil }
        if (obj["isMeta"] as? Bool) == true { return nil }
        guard let message = obj["message"] as? [String: Any] else { return nil }
        var text: String?
        if let s = message["content"] as? String {
            text = s
        } else if let blocks = message["content"] as? [[String: Any]] {
            let texts = blocks.filter { ($0["type"] as? String) == "text" }.compactMap { $0["text"] as? String }
            if blocks.contains(where: { ($0["type"] as? String) == "tool_result" }) { return nil }
            text = texts.isEmpty ? nil : texts.joined(separator: "\n")
        }
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, !t.hasPrefix("<") else { return nil }
        return t
    }

    private static func matches(_ regex: NSRegularExpression, in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { m in
            if regex === looseTicket, let a = Range(m.range(at: 1), in: text), let b = Range(m.range(at: 2), in: text) {
                return "\(text[a])-\(text[b])"
            }
            return Range(m.range(at: 1), in: text).map { String(text[$0]) }
        }
    }
}
