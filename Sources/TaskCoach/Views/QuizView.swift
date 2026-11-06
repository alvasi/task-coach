import SwiftUI

/// Lets the snapshot renderer show a question mid-answer. Unused in the live app.
struct QuestionPreset {
    var pick: Int?
    var answer = ""
    var grade: Grade?
    var confidence: Confidence?
    var outcome: AnswerOutcome?
}

struct QuizView: View {
    enum Phase { case answering, paused, done }

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var nav: Navigator
    let quiz: Quiz

    @State private var index: Int
    @State private var results: [Int]
    @State private var phase: Phase
    /// Where the current sitting stops; set on first appearance from the "questions per sitting" setting.
    @State private var sittingEnd: Int?
    @State private var writingMore = false
    private let preset: QuestionPreset?

    init(quiz: Quiz, index: Int = 0, results: [Int] = [], phase: Phase = .answering, preset: QuestionPreset? = nil) {
        self.quiz = quiz
        _index = State(initialValue: index)
        _results = State(initialValue: results)
        _phase = State(initialValue: quiz.questions.isEmpty ? .done : phase)
        self.preset = preset
    }

    private var perSitting: Int { max(1, model.state.questionsPerSitting) }
    private var limit: Int { sittingEnd ?? min(quiz.questions.count, index + perSitting) }
    private var remaining: Int { quiz.questions.count - results.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            switch phase {
            case .answering:
                QuestionCard(question: quiz.questions[index], taskKey: quiz.taskKey,
                             nextLabel: nextLabel, canStop: index + 1 < quiz.questions.count,
                             preset: preset, onNext: advance, onStop: stop)
                    .id(index)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity))
            case .paused, .done:
                ScrollView {
                    FinishView(quiz: quiz, results: results, paused: phase == .paused, remaining: remaining).padding(14)
                }
                footerBar {
                    if phase == .paused {
                        Button("Done for now") { nav.close() }.buttonStyle(SoftButtonStyle(tint: Theme.inkMuted))
                        Spacer()
                        Button("Keep going · \(min(perSitting, remaining)) more") {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                sittingEnd = min(quiz.questions.count, results.count + perSitting)
                                phase = .answering
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        if model.canContinue(quiz) && remaining == 0 {
                            Button {
                                writingMore = true
                                Task {
                                    let next = await model.moreQuestions(after: quiz)
                                    writingMore = false
                                    if let next { nav.open(next) }
                                }
                            } label: {
                                if writingMore {
                                    HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("Writing 3 more…") }
                                } else {
                                    Text("3 more on this")
                                }
                            }
                            .buttonStyle(SoftButtonStyle())
                            .disabled(writingMore)
                            .help("A new practice and a different part of the work. Takes about 30 seconds.")
                        }
                        Spacer()
                        Button("Back to tasks") { nav.close() }.buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
        .onAppear { if sittingEnd == nil { sittingEnd = min(quiz.questions.count, index + perSitting) } }
    }

    private var nextLabel: String {
        if index + 1 >= quiz.questions.count { return "See results" }
        if index + 1 >= limit { return "Take a break" }
        return "Next"
    }

    private func advance(_ points: Int) {
        results.append(points)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            index += 1
            if index >= quiz.questions.count {
                phase = .done
            } else if index >= limit {
                phase = .paused
            }
        }
        // Save progress at every pause so leaving never re-asks answered questions.
        if phase != .answering { model.finish(quiz: quiz, answered: results.count) }
    }

    private func stop(_ points: Int) {
        results.append(points)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { phase = .done }
        model.finish(quiz: quiz, answered: results.count)
    }

