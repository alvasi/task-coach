import SwiftUI

/// The menu bar popover.
struct RootView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var nav: Navigator
    var openWindow: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if case .quiz = nav.screen, let quiz = nav.activeQuiz {
                QuizView(quiz: quiz).id(quiz.id)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                header
                Group {
                    switch nav.screen {
                    case .skills: SkillsView()
                    case .history: HistoryView()
                    case .settings: SettingsView()
                    default: TaskListView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: 440, height: 600)
        .foregroundStyle(Theme.ink)
        .background(RuledPaper())
        .tint(Theme.pencil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: nav.screen)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Notes.title).font(.serif(19, .bold))
                    Text(Notes.subtitle(model)).font(.serif(12)).italic().foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(model.scanning ? 360 : 0))
                        .animation(model.scanning ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                                   value: model.scanning)
                }
                .buttonStyle(IconButtonStyle())
                .help("Rescan your Claude sessions")
                if let openWindow {
                    Button(action: openWindow) { Image(systemName: "macwindow") }
                        .buttonStyle(IconButtonStyle())
                        .help("Open the Task Coach window")
                }
            }
            UnderlineTabs(
                titles: ["Notes", "Skills", "Past answers", "Settings"],
                badges: [nil, model.dueReviews.count > 0 ? model.dueReviews.count : nil, nil, nil],
                selection: Binding(
                    get: { [Screen.tasks, .skills, .history, .settings].firstIndex(of: nav.screen) ?? 0 },
                    set: { nav.screen = [.tasks, .skills, .history, .settings][$0] }
                )
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(Theme.paper)
    }
}

/// "Thursday's notes · 6 November · 3 tickets on the go"
enum Notes {
    static var title: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return "\(f.string(from: Date()))'s notes"
    }

    @MainActor
    static func subtitle(_ model: AppModel) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM"
        let active = model.tasks.filter { $0.ticketId != nil && Date().timeIntervalSince($0.lastActivity) < 3 * 86_400 }.count
        return "\(f.string(from: Date())) · \(active) ticket\(active == 1 ? "" : "s") on the go"
    }
}

/// Text tabs with a pencil underline. Used in the popover and on the Skills page.
struct UnderlineTabs: View {
    let titles: [String]
    var badges: [Int?] = []
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 18) {
            ForEach(titles.indices, id: \.self) { i in
                Button {
                    selection = i
                } label: {
                    HStack(spacing: 5) {
                        Text(titles[i]).font(.serif(13.5, selection == i ? .bold : .regular))
                        if i < badges.count, let b = badges[i] { DueBadge(count: b) }
                    }
                    .foregroundStyle(selection == i ? Theme.ink : Theme.inkMuted)
                    .padding(.bottom, 5)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(selection == i ? Theme.pencil : .clear).frame(height: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.cardStroke).frame(height: 1) }
    }
}

/// Small pencil-red count for things that are due.
struct DueBadge: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.system(size: 9.5, weight: .heavy))
            .foregroundStyle(Theme.paperRaised)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Rectangle().fill(Theme.pencil))
    }
}

// MARK: - Notes (home)

struct TaskListView: View {
    @EnvironmentObject var model: AppModel
    @State private var showAll = false
    @State private var showOther = false

