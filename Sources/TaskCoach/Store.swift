import Foundation
import Security

struct AppState: Codable {
    var skillStats: [String: SkillStat] = [:]
    /// sessionId -> assistant turn count when we last nudged/quizzed on it.
    var seenTurns: [String: Int] = [:]
    var readyQuizzes: [String: Quiz] = [:]
    var initialised = false
    var lastDailyRun: Date?

    var nudgeAfterSessions = true
    var dailyRecap = true
    var dailyHour = 17
    var model = "sonnet"
    var claudePathOverride: String?
    var lookbackDays = 7

    var showInMenuBar = true
    var showInDock = true

    var reviews: [ReviewItem] = []
    /// Right/wrong tallies per confidence level, for the calibration view.
    var calibration: [String: SkillStat] = [:]
    var questionsPerSitting = 3
    /// "system", "light" or "dark".
    var appearance = "system"
    /// Optional: what you work on, so questions use the right vocabulary.
    var workContext = ""
    var lastNudge: Date?

    var knownCold: [KnownItem] = []
    var history: [AnswerRecord] = []
    var milestones: [String: Date] = [:]
}

extension AppState {
    // Hand-written so a state.json from an older version (missing newer keys) still loads,
    // instead of failing and wiping skill progress.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ key: CodingKeys, _ current: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? current
        }
        // Older saves use the eight-skill names; fold them into the SDLC skills.
        for (key, stat) in read(.skillStats, skillStats) {
            guard let skill = Skill.migrate(key) else { continue }
            var merged = skillStats[skill.rawValue] ?? SkillStat()
            merged.attempts += stat.attempts
            merged.points += stat.points
            merged.maxPoints += stat.maxPoints
            skillStats[skill.rawValue] = merged
        }
        seenTurns = read(.seenTurns, seenTurns)
        readyQuizzes = read(.readyQuizzes, readyQuizzes)
        initialised = read(.initialised, initialised)
        lastDailyRun = read(.lastDailyRun, lastDailyRun)
        nudgeAfterSessions = read(.nudgeAfterSessions, nudgeAfterSessions)
        dailyRecap = read(.dailyRecap, dailyRecap)
        dailyHour = read(.dailyHour, dailyHour)
        model = read(.model, model)
        claudePathOverride = read(.claudePathOverride, claudePathOverride)
        lookbackDays = read(.lookbackDays, lookbackDays)
        showInMenuBar = read(.showInMenuBar, showInMenuBar)
        showInDock = read(.showInDock, showInDock)
        reviews = read(.reviews, reviews)
        calibration = read(.calibration, calibration)
        questionsPerSitting = read(.questionsPerSitting, questionsPerSitting)
        appearance = read(.appearance, appearance)
        workContext = read(.workContext, workContext)
        lastNudge = read(.lastNudge, lastNudge)
        knownCold = read(.knownCold, knownCold)
        history = read(.history, history)
        milestones = read(.milestones, milestones)
    }
}

enum Paths {
    static let support: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("TaskCoach", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Neutral working directory for claude runs, so no project CLAUDE.md or hooks load.
    static let work: URL = {
        let dir = support.appendingPathComponent("work", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let stateFile = support.appendingPathComponent("state.json")
    static let claudeProjects = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects", isDirectory: true)
}

enum StateStore {
    static func load() -> AppState {
        guard let data = try? Data(contentsOf: Paths.stateFile) else { return AppState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(AppState.self, from: data)) ?? AppState()
    }

    static func save(_ state: AppState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(state) {
            try? data.write(to: Paths.stateFile, options: .atomic)
        }
    }
}

/// The Linear API key lives in the login keychain, never in state.json.
enum Keychain {
    private static let service = "TaskCoach.linear-api-key"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        let value = String(data: data, encoding: .utf8)
        return (value?.isEmpty ?? true) ? nil : value
    }

    static func write(_ value: String?) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(base as CFDictionary)
        guard let value, !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}
