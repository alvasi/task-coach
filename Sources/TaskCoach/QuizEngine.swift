import Foundation

enum QuizEngine {
    // MARK: Schemas

    private static let diagramSchema = """
    {"type":"object","properties":{
      "caption":{"type":"string"},
      "nodes":{"type":"array","maxItems":7,"items":{"type":"object","properties":{
        "id":{"type":"string"},"label":{"type":"string"},
        "col":{"type":"integer","minimum":0,"maximum":3},"row":{"type":"integer","minimum":0,"maximum":3},
        "highlight":{"type":"boolean"}},"required":["id","label","col","row"]}},
      "edges":{"type":"array","items":{"type":"object","properties":{
        "from":{"type":"string"},"to":{"type":"string"},"label":{"type":"string"},
        "style":{"type":"string","enum":["solid","dashed","missing"]}},"required":["from","to"]}}
    },"required":["nodes","edges"]}
    """

    private static var skillEnum: String {
        "[" + Skill.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: ",") + "]"
    }

    static var quizSchema: String {
        """
        {"type":"object","properties":{
          "summary":{"type":"string"},
          "questions":{"type":"array","minItems":1,"maxItems":6,"items":{"type":"object","properties":{
            "kind":{"type":"string","enum":["choice","explain","diagram"]},
            "role":{"type":"string","enum":["ticket","practice","transfer"]},
            "practiceId":{"type":"string"},
            "evidence":{"type":"string"},
            "skill":{"type":"string","enum":\(skillEnum)},
            "context":{"type":"string"},
            "prompt":{"type":"string"},
            "guide":{"type":"array","maxItems":3,"items":{"type":"string"}},
            "choices":{"type":"array","items":{"type":"string"}},
            "answerIndex":{"type":"integer"},
            "modelAnswer":{"type":"string"},
            "explanation":{"type":"string"},
            "diagram":\(diagramSchema),
            "feedbackDiagram":\(diagramSchema),
            "reviewOf":{"type":"integer"}
          },"required":["kind","role","skill","context","prompt","explanation"]}}
        },"required":["summary","questions"]}
        """
    }

    static var gradeSchema: String {
        """
        {"type":"object","properties":{
          "score":{"type":"integer","minimum":0,"maximum":2},
          "verdict":{"type":"string"},
          "feedback":{"type":"string"},
          "feedbackDiagram":\(diagramSchema)
        },"required":["score","verdict","feedback"]}
        """
    }

    // MARK: Prompts

    /// Optional description of the engineer's product and stack, from Settings.
    nonisolated(unsafe) static var workContext = ""

    static var systemPrompt: String {
        let about = workContext.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        You are Task Coach, a patient senior software engineer mentoring a junior engineer\(about.isEmpty ? "" : ". About their work: \(about)"). \
        The junior often lets an AI coding agent do the work and skims along. Your job is to make sure they \
        can explain the big picture of their own task, and to grow them as an engineer in general software \
        practice that applies at any company, using their work as the example. Write in plain, clear \
        English. Be warm and direct. Never include customer names, phone numbers, emails, or end-user \
        message content; say "a customer" instead. Only ask about facts that are present in the material \
        you are given; never invent details.
        """
    }

    static func quizPrompt(tasks: [TaskItem], weakSkills: [Skill], review: [ReviewItem], recap: Bool,
                           count: Int = 3, playbook: [PlaybookEntry] = [], avoid: [String] = [],
                           focus: Skill? = nil) -> String {
        let playbook = focus.map { f in playbook.filter { $0.skill == f } } ?? playbook
        var context: [String] = []
        let perTaskBudget = recap ? 25_000 : 60_000
        for task in tasks {
            var block = "## Task \(task.ticketId ?? "(no ticket)"): \(task.title)\n"
            if let issue = task.linear {
                block += "Linear status: \(issue.stateName ?? "unknown")\n"
                if let d = issue.description { block += "Ticket description:\n\(d.prefix(5000))\n" }
                if !issue.comments.isEmpty {
                    block += "Ticket comments:\n" + issue.comments.prefix(8).map { "- \($0.prefix(600))" }.joined(separator: "\n") + "\n"
                }
            }
            var remaining = perTaskBudget
            for session in task.sessions.prefix(4) where remaining > 2_000 {
                let d = SessionScanner.digest(of: session, maxChars: remaining)
                remaining -= d.count
                block += "\n" + d + "\n"
            }
            context.append(block)
        }

        let weak = weakSkills.isEmpty ? "none known yet" : weakSkills.map(\.rawValue).joined(separator: ", ")
        let reviewText = review.isEmpty ? "none"
            : review.enumerated().map { "[\($0.offset + 1)] (\($0.element.question.skill.rawValue)) \($0.element.question.prompt)" }
                .joined(separator: "\n")

        return """
        Below is what the junior engineer has been working on: Linear ticket details and condensed \
        Claude Code session transcripts (ENGINEER = what they typed, CLAUDE = what Claude said, \
        [brackets] = actions Claude took).

        \(context.joined(separator: "\n\n---\n\n"))

        ---

        THE PLAYBOOK. These are the only general practices you may teach. Each line is id | skill | rule.
        \(playbookText(playbook))

        The engineer's goal is twofold: keep a clear big picture of their own work, and learn general \
        software engineering practice that applies at any company. So questions come in three roles:
        - role "ticket": about their own work: what happened, why, how the change works. Leave "practiceId" out.
        - role "practice": which general practice from the playbook this work illustrates, would have caught \
        the problem earlier, or should guide the next step. Set "practiceId" to that playbook id.
        - role "transfer": the SAME practice (same "practiceId") applied to a short made-up scenario that has \
        nothing to do with this company, its product or its domain (for example a payments service, an \
        image upload pipeline, a booking system, a CLI tool). It must be answerable by someone who \
        understands the practice but has never seen this codebase. Use generic names only, and \
        describe the scenario plainly (don't call it "made-up" or "hypothetical").
        A chain is ticket, then practice, then transfer, all about one part of the work and one practice.
        \(avoid.isEmpty ? "" : """
        Already covered in this sitting's earlier chain. Use a DIFFERENT playbook practice and a DIFFERENT \
        part of the work; the ticket question must not re-ask any of these:
        \(avoid.map { "- \($0)" }.joined(separator: "\n"))
        """)

        \(focus.map(focusBlock) ?? "Write a \(recap ? "daily recap quiz spanning these tasks" : "quiz on this task") of \(mix(count))")
        - "choice" questions have 3 or 4 plausible choices; answerIndex is the 0-based correct one.
        - For every choice and diagram question: keep all choices about the same length and level of \
        detail (each under 20 words). The correct choice must NOT be the longest or most qualified one, \
        and its position must vary between questions. Wrong choices should be mistakes a junior could \
        genuinely make, not jokes.
        - A "diagram" question includes "diagram" showing the relevant part of the system (max 6 nodes, \
        grid col 0-3 and row 0-3, left-to-right flow). Mark the part being asked about with a highlighted \
        node or an edge with style "missing". Ask about that part, with choices and answerIndex. Keep \
        node labels to 3 words or fewer.
        - In an "explain" question the engineer answers in their own words. "modelAnswer" is 2 to 4 short \
        key points, under 60 words in total.

        Make every question specific and self-contained. The engineer skims, so a broad question gives them \
        nothing to grab onto:
        - "context": one plain sentence that sets the scene before the question: what the work is (in words, \
        e.g. "the guard that stops a LINE channel being connected to two workspaces") and which part this \
        question is about. Orient, never give the answer away.
        - "prompt": name the thing being asked about. Never refer to the work only by its ticket number, and \
        never ask them to explain or summarise a whole ticket. Each question targets ONE specific part: a \
        cause, a decision and its reason, a risk, how one piece of the fix works, or how it was verified.
        - For "explain" questions, give "guide": 2 or 3 short directions saying what a good answer should \
        cover (e.g. "What was actually broken", "Why it only happened sometimes", "What the fix changes"). \
        They are directions, not answers: never put the answer in them. The "modelAnswer" points should \
        line up with the guide.

        What to test, in priority order: what the task is and why it exists; how the change or fix \
        actually works; what could break or who would notice; decisions that were made and why; what \
        is still open or unverified. Test understanding, not trivia: no line numbers or exact variable \
        names unless they are central.

        Tag every question with one "skill" from: \(Skill.allCases.map(\.rawValue).joined(separator: ", ")). \
        For practice and transfer questions, use the skill of the playbook entry. Pick practices that \
        genuinely fit what happened in this work, leaning toward the engineer's weakest skills: \(weak).

        Earlier questions the engineer got wrong or guessed: if any relate to this material, re-test \
        exactly one of them from a new angle and set that question's "reviewOf" to its number. Leave \
        "reviewOf" out on every other question.
        \(reviewText)

        WHAT THE WORK DID IS NOT AUTOMATICALLY BEST PRACTICE. The code and decisions in the material may be \
        rushed, constrained or simply not optimal. So:
        - "ticket" questions test what happened and why the team chose it. Their explanation must not call \
        the approach correct, ideal or best practice unless a playbook entry says so.
        - In "practice" and "transfer" questions the correct answer is whatever the playbook practice says, \
        even when the work did something different. If the work fell short of the practice, ask what \
        following the practice would have changed here, and say so plainly in the explanation: what the \
        work did, then what the practice recommends.
        - Never present a habit of this codebase or company as a general rule unless a playbook entry says it.

        GROUNDING. Every answer must be something the material above actually says, because a wrong \
        "correct" answer teaches the engineer something false:
        - For "ticket" and "practice" questions, set "evidence" to a sentence copied word for word \
        describing what happened in the work (the practice itself comes from the playbook, not the material) (at most \
        30 words) from the material above that proves the correct answer. The app checks the quote against \
        the material and throws the question away if it isn't there.
        - If the material doesn't state the answer outright, don't ask that question.
        - Never join two separate facts into one answer (for example a scope decision and a follow-up \
        ticket) unless the material itself links them.
        - Leave "evidence" out for "transfer" questions.

        "explanation" is shown after they answer: 2 or 3 sentences (under 60 words) that teach the idea \
        underneath, then \
        one line starting "Junior tip:" with the general lesson that transfers to other tasks. For practice \
        and transfer questions the tip must be the playbook rule itself. Never name this company, its \
        products or its customers in a tip. Add a \
        "feedbackDiagram" on questions where a picture of the real mechanism would help (at least 2).

        "summary": the big picture of the work in two or three plain sentences, as a senior would say it.
        """
    }

    static func gradePrompt(question: Question, answer: String, practice: PlaybookEntry? = nil) -> String {
        """
        Grade a junior engineer's answer.

        Context: \(question.context ?? "(none)")
        Question: \(question.prompt)
        What the answer was asked to cover: \((question.guide ?? []).joined(separator: "; "))
        Key points a good answer hits: \(question.modelAnswer ?? "(not given)")
        Practice being taught: \(practice.map { "\($0.rule) (\($0.source))" } ?? "(none)")
        Background: \(question.explanation)

        Their answer:
        \"\"\"
        \(answer)
        \"\"\"

        Judge against the practice and the key points, not against what the team's code happened to do: an \
        answer that recommends better practice than the work used is not wrong.
        score: 2 = hits the key points (wording doesn't matter), 1 = partly right or vague, 0 = wrong or missing.
        verdict: two or three words, e.g. "Spot on", "Close", "Not quite".
        feedback: at most 3 sentences and under 60 words, because they read it straight after answering. \
        First what they got right (skip if nothing), then the single most important thing missing or wrong, \
        naming which of the "cover" points it was. \
        Do not repeat the full model answer; it is shown separately. Add feedbackDiagram only if a picture \
        would clear up what they missed.
        """
    }

    // MARK: Calls

    /// The question mix for a quiz of `count` questions, built from ticket -> practice -> transfer chains.
    private static func mix(_ count: Int) -> String {
        switch count {
        case 1:
            return """
            exactly 1 question with role "practice", kind "choice": the single most useful general practice \
            this work illustrates, asked through the work itself.
            """
        case 2...4:
            return """
            exactly 3 questions forming one chain: a "ticket" question, then a "practice" question, then a \
            "transfer" question, in that order. Exactly 1 of the 3 has kind "explain"; the rest are "choice" \
            (a "ticket" question may be a "diagram").
            """
        default:
            return """
            exactly 6 questions forming two chains, in order: ticket, practice, transfer, then ticket, \
            practice, transfer. The two chains cover two different parts of the work and two different \
            playbook practices. Exactly 1 question is kind "diagram" (a ticket question) and exactly 1 is \
            kind "explain" (one where they explain one specific part to their lead in two sentences, or \
            explain a practice using this work as the example). The rest are "choice".
            """
        }
    }

    /// Focused practice on one skill: a chain from the work if anything fits, otherwise pure transfer.
    private static func focusBlock(_ skill: Skill) -> String {
        """
        FOCUSED PRACTICE on one skill: \(skill.title) (\(skill.blurb.lowercased())). Write exactly 3 \
        questions, all with skill "\(skill.rawValue)", each built on a practice from the playbook above.
        - If some part of the work above genuinely involves this skill, write one chain: a "ticket" \
        question about that part, then a "practice" question, then a "transfer" question.
        - If nothing in the work genuinely involves this skill, don't force it: write 3 "transfer" \
        questions on three different practices instead.
        Exactly 1 of the 3 has kind "explain"; the rest are "choice".
        """
    }

    private static func playbookText(_ playbook: [PlaybookEntry]) -> String {
        playbook.map { "\($0.id) | \($0.skill.rawValue) | \($0.rule)" }.joined(separator: "\n")
    }

    static func generate(tasks: [TaskItem], weakSkills: [Skill], review: [ReviewItem], recap: Bool,
                         count: Int = 3, key overrideKey: String? = nil, title overrideTitle: String? = nil,
                         playbook: [PlaybookEntry] = [], avoid: [String] = [], focus: Skill? = nil,
                         model: String, claudePath: String?) async throws -> Quiz {
        let prompt = quizPrompt(tasks: tasks, weakSkills: weakSkills, review: review, recap: recap, count: count,
                                playbook: playbook, avoid: avoid, focus: focus)
        let data = try await ClaudeRunner.run(prompt: prompt, systemPrompt: systemPrompt, schema: quizSchema,
                                              model: model, claudePath: claudePath)
        let material = Grounding.normalise(prompt)
        let generated: GeneratedQuiz
        do {
            generated = try JSONDecoder().decode(GeneratedQuiz.self, from: data)
        } catch {
            throw ClaudeError.badOutput(error.localizedDescription)
        }
        let key = overrideKey ?? (recap ? "daily" : (tasks.first?.key ?? "unknown"))
        let title = overrideTitle ?? (recap ? "Daily recap"
            : (tasks.first.map { [$0.ticketId, $0.title].compactMap { $0 }.joined(separator: " · ") } ?? "Quiz"))
        // Drop malformed choice questions rather than showing a broken card.
        var questions = generated.questions.filter { q in
            guard q.kind != .explain else { return true }
            guard let c = q.choices, let i = q.answerIndex else { return false }
            return c.indices.contains(i)
        }
        // Drop questions about the work whose quoted proof isn't really in the session. A confident
        // wrong answer is worse than no question.
        questions = questions.filter { q in
            guard q.role != "transfer" else { return true }
            guard let quote = q.evidence, !quote.isEmpty else { return false }
            return Grounding.found(quote, in: material)
        }
        guard !questions.isEmpty else {
            throw ClaudeError.badOutput("none of the questions could be checked against your session. Try again.")
        }
        // Models favour putting the right answer in the same slot; shuffle so position gives nothing away.
        for i in questions.indices where questions[i].isMultipleChoice {
            guard let choices = questions[i].choices, let answer = questions[i].answerIndex else { continue }
            let order = Array(choices.indices).shuffled()
            questions[i].choices = order.map { choices[$0] }
            questions[i].answerIndex = order.firstIndex(of: answer)
        }
        // Only playbook practices may be taught: drop ids Claude made up, and take the skill from the entry.
        let byId = Dictionary(uniqueKeysWithValues: playbook.map { ($0.id, $0) })
        for i in questions.indices {
            if let pid = questions[i].practiceId {
                if let entry = byId[pid] { questions[i].skill = entry.skill } else { questions[i].practiceId = nil }
            }
        }
        // Link a re-tested question back to its review item so answering it moves that item's schedule.
        for i in questions.indices {
            if let n = questions[i].reviewOf, review.indices.contains(n - 1) {
                questions[i].reviewId = review[n - 1].id
            }
            questions[i].reviewOf = nil
        }
        return Quiz(taskKey: key, title: title, summary: generated.summary, questions: questions)
    }

    static func grade(question: Question, answer: String, practice: PlaybookEntry? = nil,
                      model: String, claudePath: String?) async throws -> Grade {
        let data = try await ClaudeRunner.run(prompt: gradePrompt(question: question, answer: answer, practice: practice),
                                              systemPrompt: systemPrompt, schema: gradeSchema,
                                              model: model, claudePath: claudePath, timeout: 120, label: "grade")
        do {
            var g = try JSONDecoder().decode(Grade.self, from: data)
            g.score = max(0, min(2, g.score))
            return g
        } catch {
            throw ClaudeError.badOutput(error.localizedDescription)
        }
    }
}

/// Checks a quoted line really appears in the material Claude was given.
enum Grounding {
    static func normalise(_ text: String) -> String {
        let lowered = text.lowercased()
        let kept = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// Exact match after normalising, or failing that any run of 8 consecutive words, which allows
    /// for Claude trimming a quote at either end.
    static func found(_ quote: String, in material: String) -> Bool {
        let q = normalise(quote)
        guard !q.isEmpty else { return false }
        if material.contains(q) { return true }
        let words = q.split(separator: " ")
        let window = 8
        guard words.count > window else { return false }
        for start in 0...(words.count - window) {
            if material.contains(words[start..<(start + window)].joined(separator: " ")) { return true }
        }
        return false
    }
}
