import SwiftUI

struct SkillsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var nav: Navigator
    @State private var tab = 0
    @State private var openSkill: Skill? = SkillsView.openForSnapshot
    /// Snapshot renderer only: open this skill's page.
    nonisolated(unsafe) static var openForSnapshot: Skill?

    var body: some View {
        if let skill = openSkill {
            SkillDetail(skill: skill) { withAnimation(.easeInOut(duration: 0.2)) { openSkill = nil } }
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            tabs
        }
    }

    private var tabs: some View {
        VStack(spacing: 0) {
            UnderlineTabs(titles: ["Chapters", "Known cold", "Calibration", "Review"],
                          badges: [nil, nil, nil, model.dueReviews.count > 0 ? model.dueReviews.count : nil],
                          selection: $tab)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch tab {
                    case 1: knownTab
                    case 2: CalibrationNote(calibration: model.state.calibration,
                                            confidentErrors: model.state.reviews.filter(\.confidentError).count)
                    case 3: reviewTab
                    default: chaptersTab
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: Chapters

    private var chaptersTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            (Text("Focus next: ").foregroundColor(Theme.inkMuted)
             + Text(model.weakSkills.prefix(2).map(\.title).joined(separator: " and ")).bold())
                .font(.serif(14))
            Text("Your two weakest skills. Normal quizzes lean towards them; click any skill to practise it directly.")
                .font(.serif(12.5)).foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)
            ForEach(Skill.allCases) { skill in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { openSkill = skill }
                } label: {
                    ChapterRow(skill: skill, known: model.knownCount(skill),
                               stat: model.state.skillStats[skill.rawValue] ?? SkillStat(),
                               focus: model.weakSkills.prefix(2).contains(skill))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverHighlight()
            }
            Text("A skill moves up a chapter as things become known cold: answered right and sure, or recalled three times, days apart.")
                .font(.serif(13)).foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
    }

    // MARK: Known cold

    @ViewBuilder
    private var knownTab: some View {
        let items = model.state.knownCold
        if items.isEmpty {
            Text("Nothing here yet. Answer right, and sure, and it lands on this shelf as an index card.")
                .font(.serif(14)).foregroundStyle(Theme.inkMuted)
        } else {
            Text("\(items.count) thing\(items.count == 1 ? "" : "s") you can explain without notes.")
                .font(.serif(14)).foregroundStyle(Theme.inkMuted)
            FlowRow(spacing: 10, maxItemWidth: 220) {
                ForEach(Array(items.reversed().enumerated()), id: \.element.id) { i, item in
                    IndexCard(text: item.text, tilt: [0.6, -0.9, 0.3, -0.4, 0.8][i % 5])
                        .help("\(item.skill.title) · \(item.date.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .padding(.vertical, 4)
        }

        SectionHeader(title: "Milestones", count: model.state.milestones.count).padding(.top, 16)
        ForEach(Milestone.allCases, id: \.rawValue) { m in
            let earned = model.state.milestones[m.rawValue]
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: earned == nil ? "seal" : "seal.fill")
                    .foregroundStyle(earned == nil ? Theme.inkFaint : Theme.pencil)
                VStack(alignment: .leading, spacing: 1) {
                    Text(m.title).font(.serif(14, earned == nil ? .regular : .bold))
                        .foregroundStyle(earned == nil ? Theme.inkMuted : Theme.ink)
                    Text(m.detail).font(.serif(12)).italic().foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                if let earned {
                    Text(earned.formatted(date: .abbreviated, time: .omitted))
                        .font(.serif(12)).italic().foregroundStyle(Theme.inkMuted)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Review

    @ViewBuilder
    private var reviewTab: some View {
        let due = model.dueReviews.count
        HStack {
            Text(due > 0 ? "\(due) due now" : "Nothing due right now")
                .font(.serif(15, .bold))
            Spacer()
            if due > 0 {
                Button("Begin review") { if let q = model.reviewQuiz() { nav.open(q) } }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
            }
        }
        if model.state.reviews.isEmpty {
            Text("Questions you miss or guess land here and come back 1, 3 and 7 days later.")
                .font(.serif(13.5)).foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ReviewQueueList(items: model.state.reviews)
        }
    }
}

/// One skill: its chapter in roman numerals, dots, and how close the next chapter is.
private struct ChapterRow: View {
    let skill: Skill
    let known: Int
    let stat: SkillStat
    let focus: Bool

    var body: some View {
        let lv = Chapter.level(known: known)
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(roman(lv))
                .font(.serif(20, .bold))
                .frame(width: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(skill.title).font(.serif(14.5))
                    if focus { Chip(text: "FOCUS") }
                }
                Text(skill.blurb).font(.serif(12.5)).foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Dots(filled: lv, total: 5)
                Text(nextLabel(lv)).font(.serif(11.5)).italic().foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.cardStroke).frame(height: 1) }
        .help("\(stat.attempts) answered · \(known) known cold")
    }

    private func nextLabel(_ lv: Int) -> String {
        if stat.attempts == 0 { return "not tried yet" }
        guard let n = Chapter.toNext(known: known) else { return "mastered" }
        return "\(n) more for \(roman(lv + 1))"
    }
}

/// How often you're right at each confidence level, said in words.
private struct CalibrationNote: View {
    let calibration: [String: SkillStat]
    let confidentErrors: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When you said…").font(.serif(15, .bold))
            ForEach(Confidence.allCases) { c in
                let stat = calibration[c.rawValue] ?? SkillStat()
                HStack(spacing: 12) {
                    Text("“\(c.title.lowercased())”").font(.serif(14)).italic().frame(width: 96, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Theme.rule)
                            Rectangle().fill(c == .certain ? Theme.pencil : Theme.inkMuted)
                                .frame(width: geo.size.width * (stat.ratio ?? 0))
                        }
                    }
                    .frame(height: 6)
                    Text(stat.ratio.map { "right \(Int(($0 * 100).rounded()))% of the time" } ?? "no answers yet")
                        .font(.serif(12.5)).italic().foregroundStyle(Theme.inkMuted)
                        .frame(width: 150, alignment: .trailing)
                }
            }
            Text(confidentErrors > 0
                 ? "\(confidentErrors) mistake\(confidentErrors == 1 ? "" : "s") you were certain about. These come back first."
                 : "Well calibrated means “certain” is nearly always right. If it isn't, slow down before trusting your gut.")
                .font(.serif(13)).foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ReviewQueueList: View {
    let items: [ReviewItem]

    private var sorted: [ReviewItem] { items.sorted { $0.due < $1.due } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sorted.prefix(10)) { item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: item.question.skill.symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(item.question.skill.color)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.question.prompt).font(.serif(14)).lineLimit(2)
                        HStack(spacing: 8) {
                            Dots(filled: item.streak, total: ReviewItem.retireAfter, color: Theme.good)
                            Text(dueLabel(item)).font(.serif(12)).italic().foregroundStyle(Theme.inkMuted)
                            if item.confidentError { Chip(text: "WERE CERTAIN") }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.cardStroke).frame(height: 1) }
            }
            Text("Each retires after 3 correct answers, spaced 1, 3 and 7 days apart. A miss starts it again.")
                .font(.serif(13)).foregroundStyle(Theme.inkMuted)
                .padding(.top, 12)
        }
    }

    private func dueLabel(_ item: ReviewItem) -> String {
        if item.due <= Date() { return "due now" }
        return "due " + RelativeDateTimeFormatter().localizedString(for: item.due, relativeTo: Date())
    }
}

