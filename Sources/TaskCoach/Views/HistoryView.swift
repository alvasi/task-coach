import SwiftUI

/// Your last answers, grouped by ticket. Each row opens to show what you said, what was right,
/// and the line from your session that proves it.
struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    /// Snapshot renderer only: show the first row opened.
    nonisolated(unsafe) static var openFirst = false

    /// Groups in order of their most recent answer.
    private var groups: [(key: String, records: [AnswerRecord])] {
        var order: [String] = []
        var byKey: [String: [AnswerRecord]] = [:]
        for r in model.state.history {
            if byKey[r.taskKey] == nil { order.append(r.taskKey) }
            byKey[r.taskKey, default: []].append(r)
        }
        return order.map { ($0, byKey[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if model.state.history.isEmpty {
                    Text("Nothing yet. Answers you give from now on appear here, newest first.")
                        .font(.serif(14)).foregroundStyle(Theme.inkMuted)
                        .padding(.top, 8)
                } else {
                    ForEach(groups, id: \.key) { group in
                        groupHeader(group.key).padding(.top, 14).padding(.bottom, 2)
                        ForEach(group.records) { r in
                            HistoryRow(record: r, startOpen: Self.openFirst && r.id == model.state.history.first?.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func groupHeader(_ key: String) -> some View {
        let task = model.tasks.first { $0.key == key }
        let label: String = {
            switch key {
            case "daily": return "Daily recap"
            case "pulse": return "Daily pulse"
            case "review": return "Review"
            default: return task?.title ?? (key.hasPrefix("session:") ? "Session" : key)
            }
        }()
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let id = task?.ticketId {
                Text(id).font(.system(size: 10.5, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.inkFaint)
            }
            Text(label).font(.serif(14, .bold)).lineLimit(1)
            Spacer()
        }
    }
}

private struct HistoryRow: View {
    @EnvironmentObject var model: AppModel
    let record: AnswerRecord
    @State private var open: Bool

    init(record: AnswerRecord, startOpen: Bool = false) {
        self.record = record
        _open = State(initialValue: startOpen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { open.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(record.reported ? Theme.inkFaint : Theme.scoreColor(record.points))
                        .frame(width: 14)
                    Text(record.question.prompt)
                        .font(.serif(14))
                        .lineLimit(open ? nil : 1)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: open)
                        .strikethrough(record.reported, color: Theme.inkFaint)
                    Spacer(minLength: 8)
                    Text(record.date.formatted(.relative(presentation: .named)))
                        .font(.serif(12)).italic().foregroundStyle(Theme.inkFaint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open { details.padding(.leading, 23).transition(.opacity) }
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.cardStroke).frame(height: 1) }
    }

    @ViewBuilder
    private var details: some View {
        let q = record.question
        VStack(alignment: .leading, spacing: 6) {
            line("You said", record.yourAnswer.isEmpty ? "–" : record.yourAnswer,
                 color: record.points == 2 ? Theme.good : Theme.ink)
            if let choices = q.choices, let i = q.answerIndex, choices.indices.contains(i), record.points < 2 {
                line("Right answer", choices[i], color: Theme.good)
            } else if q.kind == .explain, let m = q.modelAnswer {
                line("A strong answer covers", m, color: Theme.ink)
            }
            if let fb = record.feedback { line("Feedback", fb, color: Theme.inkMuted) }
            if let quote = q.evidence, !quote.isEmpty {
                line("From your session", "“\(quote)”", color: Theme.inkMuted)
            }
            HStack(spacing: 10) {
                Text("\(q.skill.title) · you said \(record.confidence.title.lowercased())")
                    .font(.serif(12)).italic().foregroundStyle(Theme.inkFaint)
                Spacer()
                if record.reported {
                    Text("reported as wrong").font(.serif(12)).italic().foregroundStyle(Theme.inkFaint)
                } else {
                    Button("This answer is wrong") {
                        model.reportWrong(question: q, points: record.points, confidence: record.confidence,
                                          outcome: nil, taskKey: record.taskKey)
                    }
                    .buttonStyle(.plain)
                    .font(.serif(12)).underline()
                    .foregroundStyle(Theme.inkMuted)
                }
            }
        }
    }

    private func line(_ label: String, _ text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased()).font(.label).tracking(1).foregroundStyle(Theme.pencil)
            Text(text).font(.serif(13.5)).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var icon: String {
        if record.reported { return "minus" }
        switch record.points {
        case 2: return "checkmark"
        case 1: return "circle.lefthalf.filled"
        default: return "xmark"
        }
    }
}
