import AppKit
import SwiftUI

/// `TaskCoach --snapshot <dir>` renders every screen with placeholder data to PNGs,
/// so the UI can be reviewed without clicking through the menu bar.
@MainActor
enum Snapshot {
    static func run(outDir: URL, quiz realQuiz: Quiz? = nil) {
        _ = NSApplication.shared
        HistoryView.openFirst = true
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        if let realQuiz {
            // Render each question of a real quiz, revealed, to check real content fits.
            for (i, q) in realQuiz.questions.enumerated() {
                let preset = q.isMultipleChoice ? QuestionPreset(pick: q.answerIndex, confidence: .fairlySure) : nil
                let view = QuizView(quiz: realQuiz, index: i, results: Array(repeating: 2, count: i), preset: preset)
                render(view.environmentObject(model()).environmentObject(Navigator()), size: NSSize(width: 440, height: 600), dark: false,
                       to: outDir.appendingPathComponent("real-q\(i + 1).png"))
            }
            print("Wrote real quiz snapshots to \(outDir.path)")
            return
        }
        // A skill page, rendered on its own before the main list.
        SkillsView.openForSnapshot = .debugging
        for dark in [false, true] {
            let nav = Navigator()
            nav.screen = .skills
            render(RootView(openWindow: {}).environmentObject(model()).environmentObject(nav),
                   size: NSSize(width: 440, height: 760), dark: dark,
                   to: outDir.appendingPathComponent("skill-detail\(dark ? "-dark" : "").png"))
        }
        SkillsView.openForSnapshot = nil

        let quiz = sampleQuiz
        let popover = NSSize(width: 440, height: 600)
        let window = NSSize(width: 980, height: 700)

        let screens: [(String, Screen, Quiz?, NSSize, AnyView)] = [
            ("window-tasks", .tasks, nil, window, AnyView(MainWindowView())),
            ("window-skills", .skills, nil, window, AnyView(MainWindowView())),
            ("window-skills-full", .skills, nil, NSSize(width: 980, height: 1250), AnyView(MainWindowView())),
            ("window-settings-full", .settings, nil, NSSize(width: 980, height: 1250), AnyView(MainWindowView())),
            ("window-settings", .settings, nil, window, AnyView(MainWindowView())),
            ("window-history", .history, nil, window, AnyView(MainWindowView())),
            ("history", .history, nil, popover, AnyView(RootView(openWindow: {}))),
            ("window-quiz", .tasks, quiz, window, AnyView(MainWindowView())),
            ("tasks", .tasks, nil, popover, AnyView(RootView(openWindow: {}))),
            ("skills", .skills, nil, popover, AnyView(RootView(openWindow: {}))),
            ("settings", .settings, nil, popover, AnyView(RootView(openWindow: {}))),
            ("quiz-diagram", .tasks, nil, popover, AnyView(QuizView(quiz: quiz, index: 0))),
            ("quiz-confidence", .tasks, nil, popover, AnyView(QuizView(quiz: quiz, index: 1, results: [2], preset: QuestionPreset(pick: 0)))),
            ("quiz-wrong-tall", .tasks, nil, NSSize(width: 440, height: 880), AnyView(QuizView(quiz: quiz, index: 1, results: [2], preset: QuestionPreset(pick: 0, confidence: .certain)))),
            ("quiz-right", .tasks, nil, NSSize(width: 440, height: 880), AnyView(QuizView(quiz: quiz, index: 1, results: [2], preset: QuestionPreset(pick: 1, confidence: .fairlySure,
                outcome: AnswerOutcome(becameKnown: true, skill: .debugging, chapterBefore: 1, chapterAfter: 1, newMilestones: [.firstKnown], known: 2))))),
            ("quiz-wrong", .tasks, nil, popover, AnyView(QuizView(quiz: quiz, index: 1, results: [2], preset: QuestionPreset(pick: 0, confidence: .certain)))),
            ("quiz-explain", .tasks, nil, popover, AnyView(QuizView(quiz: quiz, index: 2, results: [2, 0],
                                                       preset: QuestionPreset(answer: "Snoozing saved fine but nothing told the unread count to refresh, so it stayed stale.")))),
            ("quiz-graded", .tasks, nil, popover, AnyView(QuizView(quiz: quiz, index: 2, results: [2, 0],
                                                      preset: QuestionPreset(answer: "Snoozing saved fine but nothing told the unread count to refresh, so it stayed stale.",
                                                                             grade: sampleGrade, confidence: .fairlySure)))),
            ("quiz-paused", .tasks, nil, popover, AnyView(QuizView(quiz: quiz, index: 3, results: [2, 0, 1], phase: .paused))),
            ("finish", .tasks, nil, popover, AnyView(QuizView(quiz: quiz, index: 5, results: [2, 0, 1, 2, 2], phase: .done))),
        ]

        for dark in [false, true] {
            for (name, screen, openQuiz, size, view) in screens {
                let nav = Navigator()
                nav.screen = screen
                if let openQuiz { nav.open(openQuiz) }
                let url = outDir.appendingPathComponent("\(name)\(dark ? "-dark" : "").png")
                render(view.environmentObject(model()).environmentObject(nav), size: size, dark: dark, to: url)
            }
        }
        print("Wrote snapshots to \(outDir.path)")
    }

