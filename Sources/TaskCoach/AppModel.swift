import Foundation
import SwiftUI
import ServiceManagement
import UserNotifications

enum Screen: Equatable, Hashable {
    case tasks, skills, history, settings
    case quiz(UUID)
}

/// Where one surface (menu bar popover or main window) is looking. Each surface has its own,
/// so starting a quiz in the window doesn't take over the popover.
@MainActor
final class Navigator: ObservableObject {
    @Published var screen: Screen = .tasks
    @Published var activeQuiz: Quiz?

    func open(_ quiz: Quiz) {
        activeQuiz = quiz
        screen = .quiz(quiz.id)
    }

    func close() {
        activeQuiz = nil
        screen = .tasks
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var state: AppState
    @Published var tasks: [TaskItem] = []
    @Published var generating: Set<String> = []
    @Published var lastError: String?
    @Published var linearStatus: String?
    @Published var scanning = false
    @Published var opensAtLogin = false
    @Published var loginNeedsApproval = false
    @Published var playbook: [PlaybookEntry] = []

    /// Lets the status item swap to a filled icon when a quiz is waiting.
    var onReadyChange: ((Bool) -> Void)?

    private let scanner = SessionScanner()
    private var linearIssues: [LinearIssue] = []
    private var timer: Timer?

    /// A session counts as "finished" once it has been quiet this long.
    private let idleThreshold: TimeInterval = 10 * 60
    /// And it only earns a nudge if it did real work since the last one.
    private let minNewTurns = 15

    /// Preview models (used by the snapshot renderer) never touch disk.
    private let isPreview: Bool

    init(state: AppState? = nil, tasks: [TaskItem] = []) {
        self.isPreview = state != nil
        self.state = state ?? StateStore.load()
        self.tasks = tasks
        QuizEngine.workContext = self.state.workContext
        // Clean up duplicate cards saved before duplicates were prevented.
        var seen = Set<String>()
        self.state.knownCold.removeAll { !seen.insert($0.text.lowercased()).inserted }
        if !isPreview {
            refreshLoginStatus()
            playbook = Playbook.load()
        }
    }

    // MARK: Open at login

    func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        opensAtLogin = status == .enabled || status == .requiresApproval
        loginNeedsApproval = status == .requiresApproval
    }

    func setOpensAtLogin(_ on: Bool) {
        guard !isPreview else { return }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            lastError = "Couldn't change Open at login: \(error.localizedDescription)"
        }
        refreshLoginStatus()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func start() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func persist() {
        QuizEngine.workContext = state.workContext
        if !isPreview { StateStore.save(state) }
        onReadyChange?(!state.readyQuizzes.isEmpty)
    }

    var claudePath: String? { ClaudeRunner.locate(override: state.claudePathOverride) }

    /// One-line status shown under the app name.
    var headline: String {
        let ready = state.readyQuizzes.count
        let due = dueReviews.count
        if due > 0 { return "\(due) due for review" }
        if ready > 0 { return "\(ready) quiz\(ready == 1 ? "" : "zes") waiting for you" }
        let tickets = tasks.filter { $0.ticketId != nil }.count
        return tickets == 0 ? "Nothing to quiz yet" : "\(tickets) tickets in the last \(state.lookbackDays) days"
    }

    // MARK: Loading tasks

    func refresh() async {
        scanning = true
        defer { scanning = false }
        if let key = Keychain.read() {
            do {
                linearIssues = try await LinearClient.fetchAssigned(apiKey: key)
                linearStatus = "Linear: \(linearIssues.count) assigned tickets"
            } catch {
                linearStatus = "Linear: \(error.localizedDescription)"
            }
        } else {
            linearStatus = nil
            linearIssues = []
        }
        let lookback = state.lookbackDays
        let scanner = self.scanner
        let sessions = await Task.detached { scanner.scan(lookbackDays: lookback) }.value
        tasks = SessionScanner.group(sessions, linear: linearIssues)
        pruneStale()

        if !state.initialised {
            // First launch: treat everything that already exists as seen, so we don't
            // fire a pile of nudges about last week.
            for s in sessions { state.seenTurns[s.id] = s.assistantTurns }
            state.initialised = true
            persist()
        }
        onReadyChange?(!state.readyQuizzes.isEmpty)
    }