    private func leave() {
        if phase == .answering && !results.isEmpty { model.finish(quiz: quiz, answered: results.count) }
        nav.close()
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { leave() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(IconButtonStyle())
                    .help("Back to tasks. Unanswered questions stay ready.")
                VStack(alignment: .leading, spacing: 1) {
                    Text(quiz.title).font(.serif(14, .bold)).lineLimit(1)
                    Text(subtitle).font(.serif(12)).italic().foregroundStyle(Theme.inkMuted)
                }
                Spacer()
            }
            ProgressSegments(total: quiz.questions.count, results: results, current: phase == .answering ? index : nil)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var subtitle: String {
        switch phase {
        case .answering: return "Question \(min(index + 1, quiz.questions.count)) of \(quiz.questions.count)"
        case .paused: return "Break · \(remaining) left"
        case .done: return "Results"
        }
    }
}

private struct ProgressSegments: View {
    let total: Int
    let results: [Int]
    let current: Int?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Rectangle()
                    .fill(color(i))
                    .frame(height: i == current ? 3 : 2)
            }
        }
        .animation(.easeOut(duration: 0.25), value: results)
    }

    private func color(_ i: Int) -> Color {
        if i < results.count { return Theme.scoreColor(results[i]) }
        if i == current { return Theme.ink }
        return Theme.cardStroke
    }
}

/// Shared bottom bar so every screen's main action sits in the same place.
@ViewBuilder
func footerBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(spacing: 0) {
        Divider().opacity(0.6)
        HStack(spacing: 10) { content() }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
    }
}

private struct QuestionCard: View {
    @EnvironmentObject var model: AppModel
    let question: Question
    let taskKey: String
    let nextLabel: String
    let canStop: Bool
    let onNext: (Int) -> Void
    let onStop: (Int) -> Void

    @State private var picked: Int?
    @State private var confidence: Confidence?
    @State private var answer: String
    @State private var grading = false
    @State private var grade: Grade?
    @State private var gaveUp = false
    @State private var error: String?
    @State private var points: Int?
    @State private var showModel = false
    @State private var outcome: AnswerOutcome?
    @State private var reported = false
    @FocusState private var editorFocused: Bool

    init(question: Question, taskKey: String, nextLabel: String, canStop: Bool, preset: QuestionPreset?,
         onNext: @escaping (Int) -> Void, onStop: @escaping (Int) -> Void) {
        self.question = question
        self.taskKey = taskKey
        self.nextLabel = nextLabel
        self.canStop = canStop
        self.onNext = onNext
        self.onStop = onStop
        _picked = State(initialValue: preset?.pick)
        _confidence = State(initialValue: preset?.confidence)
        _answer = State(initialValue: preset?.answer ?? "")
        _grade = State(initialValue: preset?.grade)
        _outcome = State(initialValue: preset?.outcome)
        var p: Int?
        if let pick = preset?.pick, preset?.confidence != nil { p = pick == question.answerIndex ? 2 : 0 }
        if let g = preset?.grade { p = g.score }
        _points = State(initialValue: p)
    }

    private var revealed: Bool { points != nil }

    /// Guidance helps novices but gets in the way once you know the area, so the checklist
    /// starts tucked away for skills you're already strong in.
    private var isStrongSkill: Bool {
        guard let stat = model.state.skillStats[question.skill.rawValue], stat.attempts >= 4 else { return false }
        return (stat.ratio ?? 0) >= 0.8
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Chip(text: question.skill.title, icon: question.skill.symbol, color: question.skill.color)
                        Chip(text: roleLabel, color: question.role == "transfer" ? Theme.pencil : Theme.inkMuted)
                    }

