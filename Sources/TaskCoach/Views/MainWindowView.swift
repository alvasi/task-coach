import AppKit
import SwiftUI

/// The full window: a sidebar on the left, the current page on the right.
struct MainWindowView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var nav: Navigator

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 210)
                .background(Theme.sidebar.ignoresSafeArea())
            Rectangle().fill(Theme.cardStroke).frame(width: 1).ignoresSafeArea()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RuledPaper().ignoresSafeArea())
        }
        .frame(minWidth: 820, minHeight: 600)
        .foregroundStyle(Theme.ink)
        .tint(Theme.pencil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: nav.screen)
    }

    @ViewBuilder
    private var detail: some View {
        if case .quiz = nav.screen, let quiz = nav.activeQuiz {
            QuizView(quiz: quiz)
                .id(quiz.id)
                .frame(maxWidth: 680)
                .padding(.top, 28)
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            VStack(spacing: 0) {
                PageHeader(title: title, subtitle: subtitle, showStamp: nav.screen == .tasks)
                Group {
                    switch nav.screen {
                    case .skills: SkillsView()
                    case .history: HistoryView()
                    case .settings: SettingsView()
                    default: TaskListView()
                    }
                }
            }
            .frame(maxWidth: nav.screen == .settings ? 600 : 700)
            // The notebook's red margin line, just left of the text column.
            .background(alignment: .leading) {
                Rectangle().fill(Theme.marginLine.opacity(0.7)).frame(width: 1).offset(x: -4).ignoresSafeArea()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var title: String {
        switch nav.screen {
        case .skills: return "Skills"
        case .history: return "Past answers"
        case .settings: return "Settings"
        default: return Notes.title
        }
    }

    private var subtitle: String {
        switch nav.screen {
        case .history: return "Your last \(AnswerRecord.keep) answers, newest first."
        case .skills: return "Every question trains one of these. Quizzes lean toward the shakiest."
        case .settings: return "When to nudge you, and how quizzes get written."
        default: return Notes.subtitle(model)
        }
    }
}

private struct PageHeader: View {
    @EnvironmentObject var model: AppModel
    let title: String
    let subtitle: String
    var showStamp = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.serif(26, .bold))
                Text(subtitle).font(.serif(13.5)).italic().foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            if showStamp, let m = model.recentMilestone {
                Stamp(text: m.title).frame(maxWidth: 170).help(m.detail).padding(.trailing, 10)
            }
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(IconButtonStyle())
            .help("Rescan your Claude sessions")
            .disabled(model.scanning)
        }
        .padding(.horizontal, 16)
        .padding(.top, 40)
        .padding(.bottom, 14)
    }
}

private struct Sidebar: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var nav: Navigator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                AppMark(size: 26)
                Text("Task Coach").font(.serif(15, .bold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 44)
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 2) {
                item("Notes", screen: .tasks, badge: nil)
                item("Skills", screen: .skills, badge: model.dueReviews.count)
                item("Past answers", screen: .history, badge: nil)
                item("Settings", screen: .settings, badge: nil)
            }
            .padding(.horizontal, 8)

            Spacer()

            if model.generating.isEmpty == false {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("writing a quiz…").font(.serif(12)).italic().foregroundStyle(Theme.inkMuted)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .foregroundStyle(Theme.ink)
    }

    private func item(_ title: String, screen: Screen, badge: Int?) -> some View {
        let selected = nav.screen == screen || (screen == .tasks && nav.activeQuiz != nil)
        return Button {
            nav.activeQuiz = nil
            nav.screen = screen
        } label: {
            HStack(spacing: 8) {
                Rectangle().fill(selected ? Theme.pencil : .clear).frame(width: 2, height: 16)
                Text(title).font(.serif(14.5, selected ? .bold : .regular))
                    .foregroundStyle(selected ? Theme.ink : Theme.inkMuted)
                Spacer()
                if let badge, badge > 0 { DueBadge(count: badge).help("Due for review") }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The gradient tile with the cap, used in the sidebar, popover and app icon.
struct AppMark: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.pencil)
            Image(systemName: "graduationcap.fill")
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

/// Large version for the Dock / Finder icon, drawn on Apple's 1024 grid (824pt tile).
struct AppIconArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(Theme.brandGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 400, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
                .offset(y: -10)
        }
        .frame(width: 1024, height: 1024)
    }
}

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