/// One skill up close: practise it, clear its due reviews, and see its playbook practices.
private struct SkillDetail: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var nav: Navigator
    let skill: Skill
    let back: () -> Void

    private var key: String { "skill:\(skill.rawValue)" }
    private var busy: Bool { model.generating.contains(key) }
    private var known: Int { model.knownCount(skill) }
    private var practices: [PlaybookEntry] { model.playbook.filter { $0.skill == skill } }
    private var knownTexts: Set<String> { Set(model.state.knownCold.map { $0.text }) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: back) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                        Text("All skills").font(.serif(13))
                    }
                    .foregroundStyle(Theme.inkMuted)
                }
                .buttonStyle(.plain)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(roman(Chapter.level(known: known))).font(.serif(30, .bold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(skill.title).font(.serif(18, .bold))
                        Text(skill.blurb).font(.serif(13)).foregroundStyle(Theme.inkMuted)
                    }
                    Spacer()
                    Dots(filled: Chapter.level(known: known), total: 5)
                }
                Text(Chapter.toNext(known: known).map { "\(known) known cold · \($0) more for chapter \(roman(Chapter.level(known: known) + 1))" }
                     ?? "\(known) known cold · mastered")
                    .font(.serif(13)).foregroundStyle(Theme.inkMuted)

                // The one action this page is for.
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Practise this skill").font(.serif(15, .bold))
                        Text(busy ? "Writing 3 questions, about 20 seconds…"
                                  : "3 questions, from your recent work where it fits")
                            .font(.serif(13)).foregroundStyle(Theme.inkMuted)
                    }
                    Spacer()
                    Button {
                        Task { if let q = await model.practise(skill) { nav.open(q) } }
                    } label: {
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

                let due = model.dueReviews(for: skill).count
                if due > 0 {
                    HStack {
                        Text("\(due) review question\(due == 1 ? "" : "s") due in this skill").font(.serif(14))
                        Spacer()
                        Button("Review now") { if let q = model.reviewQuiz(for: skill) { nav.open(q) } }
                            .buttonStyle(SoftButtonStyle())
                    }
                }

                SectionHeader(title: "Practices in this skill", count: practices.count).padding(.top, 6)
                ForEach(practices) { p in
                    let isKnown = knownTexts.contains(p.rule)
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Image(systemName: isKnown ? "checkmark.square.fill" : "square")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isKnown ? Theme.good : Theme.inkFaint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.rule).font(.serif(14)).fixedSize(horizontal: false, vertical: true)
                            Text(p.source).font(.serif(12)).foregroundStyle(Theme.inkMuted)
                        }
                    }
                    .padding(.vertical, 4)
                    .help(p.why)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