                    if let context = question.context, !context.isEmpty {
                        Text(context)
                            .font(.serif(14.5))
                            .foregroundStyle(Theme.inkMuted)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(question.prompt)
                        .font(.serif(17.5, .bold))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let d = question.diagram { DiagramView(diagram: d) }

                    if question.isMultipleChoice { choices } else { freeText }

                    if !revealed && (picked != nil || !question.isMultipleChoice) {
                        ConfidencePicker(selection: confidence) { pickConfidence($0) }
                            .transition(.opacity)
                    }

                    if let error { ErrorBanner(text: error) { self.error = nil } }

                    if revealed {
                        feedback.transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: revealed)
            }
            footer
        }
    }

    /// Where this question sits in its chain: your ticket, the general practice, or a transfer.
    private var roleLabel: String {
        switch question.role {
        case "ticket": return "YOUR TICKET"
        case "practice": return "NAME THE PRACTICE"
        case "transfer": return "TRANSFER"
        default: return kindLabel
        }
    }

    private var kindLabel: String {
        switch question.kind {
        case .choice: return "Pick one"
        case .diagram: return "Read the diagram"
        case .explain: return "In your words"
        }
    }

    // MARK: Multiple choice

    private var choices: some View {
        VStack(spacing: 7) {
            ForEach(Array((question.choices ?? []).enumerated()), id: \.offset) { i, text in
                ChoiceRow(letter: String(UnicodeScalar(65 + i).map(Character.init) ?? "?"), text: text,
                          state: state(for: i)) {
                    guard !revealed else { return }
                    withAnimation(.easeOut(duration: 0.15)) { picked = i }
                }
            }
        }
    }

    /// Picking how sure you are is what locks in a multiple-choice answer.
    private func pickConfidence(_ c: Confidence) {
        confidence = c
        guard question.isMultipleChoice, let picked else { return }
        let p = (picked == question.answerIndex) ? 2 : 0
        points = p
        outcome = model.record(question: question, points: p, confidence: c, taskKey: taskKey,
                               yourAnswer: question.choices.map { $0[picked] } ?? "")
    }

    private func state(for i: Int) -> ChoiceRow.State {
        guard revealed else { return i == picked ? .selected : .idle }
        if i == question.answerIndex { return .correct }
        if i == picked { return .wrong }
        return .dimmed
    }

    // MARK: Free text

    private var freeText: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if answer.isEmpty {
                    Text("Write it the way you'd say it to a teammate…")
                        .font(.serif(14)).italic()
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $answer)
                    .font(.serif(14))
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
                    .disabled(revealed || grading)
            }
            .frame(minHeight: 96)
            .padding(10)
            .background(Rectangle().fill(Theme.cardFill))
            .overlay(
                Rectangle()
                    .strokeBorder(editorFocused ? Theme.brand.opacity(0.7) : Theme.cardStroke, lineWidth: editorFocused ? 1.5 : 1)
            )
            if let guide = question.guide, !guide.isEmpty {
                GuideChecklist(points: guide, startCollapsed: isStrongSkill)
            }
            if !revealed {
                Text("Rough is fine. Claude grades the idea, not the wording.")
                    .font(.serif(12.5)).foregroundStyle(Theme.inkMuted)
            }
        }
    }

    private func submitText() {
        grading = true
        error = nil
        Task {
            defer { grading = false }
            do {
                let g = try await model.grade(question: question, answer: answer)
                grade = g
                points = g.score
                outcome = model.record(question: question, points: g.score, confidence: confidence ?? .fairlySure, taskKey: taskKey,
                                       yourAnswer: answer, verdict: g.verdict, feedback: g.feedback)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: Feedback

    /// One panel, in reading order: verdict, the takeaway (the only emphasised line), then the
    /// explanation and any diagram right under it. Fewer boxes, less to scan.
    private var feedback: some View {
        let color = gaveUp ? Theme.brandText : Theme.scoreColor(points ?? 0)
        let (lesson, explanationTip) = splitTip(question.explanation)
        let practice = model.practice(for: question)
        // Practice and transfer questions teach a playbook rule, so the rule is the takeaway.
        let tip = practice?.rule ?? explanationTip
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
                Text(verdict).font(.serif(15, .bold)).foregroundStyle(color)
                if let note = calibrationNote {
                    Text("· \(note)").font(.serif(12.5)).italic().foregroundStyle(Theme.inkMuted)
                }
            }

            if let tip {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "lightbulb.fill").font(.system(size: 11)).foregroundStyle(Color(hex: 0xF5B400))
                    VStack(alignment: .leading, spacing: 3) {
                        (Text("Takeaway: ").foregroundColor(Theme.brandText) + Text(tip))
                            .font(.serif(14, .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        if let practice { PlaybookSourceLine(entry: practice) }
                    }
                }
            }

            if let g = grade {
                Text(g.feedback).font(.serif(14)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            Text(lesson).font(.serif(14)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(grade == nil ? Theme.ink : Theme.inkMuted)

            if let d = grade?.feedbackDiagram ?? question.feedbackDiagram { DiagramView(diagram: d) }

            if let quote = question.evidence, !quote.isEmpty {
                (Text("From your session: ").foregroundColor(Theme.inkMuted) + Text("“\(quote)”").italic())
                    .font(.serif(12.5))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if reported {
                Text("Thanks. It's been taken out of your stats, shelf and review queue.")
                    .font(.serif(12.5)).foregroundStyle(Theme.inkMuted)
            } else {
                Button("This answer is wrong") {
                    model.reportWrong(question: question, points: points, confidence: confidence,
                                      outcome: outcome, taskKey: taskKey)
                    reported = true
                }
                .buttonStyle(.plain)
                .font(.serif(12.5))
                .underline()
                .foregroundStyle(Theme.inkMuted)
                .help("Undo this answer's effect and keep a note so the question can be checked")
            }

            if question.kind == .explain, let m = question.modelAnswer {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showModel.toggle() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                                .rotationEffect(.degrees(showModel || gaveUp ? 90 : 0))
                            Text("What a strong answer covers").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Theme.brandText)
                    }
                    .buttonStyle(.plain)
                    if showModel || gaveUp {
                        Text(m).font(.serif(14)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.leading, 13)
        .padding(.vertical, 4)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3)
        }
        .safeAreaInset(edge: .bottom, spacing: 12) { progressLine }
    }

    /// One line on what this answer moved: a card on the shelf, a new chapter, a milestone.
    @ViewBuilder
    private var progressLine: some View {
        if let o = outcome, o.becameKnown || !o.newMilestones.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if o.chapterAfter > o.chapterBefore {
                    Text("✎ \(o.skill.title) reached chapter \(roman(o.chapterAfter))")
                        .font(.serif(14, .bold)).italic().foregroundStyle(Theme.pencil)
                } else if o.becameKnown {
                    let next = Chapter.toNext(known: o.known)
                    Text("✎ On the shelf: known cold." + (next.map { " \(o.skill.title) is \($0) away from chapter \(roman(o.chapterAfter + 1))." } ?? ""))
                        .font(.serif(13.5)).italic().foregroundStyle(Theme.pencil)
                }
                ForEach(o.newMilestones, id: \.rawValue) { m in
                    HStack(spacing: 12) {
                        Stamp(text: m.title).frame(maxWidth: 190)
                        Text(m.detail).font(.serif(12.5)).italic().foregroundStyle(Theme.inkMuted)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
        }
    }

    /// Goes in the footer, so it doesn't add another block to the panel.
    private var comesBack: Bool { revealed && ((points ?? 0) < 2 || confidence == .guessing) }

    /// The prompt asks Claude to end explanations with "Junior tip: …"; show that part as its own callout.
    private func splitTip(_ text: String) -> (String, String?) {
        guard let r = text.range(of: "Junior tip:", options: .caseInsensitive) else { return (text, nil) }
        let lesson = text[..<r.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        var tip = text[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = tip.first { tip = first.uppercased() + tip.dropFirst() }
        return (lesson, tip.isEmpty ? nil : tip)
    }

    /// Calls out the two cases worth noticing: sure but wrong, and right by luck.
    private var calibrationNote: String? {
        guard !gaveUp, let confidence, let points else { return nil }
        if confidence == .certain && points < 2 { return "you were certain, so this comes back first" }
        if confidence == .guessing && points == 2 { return "but you were guessing, so it comes back once more" }
        return nil
    }

    private var icon: String {
        if gaveUp { return "lightbulb.fill" }
        switch points {
        case 2: return "checkmark.circle.fill"
        case 1: return "circle.lefthalf.filled"
        default: return "xmark.circle.fill"
        }
    }

    private var verdict: String {
        if let g = grade { return g.verdict }
        if gaveUp { return "Here's the idea" }
        return points == 2 ? "Correct" : "Not quite"
    }

    // MARK: Footer

    private var footer: some View {
        footerBar {
            if !question.isMultipleChoice && !revealed {
                Button("I don't know") {
                    gaveUp = true
                    confidence = .guessing
                    points = 0
                    outcome = model.record(question: question, points: 0, confidence: .guessing, taskKey: taskKey,
                                           yourAnswer: "I don't know")
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.inkMuted))
                .disabled(grading)
            }
            if question.isMultipleChoice && !revealed {
                Text(picked == nil ? "Pick the best answer" : "Then say how sure you are")
                    .font(.serif(13)).foregroundStyle(Theme.inkMuted)
            }
            if comesBack {
                Label("back for review tomorrow", systemImage: "arrow.triangle.2.circlepath")
                    .font(.serif(12)).italic().foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            // At the end of a sitting "Take a break" already stops, so only offer this mid-sitting.
            if revealed && canStop && nextLabel == "Next" {
                Button("Stop here") { onStop(points ?? 0) }
                    .buttonStyle(SoftButtonStyle(tint: Theme.inkMuted))
                    .help("End now. The rest stay ready for later.")
            }
            if revealed {
                Button {
                    onNext(points ?? 0)
                } label: {
                    Label(nextLabel, systemImage: nextLabel == "Next" ? "arrow.right" : nextLabel == "See results" ? "flag.checkered" : "cup.and.saucer")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            } else if !question.isMultipleChoice {
                Button {
                    submitText()
                } label: {
                    if grading {
                        HStack(spacing: 6) { ProgressView().controlSize(.mini).tint(.white); Text("Grading…") }
                    } else {
                        Text("Check answer")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).count < 5 || confidence == nil || grading)
            }
        }
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) { configuration.title; configuration.icon }
    }
}

private struct ChoiceRow: View {
    enum State { case idle, selected, correct, wrong, dimmed }

    let letter: String
    let text: String
    let state: State
    let action: () -> Void
    @SwiftUI.State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle().fill(badgeFill)
                    if state == .correct {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                    } else if state == .wrong {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                    } else {
                        Text(letter).font(.system(size: 11, weight: .bold))
                            .foregroundStyle(state == .selected ? Color.white : Theme.inkMuted)
                    }
                }
                .frame(width: 22, height: 22)
                Text(text)
                    .font(.serif(14))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(state == .dimmed ? Theme.inkMuted : Theme.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Rectangle().fill(fill))
            .overlay(Rectangle().strokeBorder(stroke, lineWidth: state == .idle ? 1 : 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.easeOut(duration: 0.2), value: state)
    }

    private var fill: Color {
        switch state {
        case .idle: return hovering ? Theme.pencil.opacity(0.05) : Theme.cardFill
        case .selected: return Theme.brand.opacity(0.12)
        case .correct: return Theme.good.opacity(0.1)
        case .wrong: return Theme.bad.opacity(0.08)
        case .dimmed: return .clear
        }
    }

    private var stroke: Color {
        switch state {
        case .idle: return hovering ? Theme.brand.opacity(0.5) : Theme.cardStroke
        case .selected: return Theme.brand
        case .correct: return Theme.good
        case .wrong: return Theme.bad
        case .dimmed: return Theme.cardStroke.opacity(0.6)
        }
    }

    private var badgeFill: Color {
        switch state {
        case .correct: return Theme.good
        case .wrong: return Theme.bad
        case .selected: return Theme.brand
        default: return Theme.rule
        }
    }
}

// MARK: - Results

private struct FinishView: View {
    let quiz: Quiz
    let results: [Int]
    var paused = false
    var remaining = 0

    var body: some View {
        let total = results.reduce(0, +), max = results.count * 2
        let ratio = max == 0 ? 0 : Double(total) / Double(max)
        VStack(alignment: .leading, spacing: 18) {
            // The big picture leads: it's the thing to walk away with. Shown only once you're done,
            // after you've tried to recall it yourself.
            if !paused && !quiz.summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("The big picture", systemImage: "binoculars.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.brandText)
                    Text(quiz.summary).font(.serif(15.5)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    Text("Could you say this to your lead without looking?")
                        .font(.serif(12.5)).foregroundStyle(Theme.inkMuted)
                }
                .padding(.leading, 13)
                .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(Theme.brand).frame(width: 3) }
            }

            HStack(spacing: 12) {
                ZStack {
                    ScoreRing(value: ratio, color: ratioColor(ratio), lineWidth: 4)
                    Text("\(total)").font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(paused ? "\(results.count) done, \(remaining) left" : headline(ratio))
                        .font(.serif(15, .bold))
                    Text(paused ? "Carry on now, or later from Up next."
                         : remaining > 0 ? "\(total) of \(max) points. The other \(remaining) questions are saved for later."
                         : "\(total) of \(max) points. \(subline(ratio))")
                        .font(.system(size: 11.5)).foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "By skill").padding(.bottom, 4)
                ForEach(Array(zip(quiz.questions, results).enumerated()), id: \.offset) { _, pair in
                    HStack(spacing: 10) {
                        Image(systemName: pair.0.skill.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(pair.0.skill.color)
                            .frame(width: 20)
                        Text(pair.0.skill.title).font(.serif(14))
                        Spacer()
                        Text(pair.1 == 2 ? "Got it" : pair.1 == 1 ? "Partly" : "To review")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.scoreColor(pair.1))
                    }
                    .padding(.vertical, 7)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.cardStroke).frame(height: 1) }
                }
            }
        }
    }

    private func ratioColor(_ r: Double) -> Color { r >= 0.85 ? Theme.good : r >= 0.6 ? Theme.brand : Theme.partial }

    // Feedback about the task, not about you.
    private func headline(_ r: Double) -> String {
        if r >= 0.85 { return "You can explain this task" }
        if r >= 0.6 { return "Mostly clear, a couple of gaps" }
        return "Some gaps worth a second look"
    }

    private func subline(_ r: Double) -> String {
        if r >= 0.85 { return "Ready for stand-up." }
        return "The gaps come back for review."
    }
}

// MARK: - Confidence

/// "How sure are you?" asked before the answer is revealed. Feeds the calibration view, and
/// confident mistakes jump the review queue.
struct ConfidencePicker: View {
    let selection: Confidence?
    let onPick: (Confidence) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("How sure are you?").font(.serif(13.5)).foregroundStyle(Theme.inkMuted)
            HStack(spacing: 6) {
                ForEach(Array(Confidence.allCases.enumerated()), id: \.element) { i, c in
                    Button {
                        onPick(c)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: c.symbol).font(.system(size: 10.5, weight: .semibold))
                            Text(c.title).font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(selection == c ? Theme.paperRaised : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Rectangle().fill(selection == c ? Theme.pencil : Theme.paperRaised))
                        .overlay(Rectangle().strokeBorder(selection == c ? Theme.pencil : Theme.cardStroke))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                    .help("Shortcut: \(i + 1)")
                }
            }
        }
    }
}

// MARK: - Guide

/// "Aim to cover" directions for explain questions: what to talk about, never the answer.
private struct GuideChecklist: View {
    let points: [String]
    @State private var open: Bool

    init(points: [String], startCollapsed: Bool) {
        self.points = points
        _open = State(initialValue: !startCollapsed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if open {
                Text("AIM TO COVER").font(.label).tracking(1.2).foregroundStyle(Theme.pencil)
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Image(systemName: "square").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.inkMuted)
                        Text(point).font(.serif(14)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { open = true }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                        Text("Show what to cover").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.brandText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

/// "From the playbook · Source ↗": where a practice comes from, linked to the page it was checked against.
private struct PlaybookSourceLine: View {
    let entry: PlaybookEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("From the playbook ·").foregroundStyle(Theme.inkMuted)
            if let url = entry.url {
                Link(destination: url) {
                    HStack(spacing: 2) {
                        Text(entry.source).underline()
                        Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .bold))
                    }
                }
                .foregroundStyle(Theme.inkMuted)
                .help(entry.checked)
            } else {
                Text(entry.source).foregroundStyle(Theme.inkMuted).help(entry.checked)
            }
        }
        .font(.serif(12))
        .lineLimit(2)
    }
}