    /// `TaskCoach --page-shots <dir>`: the screenshots for the project page, at 2x so they're sharp.
    static func pageShots(outDir: URL) {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let window = NSSize(width: 980, height: 640)
        func shot<V: View>(_ name: String, _ view: V, _ size: NSSize, screen: Screen, quiz: Quiz? = nil, dark: Bool = false) {
            let nav = Navigator()
            nav.screen = screen
            if let quiz { nav.open(quiz) }
            let content = view.environmentObject(model()).environmentObject(nav)
                .frame(width: size.width, height: size.height)
                .scaleEffect(2, anchor: .topLeading)
                .frame(width: size.width * 2, height: size.height * 2, alignment: .topLeading)
            render(content, size: NSSize(width: size.width * 2, height: size.height * 2), dark: dark,
                   to: outDir.appendingPathComponent("\(name).png"))
        }
        shot("home", MainWindowView(), window, screen: .tasks)
        shot("home-dark", MainWindowView(), window, screen: .tasks, dark: true)
        shot("skills", MainWindowView(), window, screen: .skills)
        shot("history", RootView(openWindow: {}), NSSize(width: 440, height: 600), screen: .history)
        shot("question", QuizView(quiz: sampleQuiz, index: 1, results: [2], preset: QuestionPreset(pick: 1, confidence: .fairlySure,
              outcome: AnswerOutcome(becameKnown: true, skill: .debugging, chapterBefore: 1, chapterAfter: 1,
                                     newMilestones: [.firstKnown], known: 2))),
             NSSize(width: 440, height: 900), screen: .tasks)
        SkillsView.openForSnapshot = .debugging
        shot("skill", RootView(openWindow: {}), NSSize(width: 440, height: 600), screen: .skills)
        SkillsView.openForSnapshot = nil
        print("Wrote page screenshots to \(outDir.path)")
    }

    /// Writes the 1024px app icon artwork (transparent corners) for scripts/make-icon.sh.
    static func icon(to url: URL) {
        _ = NSApplication.shared
        render(AppIconArt(), size: NSSize(width: 1024, height: 1024), dark: false, to: url, opaque: false, scale: 1)
    }

