import Foundation

/// The nine SDLC skills. Each quiz question trains one of them.
enum Skill: String, Codable, CaseIterable, Identifiable {
    case scoping
    case design
    case systemDesign = "systems"
    case readingCode = "reading_code"
    case testing
    case codeReview = "code_review"
    case shipping
    case operating
    case debugging
    case explaining

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scoping: return "Scoping the problem"
        case .design: return "Design and trade-offs"
        case .systemDesign: return "System design"
        case .readingCode: return "Reading code"
        case .testing: return "Testing"
        case .codeReview: return "Code review"
        case .shipping: return "Shipping safely"
        case .operating: return "Operating and incidents"
        case .debugging: return "Debugging"
        case .explaining: return "Explaining your work"
        }
    }

    var blurb: String {
        switch self {
        case .scoping: return "What's really being asked, and what done looks like"
        case .design: return "Options, trade-offs, and clean code structure"
        case .systemDesign: return "Scaling, failure and data across services"
        case .readingCode: return "Tracing what the code actually does"
        case .testing: return "What's worth testing, which edge case bites"
        case .codeReview: return "Spotting what's missing from a diff"
        case .shipping: return "Rollout, rollback, and what else it touches"
        case .operating: return "Signals, alerts, and handling incidents"
        case .debugging: return "Finding the cause, not the symptom"
        case .explaining: return "Saying it clearly to your lead"
        }
    }

    var symbol: String {
        switch self {
        case .scoping: return "scope"
        case .design: return "square.stack.3d.up"
        case .systemDesign: return "server.rack"
        case .readingCode: return "doc.text.magnifyingglass"
        case .testing: return "checkmark.seal"
        case .codeReview: return "eye"
        case .shipping: return "shippingbox"
        case .operating: return "waveform.path.ecg"
        case .debugging: return "ant"
        case .explaining: return "bubble.left.and.text.bubble.right"
        }
    }

    /// Maps the old eight-skill names onto the SDLC ones, so saved progress carries over.
    /// "domain" (company know-how) is retired; it maps to scoping, its nearest general skill.
    static func migrate(_ raw: String) -> Skill? {
        switch raw {
        case "system_design": return .design
        case "risk": return .shipping
        case "domain": return .scoping
        default: return Skill(rawValue: raw)
        }
    }

    /// The playbook's section titles, so entries can be matched to a skill.
    static func from(playbookSection title: String) -> Skill? {
        let t = title.lowercased()
        if t.hasPrefix("scoping") { return .scoping }
        if t.hasPrefix("system design") { return .systemDesign }
        if t.hasPrefix("design") { return .design }
        if t.hasPrefix("reading") { return .readingCode }
        if t.hasPrefix("testing") { return .testing }
        if t.hasPrefix("code review") { return .codeReview }
        if t.hasPrefix("shipping") { return .shipping }
        if t.hasPrefix("operating") { return .operating }
        if t.hasPrefix("debugging") { return .debugging }
        if t.hasPrefix("explaining") { return .explaining }
        return nil
    }

    // Claude occasionally invents a skill name, and older saves use the old names.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Skill.migrate(raw) ?? .readingCode
    }
}

struct DiagramNode: Codable, Hashable {
    var id: String
    var label: String
    var col: Int
    var row: Int
    var highlight: Bool?
}

struct DiagramEdge: Codable, Hashable {
    var from: String
    var to: String
    var label: String?
    /// "solid", "dashed" or "missing" (drawn red with a question mark).
    var style: String?
}

struct Diagram: Codable, Hashable {
    var caption: String?
    var nodes: [DiagramNode]
    var edges: [DiagramEdge]
}

enum QuestionKind: String, Codable {
    case choice, explain, diagram

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = QuestionKind(rawValue: raw) ?? .choice
    }
}

struct Question: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: QuestionKind
    var skill: Skill
    /// One plain sentence that sets the scene (what the work is, which part this asks about)
    /// without giving the answer away.
    var context: String?
    var prompt: String
    /// For explain questions: 2-3 short "aim to cover" points. Directions, not answers.
    var guide: [String]?
    var choices: [String]?
    var answerIndex: Int?
    var modelAnswer: String?
    var explanation: String
    var diagram: Diagram?
    var feedbackDiagram: Diagram?
    /// "ticket" (about your own work), "practice" (name the general practice) or "transfer"
    /// (the same practice in an unrelated scenario).
    var role: String?
    /// The playbook entry a practice or transfer question is built on.
    var practiceId: String?
    /// A quote from the session that proves the answer. The app checks it really appears there.
    var evidence: String?
    /// Set by Claude when this question re-tests a review item (its number in the prompt's list).
    var reviewOf: Int?
    /// Links the question back to the review item it re-tests, so the answer moves that item's schedule.
    var reviewId: UUID?

    enum CodingKeys: String, CodingKey {
        case kind, skill, context, prompt, guide, choices, answerIndex, modelAnswer, explanation, diagram, feedbackDiagram,
             reviewOf, reviewId, role, practiceId, evidence
    }

    /// Diagram and choice questions are both answered by picking an option.
    var isMultipleChoice: Bool { kind != .explain && !(choices ?? []).isEmpty }
}

struct Quiz: Codable, Identifiable, Hashable {
    var id = UUID()
    var taskKey: String
    var title: String
    var summary: String
    var questions: [Question]
    var createdAt = Date()
    /// Practices earlier chains on this work already taught, so "3 more" picks new ones.
    var coveredPractices: [String]?

