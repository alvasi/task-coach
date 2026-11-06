import AppKit
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var window: NSWindow?
    private let model = AppModel()
    // The popover and the window each keep their own place, so one never hijacks the other.
    private let popoverNav = Navigator()
    private let windowNav = Navigator()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(ready: false)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 440, height: 600)
        popover.contentViewController = NSHostingController(
            rootView: RootView(openWindow: { [weak self] in self?.showWindow() })
                .environmentObject(model)
                .environmentObject(popoverNav)
        )

        model.onReadyChange = { [weak self] ready in self?.setIcon(ready: ready) }
        model.$state
            .map { ($0.showInMenuBar, $0.showInDock) }
            .removeDuplicates(by: ==)
            .sink { [weak self] menuBar, dock in self?.applyPresence(menuBar: menuBar, dock: dock) }
            .store(in: &cancellables)
        model.$state
            .map(\.appearance)
            .removeDuplicates()
            .sink { [weak self] in self?.applyAppearance($0) }
            .store(in: &cancellables)
        UNUserNotificationCenter.current().delegate = self
        model.start()

        // Opening the app shows the window; starting at login stays quietly in the menu bar.
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAtLogin { showWindow() }
    }

    // Closing the window keeps the menu bar icon running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // Clicking the Dock icon brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    // MARK: Appearance

    private func applyAppearance(_ mode: String) {
        let appearance: NSAppearance? = switch mode {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil  // follow the system
        }
        NSApp.appearance = appearance
        popover.appearance = appearance
    }

    // MARK: Menu bar and Dock

    /// Settings decide whether we show a menu bar icon, a Dock icon, or both.
    private func applyPresence(menuBar: Bool, dock: Bool) {
        // Belt and braces: Settings already stops both being off, but never strand the user.
        let showMenuBar = menuBar || !dock
        statusItem.isVisible = showMenuBar
        if !showMenuBar { popover.performClose(nil) }

        let policy: NSApplication.ActivationPolicy = dock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        // Switching policy can drop our window behind other apps; bring it back if it's open.
        if window?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        }
    }

    private func setIcon(ready: Bool) {
        let name = ready ? "graduationcap.fill" : "graduationcap"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Task Coach")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    private func showPopover() {
        // With the menu bar icon hidden there's nothing to anchor to; use the window.
        guard statusItem.isVisible, let button = statusItem.button else { return showWindow() }
        // Text fields only take typing once the app is active.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: Window

    @objc func showWindow() {
        popover.performClose(nil)
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 700),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Task Coach"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.minSize = NSSize(width: 820, height: 600)
            w.contentViewController = NSHostingController(
                rootView: MainWindowView().environmentObject(model).environmentObject(windowNav)
            )
            w.delegate = self
            if !w.setFrameUsingName("TaskCoachMain") { w.center() }
            w.setFrameAutosaveName("TaskCoachMain")
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Task Coach", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Task Coach", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Task Coach", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        // Without an Edit menu, ⌘C / ⌘V / ⌘A don't reach text fields.
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        let open = windowMenu.addItem(withTitle: "Task Coach", action: #selector(showWindow), keyEquivalent: "0")
        open.target = self
        windowMenu.addItem(withTitle: "Minimise", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        return main
    }

    // MARK: Notifications

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let quizKey = info["quizKey"] as? String
        let taskKey = info["taskKey"] as? String
        Task { @MainActor in
            // Open where you're already looking: the window if it's up, otherwise the popover.
            let useWindow = self.window?.isVisible == true || !self.model.state.showInMenuBar
            let nav = useWindow ? self.windowNav : self.popoverNav
            useWindow ? self.showWindow() : self.showPopover()
            completionHandler()
            if let quizKey, let quiz = self.model.readyQuiz(key: quizKey) {
                nav.open(quiz)
            } else if let taskKey, let quiz = await self.model.quiz(forTaskKey: taskKey) {
                // Session nudges don't pre-write a quiz; write it now that you've asked for it.
                nav.open(quiz)
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