    private static func render<V: View>(_ view: V, size: NSSize, dark: Bool, to url: URL,
                                        opaque: Bool = true, scale: CGFloat? = nil) {
        let root = view
            .frame(width: size.width, height: size.height)
            .background(opaque ? Color(nsColor: .windowBackgroundColor) : .clear)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = host.appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        if let scale {
            // Force an exact pixel size (the cached rep follows the screen's backing scale).
            rep.size = NSSize(width: size.width * scale, height: size.height * scale)
            guard let exact = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                                               pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                               bytesPerRow: 0, bitsPerPixel: 0) else { return }
            exact.size = rep.size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: exact)
            rep.draw(in: NSRect(origin: .zero, size: rep.size))
            NSGraphicsContext.restoreGraphicsState()
            try? exact.representation(using: .png, properties: [:])?.write(to: url)
            return
        }
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    // MARK: Placeholder data (no real tickets or customers)

    private static func model() -> AppModel {
        var state = AppState()
        state.initialised = true
        state.skillStats = [
            Skill.readingCode.rawValue: SkillStat(attempts: 6, points: 10, maxPoints: 12),
            Skill.debugging.rawValue: SkillStat(attempts: 5, points: 5, maxPoints: 10),
            Skill.design.rawValue: SkillStat(attempts: 4, points: 7, maxPoints: 8),
            Skill.shipping.rawValue: SkillStat(attempts: 3, points: 2, maxPoints: 6),
            Skill.testing.rawValue: SkillStat(attempts: 2, points: 3, maxPoints: 4),
            Skill.explaining.rawValue: SkillStat(attempts: 5, points: 6, maxPoints: 10),
        ]
        let day: TimeInterval = 86_400
        state.reviews = [
            ReviewItem(taskKey: "DEMO-101", question: sampleQuiz.questions[3], streak: 0, due: Date().addingTimeInterval(-60), confidentError: true),
            ReviewItem(taskKey: "DEMO-142", question: sampleQuiz.questions[1], streak: 1, due: Date().addingTimeInterval(-3600)),
            ReviewItem(taskKey: "OPS-77", question: sampleQuiz.questions[4], streak: 2, due: Date().addingTimeInterval(3 * day)),
        ]
        state.knownCold = [
            KnownItem(skill: .readingCode, text: "Dedicated list stores config IDs", taskKey: "DEMO-142"),
            KnownItem(skill: .readingCode, text: "The worker retries three times, then dead-letters", taskKey: "OPS-77"),
            KnownItem(skill: .readingCode, text: "Snooze writes go through one API", taskKey: "DEMO-101"),
            KnownItem(skill: .testing, text: "A test that has never failed proves nothing", taskKey: "DEMO-155"),
            KnownItem(skill: .debugging, text: "TTL explains \"flaky\" bugs", taskKey: "DEMO-101"),
            KnownItem(skill: .design, text: "Events fan out to every cache that cares", taskKey: "DEMO-101"),
        ]
        state.milestones = [Milestone.confidentFix.rawValue: Date()]
        let qs = sampleQuiz.questions
        state.history = [
            AnswerRecord(date: Date().addingTimeInterval(-300), taskKey: "DEMO-101", question: qs[1], yourAnswer: qs[1].choices![0], points: 0, confidence: .certain),
            AnswerRecord(date: Date().addingTimeInterval(-600), taskKey: "DEMO-101", question: qs[0], yourAnswer: qs[0].choices![1], points: 2, confidence: .fairlySure),
            AnswerRecord(date: Date().addingTimeInterval(-90000), taskKey: "OPS-77", question: qs[2], yourAnswer: "Snoozing saved fine but the cached count never refreshed.", points: 1, confidence: .fairlySure,
                         verdict: "Close", feedback: "Right cause; say how the fix works too.", reported: false),
            AnswerRecord(date: Date().addingTimeInterval(-95000), taskKey: "OPS-77", question: qs[3], yourAnswer: qs[3].choices![1], points: 0, confidence: .guessing, reported: true),
        ]
        state.calibration = [
            Confidence.guessing.rawValue: SkillStat(attempts: 9, points: 8, maxPoints: 18),
            Confidence.fairlySure.rawValue: SkillStat(attempts: 14, points: 20, maxPoints: 28),
            Confidence.certain.rawValue: SkillStat(attempts: 11, points: 17, maxPoints: 22),
        ]
        state.readyQuizzes["DEMO-101"] = sampleQuiz
        let m = AppModel(state: state, tasks: sampleTasks)
        m.playbook = Playbook.load()
        m.generating = ["DEMO-155"]
        return m
    }

    private static func session(_ title: String, hoursAgo: Double) -> SessionInfo {
        SessionInfo(id: UUID().uuidString, path: URL(fileURLWithPath: "/dev/null"), title: title, branch: nil,
                    lastModified: Date().addingTimeInterval(-hoursAgo * 3600), assistantTurns: 40,
                    ticketIds: [], branchTicketCandidate: nil)
    }

    private static var sampleTasks: [TaskItem] {
        func task(_ key: String, _ ticket: String?, _ title: String, _ hours: Double, _ n: Int) -> TaskItem {
            let sessions = (0..<n).map { session(title, hoursAgo: hours + Double($0) * 5) }
            return TaskItem(key: key, ticketId: ticket, title: title, sessions: sessions,
                            lastActivity: Date().addingTimeInterval(-hours * 3600), linear: nil)
        }
        return [
            task("DEMO-101", "DEMO-101", "Unread badge stays stale after snoozing a conversation", 0.4, 3),
            task("DEMO-155", "DEMO-155", "Guard file size in the media picker", 1.5, 1),
            task("OPS-77", "OPS-77", "Retry failed webhook deliveries", 3, 2),
            task("DEMO-142", "DEMO-142", "Saved replies drop attachments on one channel", 30, 1),
            task("session:a", nil, "Local Aspire setup errors", 50, 1),
            task("session:b", nil, "Slack message link", 60, 1),
        ]
    }

    private static let flow = Diagram(caption: "Snooze flow, today",
        nodes: [
            DiagramNode(id: "fe", label: "Web app", col: 0, row: 0, highlight: nil),
            DiagramNode(id: "api", label: "Snooze API", col: 1, row: 0, highlight: nil),
            DiagramNode(id: "db", label: "Database", col: 1, row: 1, highlight: nil),
            DiagramNode(id: "cache", label: "Unread cache", col: 2, row: 0, highlight: true),
        ],
        edges: [
            DiagramEdge(from: "fe", to: "api", label: "PATCH", style: "solid"),
            DiagramEdge(from: "api", to: "db", label: "save", style: "solid"),
            DiagramEdge(from: "api", to: "cache", label: nil, style: "missing"),
        ])

    private static let branch = Diagram(caption: "Why the badge fixed itself",
        nodes: [
            DiagramNode(id: "snooze", label: "Snooze", col: 0, row: 0, highlight: nil),
            DiagramNode(id: "db", label: "Database", col: 1, row: 0, highlight: nil),
            DiagramNode(id: "cache", label: "Unread cache", col: 1, row: 1, highlight: true),
            DiagramNode(id: "badge", label: "Badge", col: 2, row: 1, highlight: nil),
        ],
        edges: [
            DiagramEdge(from: "snooze", to: "db", label: "saves", style: "solid"),
            DiagramEdge(from: "db", to: "cache", label: "every 5 min", style: "dashed"),
            DiagramEdge(from: "cache", to: "badge", label: nil, style: "solid"),
        ])

    private static let fixed = Diagram(caption: "After the fix",
        nodes: [
            DiagramNode(id: "api", label: "Snooze API", col: 0, row: 0, highlight: nil),
            DiagramNode(id: "ev", label: "Snoozed event", col: 1, row: 0, highlight: true),
            DiagramNode(id: "cache", label: "Unread cache", col: 2, row: 0, highlight: nil),
        ],
        edges: [
            DiagramEdge(from: "api", to: "ev", label: "publish", style: "solid"),
            DiagramEdge(from: "ev", to: "cache", label: "invalidate", style: "dashed"),
        ])

    static let sampleQuiz = Quiz(taskKey: "DEMO-101", title: "DEMO-101 · Unread badge after snooze",
        summary: "Snoozing a conversation saved correctly, but the unread count is cached and nothing told the cache to refresh, so the badge stayed wrong for up to five minutes. The fix publishes a 'snoozed' event that clears that workspace's cached count.",
        questions: [
            Question(kind: .diagram, skill: .design,
                     prompt: "The red link is where the bug lived. What was missing there?",
                     choices: ["The API never saved the snooze", "Nothing told the cache to refresh", "The web app sent the wrong conversation ID"],
                     answerIndex: 1, modelAnswer: nil,
                     explanation: "The data was right in the database; only the cached copy was stale. Junior tip: when a value is wrong only for a while and then fixes itself, suspect a cache before the code that writes the data.",
                     diagram: flow, feedbackDiagram: fixed),
            Question(kind: .choice, skill: .debugging,
                     context: "The bug report said the badge was \"sometimes\" wrong after snoozing, which made it hard to reproduce.",
                     prompt: "Why did the bug look 'flaky' to the person who reported it?",
                     choices: ["The snooze job runs on a random schedule", "The cache expires after five minutes, so it fixed itself", "Only some browsers were affected"],
                     answerIndex: 1, modelAnswer: nil,
                     explanation: "Cached values have a time-to-live. After five minutes the cache refetched and the badge was right again, which made it hard to reproduce. Junior tip: ask \"does it fix itself if I wait?\" early; the answer narrows things down fast.",
                     diagram: nil, feedbackDiagram: branch),
            Question(kind: .explain, skill: .explaining,
                     context: "The unread badge stayed wrong for a few minutes after someone snoozed a conversation. The fix touched the snooze API and the unread cache.",
                     prompt: "Explain to your lead, in two sentences, why the badge was wrong and how the fix makes it update straight away.",
                     guide: ["What was actually stale, and where", "Why it fixed itself after a while", "What the fix now does when you snooze"],
                     choices: nil, answerIndex: nil,
                     modelAnswer: "Snoozing saved fine, but the unread count is cached per workspace and wasn't refreshed. The fix publishes a snoozed event that clears that cache, so the badge updates straight away.",
                     explanation: "Good status updates name the cause and the mechanism of the fix, not the files touched. Junior tip: cause, fix, and how you checked it, in that order.",
                     diagram: nil, feedbackDiagram: nil),
            Question(kind: .choice, skill: .shipping, prompt: "What else reads the same cached count?",
                     choices: ["The mobile app's tab badge", "Billing", "The audit log"], answerIndex: 0, modelAnswer: nil,
                     explanation: "x", diagram: nil, feedbackDiagram: nil),
            Question(kind: .explain, skill: .testing, prompt: "What test would have caught this?",
                     choices: nil, answerIndex: nil, modelAnswer: "x", explanation: "x", diagram: nil, feedbackDiagram: nil),
        ])

    private static let sampleGrade = Grade(score: 1, verdict: "Close",
        feedback: "You nailed the cause: the snooze saved but the count went stale. What's missing is how the fix works. Your lead will ask that next, so say it up front: an event now clears the cached count.",
        feedbackDiagram: nil)
}