    private func tick() async {
        await refresh()
        if state.nudgeAfterSessions { nudgeForFinishedSessions() }
        if state.dailyRecap { await runDailyPulseIfDue() }
    }

    /// Unopened quizzes go stale; after a day they're about old work, so drop them.
    private func pruneStale() {
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        let before = state.readyQuizzes.count
        state.readyQuizzes = state.readyQuizzes.filter { $0.value.createdAt > cutoff }
        if state.readyQuizzes.count != before { persist() }
    }

    /// Nudges no longer write a quiz up front (unopened ones piled up). The notification just
    /// offers one; clicking it writes it then.
    private func nudgeForFinishedSessions() {
        let now = Date()
        // One session nudge a day at most; repeated nudges lose their effect.
        if let last = state.lastNudge, Calendar.current.isDate(last, inSameDayAs: now) { return }
        for task in tasks {
            for s in task.sessions {
                let quietFor = now.timeIntervalSince(s.lastModified)
                let newTurns = s.assistantTurns - (state.seenTurns[s.id] ?? 0)
                guard quietFor > idleThreshold, quietFor < 6 * 3600, newTurns >= minNewTurns else { continue }
                state.seenTurns[s.id] = s.assistantTurns
                state.lastNudge = now
                persist()
                notify(title: "\(task.ticketId ?? "Session") wrapped up",
                       body: "\(state.questionsPerSitting) quick questions on \(task.title) to lock it in?",
                       info: ["taskKey": task.key])
                return  // one nudge at a time
            }
        }
    }

    /// Once a day: a single question, ideally a review that's due (no Claude call needed).
    private func runDailyPulseIfDue() async {
        let cal = Calendar.current
        let now = Date()
        guard cal.component(.hour, from: now) >= state.dailyHour else { return }
        if let last = state.lastDailyRun, cal.isDate(last, inSameDayAs: now) { return }
        state.lastDailyRun = now
        persist()
        guard let quiz = await pulseQuiz() else { return }
        state.readyQuizzes[quiz.taskKey] = quiz
        persist()
        notify(title: "One question for today", body: String(quiz.questions[0].prompt.prefix(160)),
               info: ["quizKey": quiz.taskKey])
    }

    private func pulseQuiz() async -> Quiz? {
        if let item = dueReviews.first {
            var q = item.question
            q.reviewId = item.id
            return Quiz(taskKey: "pulse", title: "Daily pulse · review", summary: "", questions: [q])
        }
        let now = Date()
        guard let recent = tasks.first(where: { now.timeIntervalSince($0.lastActivity) < 36 * 3600 }) else { return nil }
        return await build(tasks: [recent], recap: false, count: 1, key: "pulse",
                           title: "Daily pulse · \(recent.ticketId ?? recent.title)")
    }

    // MARK: Quizzes

    var weakSkills: [Skill] {
        // Untested skills count as weak so they get some airtime.
        Skill.allCases
            .map { ($0, state.skillStats[$0.rawValue]?.ratio ?? 0.4) }
            .sorted { $0.1 < $1.1 }
            .prefix(3)
            .map(\.0)
    }