    private let collapsedCount = 6
    private var tickets: [TaskItem] { model.tasks.filter { $0.ticketId != nil } }
    private var other: [TaskItem] { model.tasks.filter { $0.ticketId == nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let error = model.lastError {
                    ErrorBanner(text: error) { model.lastError = nil }
                        .padding(.bottom, 12)
                }

                if model.tasks.isEmpty {
                    EmptyState(scanning: model.scanning, days: model.state.lookbackDays)
                } else {
                    UpNextCard().padding(.top, 6)

                    if !tickets.isEmpty {
                        SectionHeader(title: "This week", count: tickets.count)
                            .padding(.top, 22)
                            .padding(.bottom, 2)
                        ForEach(showAll ? tickets : Array(tickets.prefix(collapsedCount))) { TaskRow(task: $0) }
                        if tickets.count > collapsedCount {
                            DisclosureLink(title: showAll ? "Show fewer" : "Show all \(tickets.count)", open: showAll) {
                                showAll.toggle()
                            }
                        }
                    }

                    if !other.isEmpty {
                        DisclosureLink(title: "\(other.count) session\(other.count == 1 ? "" : "s") without a ticket", open: showOther) {
                            showOther.toggle()
                        }
                        if showOther {
                            ForEach(other) { TaskRow(task: $0) }
                        }
                    }

                    ChaptersStrip().padding(.top, 20)
                    KnownShelf().padding(.top, 20)
                }

                if let status = model.linearStatus {
                    Label(status, systemImage: "link").font(.caption).foregroundStyle(Theme.inkMuted).padding(.top, 14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

private struct DisclosureLink: View {
    let title: String
    let open: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(open ? 90 : 0))
                Text(title).font(.serif(12.5)).italic()
            }
            .foregroundStyle(Theme.inkMuted)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The single next thing to do, in priority order: today's pulse question, due reviews,
/// a quiz that's already written, and otherwise a recap across recent tasks.
struct UpNextCard: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var nav: Navigator

    private enum Mode { case pulse(Quiz), review(Int), ready(Quiz), recap }

    /// Written quizzes for tickets, newest first (pulse and review are handled separately).
    private var waiting: [Quiz] {
        model.state.readyQuizzes.values
            .filter { $0.taskKey != "pulse" && $0.taskKey != "review" }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var mode: Mode {
        if let pulse = model.readyQuiz(key: "pulse") { return .pulse(pulse) }
        let due = model.dueReviews.count
        if due > 0 { return .review(due) }
        if let first = waiting.first { return .ready(first) }
        return .recap
    }

    private var busy: Bool { model.generating.contains("daily") }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.serif(15, .bold))
                    Text(subtitle).font(.serif(13)).foregroundStyle(Theme.inkMuted).lineLimit(2)
                }
                Spacer(minLength: 8)
                Button(action: start) {
                    if busy {
                        HStack(spacing: 6) { ProgressView().controlSize(.mini).tint(Theme.paperRaised); Text("Writing") }
                    } else {
                        Text("Begin")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .allowsHitTesting(!busy)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Rectangle().fill(Theme.paperRaised))
            .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: 1.5))
            .rotationEffect(.degrees(-0.4))

            if !alsoWaiting.isEmpty {
                HStack(spacing: 6) {
                    Text("Also waiting:").italic().foregroundStyle(Theme.inkMuted)
                    ForEach(alsoWaiting) { q in
                        Button(label(for: q)) { nav.open(q) }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.pencil)
                            .underline()
                    }
                }
                .font(.serif(12.5))
                .padding(.leading, 2)
            }
        }
    }

    /// Other written quizzes, so nothing is hidden, without competing with the main action.
    private var alsoWaiting: [Quiz] {
        var list = waiting
        if case .ready(let shown) = mode { list.removeAll { $0.id == shown.id } }
        return Array(list.prefix(2))
    }

    private func label(for q: Quiz) -> String {
        let id = model.tasks.first { $0.key == q.taskKey }?.ticketId ?? "Recap"
        return "\(id) (\(q.questions.count))"
    }

    private var title: String {
        switch mode {
        case .pulse: return "Today's question"
        case .review(let n): return n == 1 ? "One question is back for review" : "\(n) questions are back for review"
        case .ready(let q): return "A quiz is ready on \(model.tasks.first { $0.key == q.taskKey }?.ticketId ?? q.title)"
        case .recap: return "Recap your week"
        }
    }

    private var subtitle: String {
        if busy { return "writing your questions, about 30 seconds…" }
        switch mode {
        case .pulse(let q): return q.questions.first?.prompt ?? "one question"
        case .review: return "things you missed or guessed before · a minute, no waiting"
        case .ready(let q): return "\(q.questions.count) questions on \(q.title)"
        case .recap: return "questions across your most recent tasks"
        }
    }

    private func start() {
        switch mode {
        case .pulse(let q), .ready(let q): nav.open(q)
        case .review: if let q = model.reviewQuiz() { nav.open(q) }
        case .recap: Task { if let q = await model.dailyRecap() { nav.open(q) } }
        }
    }
}