    enum CodingKeys: String, CodingKey {
        case id, taskKey, title, summary, questions, createdAt, coveredPractices
    }
}

/// The JSON shape Claude returns for a quiz.
struct GeneratedQuiz: Codable {
    var summary: String
    var questions: [Question]
}

struct Grade: Codable, Hashable {
    var score: Int
    var verdict: String
    var feedback: String
    var feedbackDiagram: Diagram?
}

struct SessionInfo: Hashable {
    var id: String
    var path: URL
    var title: String
    var branch: String?
    var lastModified: Date
    var assistantTurns: Int
    var ticketIds: [String]
    var branchTicketCandidate: String?
}

struct LinearIssue: Codable, Hashable {
    var identifier: String
    var title: String
    var description: String?
    var url: String?
    var stateName: String?
    var comments: [String]
}

struct TaskItem: Identifiable, Hashable {
    var key: String
    var ticketId: String?
    var title: String
    var sessions: [SessionInfo]
    var lastActivity: Date
    var linear: LinearIssue?

    var id: String { key }
}

struct SkillStat: Codable {
    var attempts = 0
    var points = 0
    var maxPoints = 0

    var ratio: Double? { maxPoints == 0 ? nil : Double(points) / Double(maxPoints) }
}

enum Confidence: String, Codable, CaseIterable, Identifiable {
    case guessing
    case fairlySure = "fairly_sure"
    case certain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guessing: return "Guessing"
        case .fairlySure: return "Fairly sure"
        case .certain: return "Certain"
        }
    }

    var symbol: String {
        switch self {
        case .guessing: return "questionmark"
        case .fairlySure: return "hand.thumbsup"
        case .certain: return "checkmark.seal"
        }
    }
}

/// A question that comes back later. It retires after three correct recalls, spaced 1, 3 and 7
/// days apart; a wrong answer resets it. (Repeated spaced retrieval beats asking once; growing
/// gaps aren't proven better than even ones, so the schedule is kept simple.)
struct ReviewItem: Codable, Identifiable {
    var id = UUID()
    var taskKey: String
    var question: Question
    var streak = 0
    var due: Date
    /// Answered wrong while "certain". These come back first.
    var confidentError = false
    var added = Date()

    static let gapsInDays: [Double] = [1, 3, 7]
    static let retireAfter = 3
}

// MARK: - Game layer (mastery-based: no points, no streaks)

/// Something you've shown you know: answered right and sure on first ask, or a review item
/// retired after three spaced recalls. These fill the shelf and move skills up a chapter.
struct KnownItem: Codable, Identifiable {
    var id = UUID()
    var skill: Skill
    var text: String
    var taskKey: String
    var date = Date()
}

/// Chapters I to V per skill, earned by things known cold in that skill.
enum Chapter {
    static let thresholds = [0, 3, 7, 12, 20]  // known items needed for I, II, III, IV, V

    static func level(known: Int) -> Int {
        (thresholds.lastIndex { known >= $0 } ?? 0) + 1
    }

    /// 0...1 progress from this chapter to the next (1 at chapter V).
    static func progress(known: Int) -> Double {
        let lv = level(known: known)
        guard lv < 5 else { return 1 }
        let lo = thresholds[lv - 1], hi = thresholds[lv]
        return Double(known - lo) / Double(hi - lo)
    }

    static func toNext(known: Int) -> Int? {
        let lv = level(known: known)
        return lv < 5 ? thresholds[lv] - known : nil
    }
}

/// Milestones for learning moves, never for just turning up.
enum Milestone: String, CaseIterable {
    case firstKnown = "first_known"
    case confidentFix = "confident_fix"
    case firstRetired = "first_retired"
    case allTested = "all_tested"
    case known10 = "known_10"
    case chapterThree = "chapter_three"
    case calibrated = "calibrated"
    case known25 = "known_25"

    var title: String {
        switch self {
        case .firstKnown: return "First thing known cold"
        case .confidentFix: return "Fixed a mistake you were sure about"
        case .firstRetired: return "First review item retired"
        case .allTested: return "Every skill tested"
        case .known10: return "Ten things known cold"
        case .chapterThree: return "A skill reached chapter III"
        case .calibrated: return "Your \"certain\" means certain"
        case .known25: return "Twenty-five things known cold"
        }
    }

    var detail: String {
        switch self {
        case .firstKnown: return "Answered right, and you knew you knew it."
        case .confidentFix: return "The mistakes you're surest about are the most worth fixing."
        case .firstRetired: return "Recalled three times, days apart. That one's yours now."
        case .allTested: return "All eight skills have been tried at least once."
        case .known10: return "Ten ideas you can now explain without notes."
        case .chapterThree: return "Halfway to mastering a skill."
        case .calibrated: return "Right at least 9 times in 10 when you say you're certain."
        case .known25: return "A real body of knowledge about your own work."
        }
    }
}

/// What an answer changed, so the quiz can say so in one line.
struct AnswerOutcome {
    var becameKnown = false
    var skill: Skill
    var chapterBefore = 1
    var chapterAfter = 1
    var newMilestones: [Milestone] = []
    var known = 0
}

/// One answered question, kept so you can look back at what you said and what was right.
struct AnswerRecord: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var taskKey: String
    var question: Question
    var yourAnswer: String
    var points: Int
    var confidence: Confidence
    var verdict: String?
    var feedback: String?
    var reported = false

    static let keep = 50
}