    @discardableResult
    /// Writes one chain of 3 by default: output is the costliest part of a quiz, and most sittings
    /// stop after 3. "3 more" writes the next chain on demand.
    func build(tasks: [TaskItem], recap: Bool, count: Int = 3, key: String? = nil, title: String? = nil,
               avoid: [String] = [], focus: Skill? = nil) async -> Quiz? {
        let busyKey = key ?? (recap ? "daily" : (tasks.first?.key ?? ""))
        generating.insert(busyKey)
        defer { generating.remove(busyKey) }
        lastError = nil

        // Offer Claude due reviews from these tasks first, then any others that are due.
        let keys = Set(tasks.map(\.key))
        let due = dueReviews
        let review = Array((due.filter { keys.contains($0.taskKey) } + due.filter { !keys.contains($0.taskKey) }).prefix(3))
        do {
            let quiz = try await QuizEngine.generate(tasks: tasks, weakSkills: weakSkills, review: review, recap: recap,
                                                     count: count, key: key, title: title, playbook: playbook, avoid: avoid,
                                                     focus: focus,
                                                     model: state.model, claudePath: state.claudePathOverride)
            state.readyQuizzes[quiz.taskKey] = quiz
            persist()
            return quiz
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Returns the waiting quiz for this task, or writes a new one.
    func quiz(for task: TaskItem) async -> Quiz? {
        if let ready = state.readyQuizzes[task.key] { return ready }
        return await build(tasks: [task], recap: false)
    }

    func quiz(forTaskKey key: String) async -> Quiz? {
        guard let task = tasks.first(where: { $0.key == key }) else { return nil }
        return await quiz(for: task)
    }

    func dailyRecap() async -> Quiz? {
        let recent = Array(tasks.prefix(3))
        guard !recent.isEmpty else { return nil }
        return await build(tasks: recent, recap: true)
    }

    func readyQuiz(key: String) -> Quiz? { state.readyQuizzes[key] }

    /// Three questions on one skill, using your most recent work where it fits.
    func practise(_ skill: Skill, avoid: [String] = []) async -> Quiz? {
        await build(tasks: Array(tasks.prefix(3)), recap: true, count: 3, key: "skill:\(skill.rawValue)",
                    title: "Practise · \(skill.title)", avoid: avoid, focus: skill)
    }

    static func focusSkill(of quiz: Quiz) -> Skill? {
        quiz.taskKey.hasPrefix("skill:") ? Skill(rawValue: String(quiz.taskKey.dropFirst(6))) : nil
    }

    /// Due review questions for one skill: instant, no Claude call.
    func dueReviews(for skill: Skill) -> [ReviewItem] { dueReviews.filter { $0.question.skill == skill } }

    func reviewQuiz(for skill: Skill) -> Quiz? {
        let items = dueReviews(for: skill).prefix(5)
        guard !items.isEmpty else { return nil }
        let questions = items.map { item -> Question in
            var q = item.question
            q.reviewId = item.id
            return q
        }
        return Quiz(taskKey: "review", title: "Review · \(skill.title)", summary: "", questions: questions)
    }

    /// Whether "3 more" makes sense: not for the pulse or the review queue, which aren't about one piece of work.
    func canContinue(_ quiz: Quiz) -> Bool { quiz.taskKey != "pulse" && quiz.taskKey != "review" }

    /// The next chain on the same work, steering away from practices already covered.
    func moreQuestions(after quiz: Quiz) async -> Quiz? {
        // Practices taught and ticket questions asked so far, so the next chain covers new ground.
        let avoid = quiz.questions.compactMap(\.practiceId)
            + quiz.questions.filter { $0.role == "ticket" }.map { "asked: \($0.prompt)" }
            + (quiz.coveredPractices ?? [])
        let next: Quiz?
        if let skill = Self.focusSkill(of: quiz) {
            next = await practise(skill, avoid: avoid)
        } else if quiz.taskKey == "daily" {
            next = await build(tasks: Array(tasks.prefix(3)), recap: true, avoid: avoid)
        } else if let task = tasks.first(where: { $0.key == quiz.taskKey }) {
            next = await build(tasks: [task], recap: false, avoid: avoid)
        } else {
            return nil
        }
        guard var q = next else { return nil }
        q.coveredPractices = Array(Set(avoid))
        state.readyQuizzes[q.taskKey] = q
        persist()
        return q
    }

    /// Ends a sitting after `answered` questions. Unanswered ones stay ready to pick up later.
    func finish(quiz: Quiz, answered: Int) {
        // The review "quiz" is rebuilt from whatever is due each time, so there's nothing to keep.
        if quiz.taskKey != "review", answered < quiz.questions.count {
            var rest = quiz
            rest.questions = Array(quiz.questions.dropFirst(answered))
            state.readyQuizzes[quiz.taskKey] = rest
        } else {
            state.readyQuizzes.removeValue(forKey: quiz.taskKey)
        }
        persist()
    }

    // MARK: Review queue

    var dueReviews: [ReviewItem] {
        let now = Date()
        // Confident mistakes first, then oldest due.
        return state.reviews.filter { $0.due <= now }
            .sorted { ($0.confidentError ? 0 : 1, $0.due) < ($1.confidentError ? 0 : 1, $1.due) }
    }

    func reviewQuiz() -> Quiz? {
        let items = dueReviews.prefix(5)
        guard !items.isEmpty else { return nil }
        let questions = items.map { item -> Question in
            var q = item.question
            q.reviewId = item.id
            return q
        }
        return Quiz(taskKey: "review", title: "Review", summary: "", questions: questions)
    }

    @discardableResult
    func record(question: Question, points: Int, confidence: Confidence, taskKey: String,
                yourAnswer: String = "", verdict: String? = nil, feedback: String? = nil) -> AnswerOutcome {
        state.history.insert(AnswerRecord(taskKey: taskKey, question: question, yourAnswer: yourAnswer, points: points,
                                          confidence: confidence, verdict: verdict, feedback: feedback), at: 0)
        if state.history.count > AnswerRecord.keep { state.history.removeLast(state.history.count - AnswerRecord.keep) }
        let skill = question.skill
        var outcome = AnswerOutcome(skill: skill)
        outcome.chapterBefore = Chapter.level(known: knownCount(skill))

        var stat = state.skillStats[skill.rawValue] ?? SkillStat()
        stat.attempts += 1
        stat.points += points
        stat.maxPoints += 2
        state.skillStats[skill.rawValue] = stat

        var cal = state.calibration[confidence.rawValue] ?? SkillStat()
        cal.attempts += 1
        cal.points += points
        cal.maxPoints += 2
        state.calibration[confidence.rawValue] = cal

        let now = Date()
        let day: TimeInterval = 86_400
        let confidentError = points < 2 && confidence == .certain
        var retired = false
        var fixedConfidentError = false

        if let rid = question.reviewId, let i = state.reviews.firstIndex(where: { $0.id == rid }) {
            if points == 2 {
                fixedConfidentError = state.reviews[i].confidentError
                state.reviews[i].streak += 1
                state.reviews[i].confidentError = false
                if state.reviews[i].streak >= ReviewItem.retireAfter {
                    state.reviews.remove(at: i)
                    retired = true
                } else {
                    let gap = ReviewItem.gapsInDays[min(state.reviews[i].streak, ReviewItem.gapsInDays.count - 1)]
                    state.reviews[i].due = now.addingTimeInterval(gap * day)
                }
            } else {
                state.reviews[i].streak = 0
                state.reviews[i].confidentError = confidentError
                state.reviews[i].due = confidentError ? now : now.addingTimeInterval(day)
            }
        } else if points < 2 || confidence == .guessing {
            // Wrong, or right by luck: both come back. Confident mistakes are due straight away.
            var q = question
            q.reviewId = nil
            state.reviews.append(ReviewItem(taskKey: taskKey, question: q, due: confidentError ? now : now.addingTimeInterval(day),
                                            confidentError: confidentError))
            if state.reviews.count > 60 { state.reviews.removeFirst(state.reviews.count - 60) }
        }

        // Known cold: right and sure on a first ask, or a review item retired after three recalls.
        let firstAskKnown = question.reviewId == nil && points == 2 && confidence != .guessing
        if firstAskKnown || retired {
            // Practice questions put the playbook rule itself on the shelf, so it becomes your playbook.
            let text = practice(for: question)?.rule ?? Self.takeaway(of: question)
            // The same lesson often comes up twice; one card on the shelf is enough.
            if !state.knownCold.contains(where: { $0.text.caseInsensitiveCompare(text) == .orderedSame }) {
                state.knownCold.append(KnownItem(skill: skill, text: text, taskKey: taskKey))
            }
            outcome.becameKnown = true
        }
        outcome.known = knownCount(skill)
        outcome.chapterAfter = Chapter.level(known: outcome.known)

        var earned: [Milestone] = []
        if outcome.becameKnown { earned.append(.firstKnown) }
        if fixedConfidentError { earned.append(.confidentFix) }
        if retired { earned.append(.firstRetired) }
        if Skill.allCases.allSatisfy({ (state.skillStats[$0.rawValue]?.attempts ?? 0) > 0 }) { earned.append(.allTested) }
        if state.knownCold.count >= 10 { earned.append(.known10) }
        if state.knownCold.count >= 25 { earned.append(.known25) }
        if outcome.chapterAfter >= 3 { earned.append(.chapterThree) }
        if let certain = state.calibration[Confidence.certain.rawValue], certain.attempts >= 10, (certain.ratio ?? 0) >= 0.9 {
            earned.append(.calibrated)
        }
        for m in earned where state.milestones[m.rawValue] == nil {
            state.milestones[m.rawValue] = now
            outcome.newMilestones.append(m)
        }

        persist()
        return outcome
    }

    /// "This answer is wrong": undo what the answer recorded, drop it from the review queue and
    /// shelf, and keep a note so bad questions can be looked at later.
    func reportWrong(question: Question, points: Int?, confidence: Confidence?, outcome: AnswerOutcome?, taskKey: String) {
        if let points {
            var stat = state.skillStats[question.skill.rawValue] ?? SkillStat()
            stat.attempts = max(0, stat.attempts - 1)
            stat.points = max(0, stat.points - points)
            stat.maxPoints = max(0, stat.maxPoints - 2)
            state.skillStats[question.skill.rawValue] = stat
            if let c = confidence, var cal = state.calibration[c.rawValue] {
                cal.attempts = max(0, cal.attempts - 1)
                cal.points = max(0, cal.points - points)
                cal.maxPoints = max(0, cal.maxPoints - 2)
                state.calibration[c.rawValue] = cal
            }
        }
        state.reviews.removeAll { $0.question.prompt == question.prompt || $0.id == question.reviewId }
        if let i = state.history.firstIndex(where: { $0.question.prompt == question.prompt }) { state.history[i].reported = true }
        if outcome?.becameKnown == true {
            let text = practice(for: question)?.rule ?? Self.takeaway(of: question)
            if let i = state.knownCold.lastIndex(where: { $0.text == text }) { state.knownCold.remove(at: i) }
        }
        let report: [String: Any] = [
            "at": ISO8601DateFormatter().string(from: Date()), "taskKey": taskKey, "prompt": question.prompt,
            "context": question.context ?? "", "evidence": question.evidence ?? "",
            "markedCorrect": question.choices.flatMap { c in question.answerIndex.map { c[$0] } } ?? question.modelAnswer ?? "",
        ]
        if var line = try? JSONSerialization.data(withJSONObject: report) {
            line.append(0x0A)
            let file = Paths.support.appendingPathComponent("wrong-answers.jsonl")
            if let h = try? FileHandle(forWritingTo: file) { h.seekToEndOfFile(); h.write(line); try? h.close() }
            else { try? line.write(to: file) }
        }
        persist()
    }

    func practice(for question: Question) -> PlaybookEntry? {
        question.practiceId.flatMap { id in playbook.first { $0.id == id } }
    }

    func reloadPlaybook() { playbook = Playbook.load() }

    func knownCount(_ skill: Skill) -> Int { state.knownCold.filter { $0.skill == skill }.count }

    /// The latest milestone, if it's recent enough to still be worth a stamp on the home page.
    var recentMilestone: Milestone? {
        let week = Date().addingTimeInterval(-7 * 86_400)
        return state.milestones
            .filter { $0.value > week }
            .max { $0.value < $1.value }
            .flatMap { Milestone(rawValue: $0.key) }
    }

    /// What goes on the index card: the question's takeaway, or failing that the question itself.
    static func takeaway(of question: Question) -> String {
        if let r = question.explanation.range(of: "Junior tip:", options: .caseInsensitive) {
            var tip = question.explanation[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if let first = tip.first { tip = first.uppercased() + tip.dropFirst() }
            if !tip.isEmpty { return tip }
        }
        return question.prompt
    }

    func grade(question: Question, answer: String) async throws -> Grade {
        try await QuizEngine.grade(question: question, answer: answer, practice: practice(for: question), model: state.model,
                                   claudePath: state.claudePathOverride)
    }

    // MARK: Notifications

    private func notify(title: String, body: String, info: [String: String]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = info
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Settings

    func saveLinearKey(_ key: String) async {
        Keychain.write(key.trimmingCharacters(in: .whitespacesAndNewlines))
        await refresh()
    }

    func resetProgress() {
        state.skillStats = [:]
        state.calibration = [:]
        state.reviews = []
        state.knownCold = []
        state.milestones = [:]
        persist()
    }
}
