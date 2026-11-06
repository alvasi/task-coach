# Task Coach

A macOS app that quizzes you on the work you're doing with AI coding agents, so you keep a clear
picture of your own tasks and build general software engineering skill while you do it.

It's built for engineers who let an agent like Claude Code do much of the work and only skim along.
Task Coach reads your recent sessions, writes short quizzes about them, and uses each piece of work as
an example of a wider practice from a fact-checked playbook.

## What it does

- **Quizzes on your real work.** Each quiz is a chain of three: a question about your ticket, then the
  general practice it shows, then that practice in an unrelated scenario. Answers about your work must
  quote your session, and the app throws away any question whose quote isn't really there.
- **Teaches best practice, not just what your code did.** Every practice comes from a public source
  (Google's engineering practices and SRE books, Martin Fowler, OWASP, SOLID, the AWS Builders'
  Library and more). See [`playbook.md`](playbook.md); you can edit your own copy.
- **Built on learning research.** Three-question sittings, confidence ratings before each reveal,
  a review queue spaced 1, 3 and 7 days apart, and per-skill practice across ten SDLC skills.
- **Lives in the menu bar and as a window,** with a field-notebook look, light and dark.

## Requirements

- macOS 14 or later, on Apple silicon or Intel
- [Claude Code](https://claude.com/claude-code), logged in. Task Coach reads its session history and
  uses the `claude` CLI to write and grade questions, so it counts against your Claude plan.
- Optional: a Linear personal API key, to see assigned tickets you haven't started in Claude yet.

## Install

```bash
curl -fsSL https://alvasi.github.io/task-coach/install.sh | bash
```

[The installer](docs/install.sh) downloads the latest release, checks its checksum and that it's signed
with Task Coach's own certificate, then puts it in `~/Applications` and opens it. Run it again to update.

Other ways:

- **Download** `TaskCoach.zip` from [Releases](https://github.com/alvasi/task-coach/releases/latest).
  macOS blocks apps downloaded in a browser until you allow them once: try to open it, then go to
  System Settings › Privacy & Security and click Open Anyway.
- **Build from source** with the Xcode Command Line Tools (`xcode-select --install`):
  `git clone https://github.com/alvasi/task-coach.git && cd task-coach && scripts/build-app.sh --install`

Releases are signed with the project's own certificate, not an Apple Developer ID, so they aren't
notarised. That keeps the app's identity stable across updates; you're trusting this repo.

If quizzes fail with a login error, run `claude` in Terminal and type `/login`.

## Privacy

- Everything is stored locally in `~/Library/Application Support/TaskCoach/`.
- To write a quiz, a condensed copy of your recent sessions is sent to Claude through your own
  `claude` CLI, the same way Claude Code itself works. Nothing else leaves your Mac.
- The Linear key, if you add one, is kept in your login Keychain.
- Questions are told never to include customer names, contact details or end-user message content.

## How it works

1. It scans `~/.claude/projects` for sessions from the last 7 days and groups them by ticket
   (from Linear links, `get_issue` calls, or the branch name).
2. When you start a quiz it sends a condensed transcript, the playbook, and your weakest skills to
   `claude -p` (no tools, nothing saved as a session) and asks for one chain of three questions.
3. Explain-in-your-own-words answers are graded by a second, small call.
4. Missed or guessed questions go into a review queue. Things you answer right and sure become
   "known cold" cards, which move each skill through chapters I to V.

## Development

```bash
swift build
./scripts/build-app.sh            # builds build/TaskCoach.app
./scripts/build-app.sh --install  # also copies it to ~/Applications
```

Debug helpers (after `swift build`):

- `.build/debug/TaskCoach --scan` lists detected tasks.
- `.build/debug/TaskCoach --prompt ABC-123` prints the prompt a quiz would use.
- `.build/debug/TaskCoach --quiz ABC-123 --out quiz.json` writes a real quiz.
- `.build/debug/TaskCoach --practise testing` writes a focused quiz on one skill.
- `.build/debug/TaskCoach --snapshot ./snaps` renders every screen with placeholder data.

Token use per call is logged to `~/Library/Application Support/TaskCoach/usage.jsonl`.

## Releasing

1. Once: `scripts/make-signing-identity.sh`, then store the two secrets it prints on the repo.
2. Bump `VERSION`, add a section to `CHANGELOG.md`, commit, and push a tag `v<VERSION>`.
3. The release workflow builds a universal app, signs it, and publishes `TaskCoach.zip` with its checksum.

The project page is `docs/` on GitHub Pages; `.build/debug/TaskCoach --page-shots docs/img` renders its
screenshots.

## Licence

MIT. See [LICENSE](LICENSE).
