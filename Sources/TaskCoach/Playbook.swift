import Foundation

/// One practice from playbook.md: a rule, why it matters, and where it comes from.
struct PlaybookEntry: Identifiable, Hashable {
    var id: String
    var skill: Skill
    var rule: String
    var why: String
    var source: String
    var checked: String
    /// The page it was checked against, if any.
    var url: URL?
}

/// The fact-checked playbook every "name the practice" and transfer question must cite.
/// The app ships a copy; the editable one lives in Application Support so your edits survive updates.
enum Playbook {
    static let userFile = Paths.support.appendingPathComponent("playbook.md")

    static func load() -> [PlaybookEntry] {
        ensureUserCopy()
        guard let text = try? String(contentsOf: userFile, encoding: .utf8) else { return [] }
        return parse(text)
    }

    /// The bundled version you last received, so updates can tell your edits from old text.
    private static let lastBundledFile = Paths.support.appendingPathComponent("playbook.bundled.md")

    /// First launch copies the bundled playbook somewhere you can edit it. Later app versions bring
    /// new or corrected entries in, but never overwrite an entry you've changed yourself.
    static func ensureUserCopy() {
        guard let bundledURL = bundledURL(), let bundled = try? String(contentsOf: bundledURL, encoding: .utf8) else { return }
        defer { try? bundled.write(to: lastBundledFile, atomically: true, encoding: .utf8) }
        guard let user = try? String(contentsOf: userFile, encoding: .utf8) else {
            try? bundled.write(to: userFile, atomically: true, encoding: .utf8)
            return
        }
        let previous = (try? String(contentsOf: lastBundledFile, encoding: .utf8)) ?? user
        let merged = merge(user: user, previous: previous, bundled: bundled)
        if merged != user { try? merged.write(to: userFile, atomically: true, encoding: .utf8) }
    }

    /// Entry blocks keyed by id, with the section they sit in.
    private static func blocks(_ text: String) -> [(section: String, id: String, body: String)] {
        var out: [(String, String, String)] = []
        var section = ""
        var id: String?
        var lines: [String] = []
        func flush() { if let id { out.append((section, id, lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))) } }
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("## ") { flush(); id = nil; lines = []; section = line }
            else if line.hasPrefix("### ") { flush(); id = String(line.dropFirst(4)); lines = [line] }
            else if id != nil { lines.append(line) }
        }
        flush()
        return out
    }

    static func merge(user: String, previous: String, bundled: String) -> String {
        var result = user
        let userList = blocks(user)
        let userBlocks = Dictionary(userList.map { ($0.id, $0.body) }, uniquingKeysWith: { a, _ in a })
        let userSections = Dictionary(userList.map { ($0.id, $0.section) }, uniquingKeysWith: { a, _ in a })
        let previousBlocks = Dictionary(blocks(previous).map { ($0.id, $0.body) }, uniquingKeysWith: { a, _ in a })
        for b in blocks(bundled) {
            if let mine = userBlocks[b.id] {
                let unedited = mine == previousBlocks[b.id]
                if unedited && userSections[b.id] != b.section {
                    // The entry moved section (for example into House practices): move it too.
                    result = result.replacingOccurrences(of: mine, with: "")
                    result = insert(b, into: result)
                } else if unedited, mine != b.body {
                    // Unedited since the last version you received: take the new wording.
                    result = result.replacingOccurrences(of: mine, with: b.body)
                }
                continue
            }
            result = insert(b, into: result)
        }
        while result.contains("\n\n\n") { result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return result
    }

    private static func insert(_ b: (section: String, id: String, body: String), into text: String) -> String {
        var result = text
        do {
            if let range = result.range(of: b.section + "\n") {
                // Add it at the end of its section.
                let after = result[range.upperBound...]
                let end = after.range(of: "\n## ").map { $0.lowerBound } ?? result.endIndex
                result.insert(contentsOf: "\n" + b.body + "\n", at: end)
            } else {
                result += "\n" + b.section + "\n\n" + b.body + "\n"
            }
        }
        return result
    }

    private static func bundledURL() -> URL? {
        if let url = Bundle.main.url(forResource: "playbook", withExtension: "md") { return url }
        // Debug builds run outside the .app bundle; fall back to the copy in the repo.
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("playbook.md")
        return FileManager.default.fileExists(atPath: repo.path) ? repo : nil
    }

    /// Reads "## Section" headings and "### id" entries with **Rule/Why/Source/Checked** lines.
    static func parse(_ text: String) -> [PlaybookEntry] {
        var entries: [PlaybookEntry] = []
        var skill: Skill?
        var current: [String: String] = [:]
        var id: String?

        func flush() {
            guard let id, let skill, let rule = current["Rule"] else { return }
            let checked = current["Checked"] ?? ""
            let url = checked.range(of: #"https?://\S+"#, options: .regularExpression)
                .flatMap { URL(string: String(checked[$0]).trimmingCharacters(in: CharacterSet(charactersIn: ").,"))) }
            entries.append(PlaybookEntry(id: id, skill: skill, rule: rule, why: current["Why"] ?? "",
                                         source: current["Source"] ?? "Common practice", checked: checked, url: url))
        }

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("### ") {
                flush()
                id = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                current = [:]
            } else if line.hasPrefix("## ") {
                flush()
                id = nil
                current = [:]
                skill = Skill.from(playbookSection: String(line.dropFirst(3)))
            } else if line.hasPrefix("**"), let close = line.range(of: ":**") {
                let key = String(line[line.index(line.startIndex, offsetBy: 2)..<close.lowerBound])
                current[key] = String(line[close.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        flush()
        return entries
    }
}