/// One ticket as a notebook entry. The Quiz button only shows on hover, so the page stays quiet.
struct TaskRow: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var nav: Navigator
    let task: TaskItem
    @State private var hovering = false

    private var ready: Bool { model.state.readyQuizzes[task.key] != nil }
    private var busy: Bool { model.generating.contains(task.key) }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(task.ticketId ?? "session")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.inkFaint)
                .frame(width: 72, alignment: .leading)
            (Text(task.title) + Text(ready ? "  · quiz ready" : "").foregroundColor(Theme.good))
                .font(.serif(14))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            trailing
        }
        .frame(height: 28)
        .padding(.horizontal, 4)
        .background(Rectangle().fill(Theme.ink.opacity(hovering ? 0.04 : 0)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    @ViewBuilder
    private var trailing: some View {
        if busy {
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text("writing…").font(.serif(12)).italic().foregroundStyle(Theme.inkMuted)
            }
        } else if hovering {
            Button {
                Task { if let q = await model.quiz(for: task) { nav.open(q) } }
            } label: {
                Text(ready ? "Start" : "Quiz me")
            }
            .buttonStyle(PrimaryButtonStyle(compact: true))
        } else {
            Text(relative).font(.serif(12)).italic().foregroundStyle(Theme.inkFaint)
        }
    }

    private var relative: String {
        guard task.lastActivity != .distantPast else { return "no sessions" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: task.lastActivity, relativeTo: Date())
    }
}

/// Three skills at a glance: your two focus skills and your strongest, as chapters I to V.
struct ChaptersStrip: View {
    @EnvironmentObject var model: AppModel

    private var picks: [Skill] {
        let focus = Array(model.weakSkills.prefix(2))
        let strongest = Skill.allCases
            .filter { !focus.contains($0) }
            .max { model.knownCount($0) < model.knownCount($1) } ?? .readingCode
        return [strongest] + focus
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Chapters")
            HStack(alignment: .top, spacing: 12) {
                ForEach(picks) { skill in
                    let known = model.knownCount(skill)
                    let lv = Chapter.level(known: known)
                    VStack(alignment: .leading, spacing: 3) {
                        Rectangle().fill(Theme.ink).frame(height: 2)
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(roman(lv)).font(.serif(24, .bold))
                            Text(model.weakSkills.prefix(2).contains(skill) ? "focus" : "of V")
                                .font(.serif(11.5)).italic().foregroundStyle(Theme.inkMuted)
                        }
                        Text(skill.title).font(.serif(12.5)).lineLimit(1)
                        Dots(filled: lv, total: 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// The shelf of things you know cold, as index cards.
struct KnownShelf: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Known cold", count: model.state.knownCold.count)
            if model.state.knownCold.isEmpty {
                Text("Answer right, and sure, and it lands here as an index card.")
                    .font(.serif(13)).foregroundStyle(Theme.inkMuted)
            } else {
                FlowRow(spacing: 8) {
                    ForEach(Array(model.state.knownCold.suffix(4).reversed().enumerated()), id: \.element.id) { i, item in
                        IndexCard(text: item.text, tilt: [0.6, -1, 0.3, -0.5][i % 4])
                    }
                }
            }
        }
    }
}

/// Wraps children onto new lines, like cards pinned along a shelf.
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    var maxItemWidth: CGFloat = 210

    private func measure(_ s: LayoutSubview) -> CGSize {
        let ideal = s.sizeThatFits(.unspecified)
        return ideal.width <= maxItemWidth ? ideal : s.sizeThatFits(ProposedViewSize(width: maxItemWidth, height: nil))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let size = measure(s)
            if x + size.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = measure(s)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}

private struct EmptyState: View {
    let scanning: Bool
    let days: Int

    var body: some View {
        VStack(spacing: 8) {
            Text(scanning ? "Reading your Claude sessions…" : "A blank page")
                .font(.serif(18, .bold))
            Text(scanning ? "" : "No Claude sessions in the last \(days) days. Tasks appear here as you work on tickets with Claude.")
                .font(.serif(13.5)).foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}

struct ErrorBanner: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.pencil)
            Text(text)
                .font(.serif(12.5))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(action: dismiss) { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkMuted)
        }
        .padding(10)
        .background(Rectangle().fill(Theme.paperRaised))
        .overlay(Rectangle().strokeBorder(Theme.pencil.opacity(0.6)))
    }
}
