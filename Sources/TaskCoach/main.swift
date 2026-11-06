import AppKit
import SwiftUI

// Debug helpers: `TaskCoach --scan` lists tasks, `TaskCoach --prompt <task key>` prints the quiz prompt.
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--page-shots"), i + 1 < args.count {
    MainActor.assumeIsolated { Snapshot.pageShots(outDir: URL(fileURLWithPath: args[i + 1])) }
    exit(0)
}
if let i = args.firstIndex(of: "--icon"), i + 1 < args.count {
    MainActor.assumeIsolated { Snapshot.icon(to: URL(fileURLWithPath: args[i + 1])) }
    exit(0)
}
if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
    var quiz: Quiz?
    if let q = args.firstIndex(of: "--quiz-file"), q + 1 < args.count,
       let data = try? Data(contentsOf: URL(fileURLWithPath: args[q + 1])) {
        quiz = try? JSONDecoder().decode(Quiz.self, from: data)
    }
    MainActor.assumeIsolated { Snapshot.run(outDir: URL(fileURLWithPath: args[i + 1]), quiz: quiz) }
    exit(0)
}
// `TaskCoach --practise <skill>` writes a focused 3-question quiz on one skill from recent work.
if let i = args.firstIndex(of: "--practise"), i + 1 < args.count, let skill = Skill(rawValue: args[i + 1]) {
    let tasks = SessionScanner.group(SessionScanner().scan(lookbackDays: 7), linear: [])
    Task {
        do {
            let quiz = try await QuizEngine.generate(tasks: Array(tasks.prefix(3)), weakSkills: [], review: [], recap: true,
                                                     count: 3, playbook: Playbook.load(), focus: skill,
                                                     model: "sonnet", claudePath: nil)
            for q in quiz.questions {
                print("[\(q.role ?? "-")] \(q.skill.rawValue) \(q.practiceId ?? "-") | \(q.prompt)")
                if let e = q.evidence { print("    evidence: \(e)") }
            }
        } catch { print("FAILED:", error.localizedDescription) }
        exit(0)
    }
    RunLoop.main.run()
}

// `TaskCoach --quiz <task key>` generates a real quiz and grades a sample answer, printing both.
if let i = args.firstIndex(of: "--quiz"), i + 1 < args.count {
    let key = args[i + 1]
    let tasks = SessionScanner.group(SessionScanner().scan(lookbackDays: 7), linear: [])
    guard let task = tasks.first(where: { $0.key == key }) else { print("No task \(key)"); exit(1) }
    Task {
        do {
            let start = Date()
            let count = args.firstIndex(of: "--count").flatMap { Int(args[$0 + 1]) } ?? 3
            // `--review-file quiz.json`: treat that quiz's first question as a due review item.
            var review: [ReviewItem] = []
            if let r = args.firstIndex(of: "--review-file"),
               let data = try? Data(contentsOf: URL(fileURLWithPath: args[r + 1])),
               let old = try? JSONDecoder().decode(Quiz.self, from: data), let q = old.questions.first {
                review = [ReviewItem(taskKey: key, question: q, due: Date())]
            }
            let quiz = try await QuizEngine.generate(tasks: [task], weakSkills: [.shipping, .codeReview], review: review,
                                                     recap: false, count: count, playbook: Playbook.load(),
                                                     avoid: args.firstIndex(of: "--avoid").map { args[$0 + 1].components(separatedBy: ",") } ?? [],
                                                     model: "sonnet", claudePath: nil)
            print("Questions:", quiz.questions.count, "| linked to review:", quiz.questions.filter { $0.reviewId != nil }.count,
                  "| kinds:", quiz.questions.map(\.kind.rawValue))
            print("Generated in \(Int(Date().timeIntervalSince(start)))s")
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let json = try enc.encode(quiz)
            print(String(data: json, encoding: .utf8)!)
            if let o = args.firstIndex(of: "--out"), o + 1 < args.count {
                try json.write(to: URL(fileURLWithPath: args[o + 1]))
            }
            if let q = quiz.questions.first(where: { $0.kind == .explain }) {
                let g = try await QuizEngine.grade(question: q, answer: "I'm not totally sure, I think it was something about the channel config not being saved properly.",
                                                   model: "sonnet", claudePath: nil)
                print("GRADE:", g.score, g.verdict, "|", g.feedback)
            }
        } catch {
            print("FAILED:", error.localizedDescription)
        }
        exit(0)
    }
    RunLoop.main.run()
}

if args.contains("--scan") || args.contains("--prompt") {
    let sessions = SessionScanner().scan(lookbackDays: 7)
    let tasks = SessionScanner.group(sessions, linear: [])
    if let i = args.firstIndex(of: "--prompt"), i + 1 < args.count {
        if let task = tasks.first(where: { $0.key == args[i + 1] }) {
            print(QuizEngine.quizPrompt(tasks: [task], weakSkills: [], review: [], recap: false))
        } else {
            print("No task with key \(args[i + 1])")
        }
    } else {
        for t in tasks {
            print("\(t.key)\t\(t.sessions.count) sessions\t\(t.lastActivity)\t\(t.title)")
        }
    }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
