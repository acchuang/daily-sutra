import SwiftUI
import AppKit
import Combine
import ServiceManagement
import UserNotifications
import SutraKit
import QuartzCore

@main
struct DiamondSutraBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

enum AppLang: String, CaseIterable {
    case en, zh
    var label: String { self == .en ? "EN" : "中" }
}

/// What the panel is showing. A day resolves to a verse through DailyPick, so
/// prev/next move by real calendar days and the weekday shown matches the verse.
/// A favorite has no date of its own, so it is carried directly.
enum Showing: Equatable {
    case day(Date)
    case verse(Verse)
}

final class CardPanel: NSPanel {
    override var canBecomeKey: Bool { true }    // needed for text selection
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var viewModel: VerseViewModel?
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    deinit {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vm = VerseViewModel(verses: VerseStore.load())
        viewModel = vm

        let panel = CardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 560),
            styleMask: [.borderless, .resizable],
            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.minSize = NSSize(width: 320, height: 400)
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = !vm.attachToMenubar
        // Use NSHostingView as contentView (not contentViewController) so the
        // window keeps its 400x560 frame; a flexible SwiftUI frame inside a
        // contentViewController collapses to a 0 fitting size and renders blank.
        let hosting = NSHostingView(rootView: SutraView(viewModel: vm))
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.delegate = self
        self.panel = panel

        // Pin toggle: keep the panel open across focus loss while pinned.
        vm.$pinned
            .receive(on: RunLoop.main)
            .sink { [weak self] pinned in self?.panel?.hidesOnDeactivate = !pinned }
            .store(in: &cancellables)

        // Attach to menu bar toggle: lock under status item or enable dragging.
        vm.$attachToMenubar
            .receive(on: RunLoop.main)
            .sink { [weak self] attach in
                guard let self, let panel = self.panel else { return }
                panel.isMovableByWindowBackground = !attach
                if attach {
                    self.snapToMenubar(animate: true)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let vm = self.viewModel, vm.attachToMenubar, let panel = self.panel, panel.isVisible else { return }
                self.snapToMenubar(animate: false)
            }
            .store(in: &cancellables)

        // Intercept and close any phantom SwiftUI Settings window, routing to the in-panel settings card
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notif in
                guard let self, let win = notif.object as? NSWindow, win !== self.panel else { return }
                if win.title.localizedCaseInsensitiveContains("Settings") || win.title.localizedCaseInsensitiveContains("Preferences") {
                    win.orderOut(nil)
                    win.close()
                    self.openPanel()
                    self.viewModel?.showSettings = true
                }
            }
            .store(in: &cancellables)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for window in NSApp.windows where window !== self.panel {
                if window.title.localizedCaseInsensitiveContains("Settings") || window.title.localizedCaseInsensitiveContains("Preferences") {
                    window.orderOut(nil)
                    window.close()
                }
            }
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let url = Bundle.main.url(forResource: "MenubarIcon", withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                img.isTemplate = true          // transparent silhouette → auto light/dark
                // fit within the menu bar, preserving aspect (icon is not square)
                let maxDim: CGFloat = 22
                let maxSize = max(img.size.width, img.size.height)
                guard maxSize > 0 else {
                    button.image = NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: "Daily Sutra")
                    self.statusItem = item
                    return
                }
                let s = maxDim / maxSize
                img.size = NSSize(width: img.size.width * s, height: img.size.height * s)
                button.image = img
            } else {
                button.image = NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: "Daily Sutra")
            }
            button.action = #selector(togglePanel(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.statusItem = item

        NSApp.setActivationPolicy(.accessory)

        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            let code = ev.keyCode
            let mods = ev.modifierFlags
            let chars = ev.charactersIgnoringModifiers
            let swallow = MainActor.assumeIsolated {
                self?.handleKey(code: code, mods: mods, chars: chars) ?? false
            }
            return swallow ? nil : ev
        }
    }

    // Keyboard shortcuts while the panel is key: ← prev, → next, T today,
    // Esc close, ⌘C copy the full formatted verse (left to native selection
    // copy when text is selected). Returns true to swallow the event.
    @MainActor private func handleKey(code: UInt16, mods: NSEvent.ModifierFlags, chars: String?) -> Bool {
        guard let panel, panel.isKeyWindow, let vm = viewModel else { return false }
        let fr = panel.firstResponder
        let inControl = (fr is NSTextView) || (fr is NSControl)
        if code == 123, !inControl { vm.prev(); return true }    // ←
        if code == 124, !inControl { vm.next(); return true }    // →
        if code == 53 { panel.orderOut(nil); return true }       // Esc
        if mods.contains(.command), chars == "c" {
            // Defer to native copy only when the user has actually selected text;
            // otherwise copy the full formatted verse.
            if let tv = fr as? NSTextView, tv.selectedRange().length > 0 { return false }
            vm.copyFormatted(); return true
        }
        if !mods.contains(.command) && !mods.contains(.control) && !mods.contains(.option),
           chars == "t" {
            vm.reset(); return true
        }
        if mods.contains(.command), chars == "," {
            vm.toggleSettings(); return true
        }
        return false
    }

    @MainActor @objc func togglePanel(_ sender: Any?) {
        guard let panel else { return }
        // Right-click on the menu-bar icon → context menu (no toggle).
        if NSApp.currentEvent?.type == .rightMouseUp {
            if let button = statusItem?.button { showMenu(from: button) }
            return
        }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            openPanel()
        }
    }

    @MainActor private func openPanel() {
        guard let panel else { return }
        let isAttached = viewModel?.attachToMenubar ?? true
        if isAttached {
            snapToMenubar()
        } else {
            restoreSavedPositionOrSnap()
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor func snapToMenubar(animate: Bool = false) {
        guard let button = statusItem?.button, let panel else { return }
        guard let btnFrame = button.window?.convertToScreen(button.bounds) else { return }

        let screen = button.window?.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height

        // Horizontal centering beneath the status item icon, clamped to screen margins
        let desiredX = btnFrame.midX - (panelWidth / 2)
        let minX = visible.minX + 8
        let maxX = max(minX, visible.maxX - panelWidth - 8)
        let targetX = min(max(desiredX, minX), maxX)

        // Vertical anchoring: top edge sits directly below the menu bar
        let gap: CGFloat = 2
        let desiredTopY = btnFrame.minY - gap
        let maxTopY = visible.maxY - gap
        let targetTopY = min(desiredTopY, maxTopY)

        // Cocoa origin is bottom-left
        var targetOriginY = targetTopY - panelHeight
        if targetOriginY < visible.minY && panelHeight <= visible.height {
            targetOriginY = visible.minY + 8
        }

        let targetFrame = NSRect(x: targetX, y: targetOriginY, width: panelWidth, height: panelHeight)

        if animate && panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }

        if let vm = viewModel, !vm.attachToMenubar {
            UserDefaults.standard.set(panel.frame.origin.x, forKey: "CustomPanelOriginX")
            UserDefaults.standard.set(panel.frame.origin.y, forKey: "CustomPanelOriginY")
            UserDefaults.standard.set(true, forKey: "HasCustomPanelOrigin")
        }
    }

    @MainActor private func restoreSavedPositionOrSnap() {
        guard let panel else { return }
        if UserDefaults.standard.bool(forKey: "HasCustomPanelOrigin") {
            let x = UserDefaults.standard.double(forKey: "CustomPanelOriginX")
            let y = UserDefaults.standard.double(forKey: "CustomPanelOriginY")
            let savedPoint = NSPoint(x: x, y: y)
            let panelRect = NSRect(origin: savedPoint, size: panel.frame.size)
            let screens = NSScreen.screens
            let onScreen = screens.contains { $0.visibleFrame.intersects(panelRect) }
            if onScreen {
                panel.setFrameOrigin(savedPoint)
                return
            }
        }
        snapToMenubar(animate: false)
    }

    @MainActor func windowDidMove(_ notification: Notification) {
        guard let panel, let vm = viewModel, !vm.attachToMenubar else { return }
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: "CustomPanelOriginX")
        UserDefaults.standard.set(origin.y, forKey: "CustomPanelOriginY")
        UserDefaults.standard.set(true, forKey: "HasCustomPanelOrigin")
    }

    @MainActor func windowDidResize(_ notification: Notification) {
        guard let panel, let vm = viewModel, vm.attachToMenubar else { return }
        guard let button = statusItem?.button, let btnFrame = button.window?.convertToScreen(button.bounds) else { return }
        let screen = button.window?.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height

        let desiredX = btnFrame.midX - (panelWidth / 2)
        let minX = visible.minX + 8
        let maxX = max(minX, visible.maxX - panelWidth - 8)
        let targetX = min(max(desiredX, minX), maxX)

        let targetTopY = min(btnFrame.minY - 2, visible.maxY - 2)
        let targetOriginY = targetTopY - panelHeight
        panel.setFrameOrigin(NSPoint(x: targetX, y: targetOriginY))
    }

    // Right-click context menu on the menu-bar icon.
    @MainActor private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Verse", action: #selector(menuShowVerse(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy Today's Verse", action: #selector(menuCopyVerse(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        let isAttached = viewModel?.attachToMenubar ?? true
        let attachItem = NSMenuItem(title: "Attach to Menu Bar", action: #selector(menuToggleAttach(_:)), keyEquivalent: "")
        attachItem.state = isAttached ? .on : .off
        menu.addItem(attachItem)
        if !isAttached {
            menu.addItem(withTitle: "Snap to Menu Bar", action: #selector(menuSnapToMenubar(_:)), keyEquivalent: "")
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Daily Sutra", action: #selector(menuQuit(_:)), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        if let evt = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: evt, for: button)
        }
    }

    // Tapping the daily reminder opens the panel on today's verse.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            viewModel?.reset()
            openPanel()
        }
    }

    // The app is an accessory, but show the banner anyway if macOS considers it frontmost.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }

    @MainActor @objc func menuShowVerse(_ s: Any?) { openPanel() }
    @MainActor @objc func menuCopyVerse(_ s: Any?) { viewModel?.copyTodayVerse() }
    @MainActor @objc func menuToggleAttach(_ s: Any?) { viewModel?.toggleAttachToMenubar() }
    @MainActor @objc func menuSnapToMenubar(_ s: Any?) { snapToMenubar(animate: true) }
    @MainActor @objc func showSettingsWindow(_ s: Any?) {
        openPanel()
        viewModel?.showSettings = true
    }
    @MainActor @objc func showPreferencesWindow(_ s: Any?) {
        openPanel()
        viewModel?.showSettings = true
    }
    @objc func menuQuit(_ s: Any?) { NSApp.terminate(nil) }
}

@MainActor
final class VerseViewModel: ObservableObject {
    @Published var verses: [Verse]
    @Published var showing: Showing = .day(Date())
    @Published var lang: AppLang
    @Published var fontScale: Double
    @Published var launchAtLogin: Bool
    @Published var notifyEnabled: Bool
    @Published var notifyMinutes: Int       // minutes since local midnight
    @Published var favorites: Set<String>      // verse.id strings e.g. "diamond_1"
    @Published var showFavorites = false
    @Published var showHistory = false
    @Published var showSettings = false
    @Published var showShortcuts = false
    @Published var pinned = false      // keep panel open across focus loss
    @Published var showOnboarding = false
    @Published var notifyDeniedAlert = false
    @Published var copyFeedback = false
    @Published var warmPaper: Bool
    @Published var attachToMenubar: Bool

    private static let kLang = "AppLang", kScale = "FontScale", kFavs = "Favorites"
    private static let kNotify = "NotifyEnabled", kNotifyAt = "NotifyMinutes"
    private static let kOnboarded = "OnboardingCompleted", kWarmPaper = "WarmPaperTheme", kAttach = "AttachToMenubar"
    private static let defaultNotifyMinutes = 8 * 60
    private var rolloverTimer: Timer?
    private var currentDay: Int = 0

    init(verses: [Verse]) {
        self.verses = verses
        let saved = UserDefaults.standard.string(forKey: Self.kLang) ?? "en"
        self.lang = AppLang(rawValue: saved) ?? .en
        let raw = UserDefaults.standard.double(forKey: Self.kScale)
        self.fontScale = raw == 0 ? 1.0 : min(max(raw, 0.85), 1.8)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.notifyEnabled = UserDefaults.standard.bool(forKey: Self.kNotify)
        let savedMinutes = UserDefaults.standard.object(forKey: Self.kNotifyAt) as? Int
        self.notifyMinutes = savedMinutes ?? Self.defaultNotifyMinutes
        self.warmPaper = UserDefaults.standard.bool(forKey: Self.kWarmPaper)
        if UserDefaults.standard.object(forKey: Self.kAttach) == nil {
            self.attachToMenubar = true
        } else {
            self.attachToMenubar = UserDefaults.standard.bool(forKey: Self.kAttach)
        }
        if let data = UserDefaults.standard.data(forKey: Self.kFavs) {
            if let ids = try? JSONDecoder().decode([String].self, from: data) {
                self.favorites = Set(ids)
            } else if let legacyIndices = try? JSONDecoder().decode([Int].self, from: data) {
                // Migrate legacy integer array indices to stable IDs
                let ids = legacyIndices.compactMap { verses.indices.contains($0) ? verses[$0].id : nil }
                self.favorites = Set(ids)
                if let migrated = try? JSONEncoder().encode(Array(self.favorites)) {
                    UserDefaults.standard.set(migrated, forKey: Self.kFavs)
                }
            } else {
                self.favorites = []
            }
        } else {
            self.favorites = []
        }
        self.currentDay = Self.dayKey(Date())
        self.showOnboarding = !UserDefaults.standard.bool(forKey: Self.kOnboarded)
        startRollover()
        if notifyEnabled { refreshNotifications() }
    }

    func completeOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: Self.kOnboarded)
    }

    // MARK: - Daily reminder

    func toggleNotify() {
        if notifyEnabled {
            notifyEnabled = false
            UserDefaults.standard.set(false, forKey: Self.kNotify)
            DailyNotifier.cancelAll()
            return
        }
        Task {
            let granted = await DailyNotifier.requestAuthorization()
            notifyEnabled = granted
            UserDefaults.standard.set(granted, forKey: Self.kNotify)
            if granted {
                refreshNotifications()
            } else {
                notifyDeniedAlert = true
            }
        }
    }

    func setNotifyMinutes(_ m: Int) {
        notifyMinutes = min(max(m, 0), 24 * 60 - 1)
        UserDefaults.standard.set(notifyMinutes, forKey: Self.kNotifyAt)
        if notifyEnabled { refreshNotifications() }
    }

    /// Re-queues the reminder horizon. Called whenever anything the queued
    /// content depends on changes — language, time, the calendar day.
    private func refreshNotifications() {
        DailyNotifier.reschedule(verses: verses, text: text,
                                 hour: notifyMinutes / 60, minute: notifyMinutes % 60)
    }

    // MARK: - Day rollover
    // The menu bar app often stays open across midnight; recompute the daily
    // pick and weekday when the local calendar day changes.
    private static func dayKey(_ d: Date) -> Int {
        Int(Calendar.current.startOfDay(for: d).timeIntervalSince1970)
    }
    private func startRollover() {
        rolloverTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkRollover() }
        }
    }
    @MainActor private func checkRollover() {
        let k = Self.dayKey(Date())
        guard k != currentDay else { return }
        currentDay = k
        // Re-point a date view at the new today. A favorite being read stays put.
        if case .day = showing { showing = .day(Date()) }
        if notifyEnabled { refreshNotifications() }   // top the horizon back up
    }

    func setLang(_ l: AppLang) {
        lang = l
        UserDefaults.standard.set(l.rawValue, forKey: Self.kLang)
        if notifyEnabled { refreshNotifications() }   // queued bodies are language-specific
    }

    func setWarmPaper(_ enabled: Bool) {
        warmPaper = enabled
        UserDefaults.standard.set(enabled, forKey: Self.kWarmPaper)
    }

    func setAttachToMenubar(_ v: Bool) {
        attachToMenubar = v
        UserDefaults.standard.set(v, forKey: Self.kAttach)
    }

    func toggleAttachToMenubar() {
        setAttachToMenubar(!attachToMenubar)
    }

    var isCurrentFavorite: Bool {
        guard let v = current else { return false }
        return favorites.contains(v.id)
    }

    func toggleFavorite() {
        guard let v = current else { return }
        if favorites.contains(v.id) {
            favorites.remove(v.id)
        } else {
            favorites.insert(v.id)
        }
        persistFavorites()
    }

    func toggleFavorites() {
        showHistory = false
        showSettings = false
        showFavorites.toggle()
    }

    func toggleHistory() {
        showFavorites = false
        showSettings = false
        showHistory.toggle()
    }

    func toggleSettings() {
        showFavorites = false
        showHistory = false
        showSettings.toggle()
    }

    // Show a saved favorite directly — it belongs to no particular day.
    func show(_ v: Verse) {
        showing = .verse(v)
        showFavorites = false
    }

    // Jump to the verse that would have shown on a given date — the daily
    // pick is a pure function of the date, so this needs no stored history.
    func jumpToDate(_ date: Date) {
        showing = .day(date)
        showHistory = false
    }

    func verse(on date: Date) -> Verse? {
        guard !verses.isEmpty else { return nil }
        return verses[DailyPick.index(count: verses.count, for: date)]
    }

    var favoriteVerses: [Verse] {
        verses.filter { favorites.contains($0.id) }
    }

    private func persistFavorites() {
        if let data = try? JSONEncoder().encode(Array(favorites)) {
            UserDefaults.standard.set(data, forKey: Self.kFavs)
        }
    }

    func toggleLaunchAtLogin() {
        let svc = SMAppService.mainApp
        if launchAtLogin {
            try? svc.unregister()
        } else {
            try? svc.register()
        }
        // Reflect the actual system state regardless of the call's success.
        launchAtLogin = (svc.status == .enabled)
    }

    func bigger() { setScale(fontScale + 0.1) }
    func smaller() { setScale(fontScale - 0.1) }
    private func setScale(_ v: Double) {
        fontScale = min(max(v, 0.85), 1.8)
        UserDefaults.standard.set(fontScale, forKey: Self.kScale)
    }

    // The date whose verse is on screen. A favorite has none, so its weekday
    // and blessing fall back to today.
    var displayedDate: Date {
        if case .day(let d) = showing { return d }
        return Date()
    }

    var isToday: Bool {
        if case .day(let d) = showing {
            return Calendar.current.isDateInToday(d)
        }
        return false
    }

    var current: Verse? {
        if case .verse(let v) = showing { return v }
        return verse(on: displayedDate)
    }

    var todayVerse: Verse? { verse(on: Date()) }

    private func shiftDay(_ n: Int) {
        let cal = Calendar.current
        let base = cal.startOfDay(for: displayedDate)
        showing = .day(cal.date(byAdding: .day, value: n, to: base) ?? base)
    }

    func prev() { shiftDay(-1) }
    func next() { shiftDay(1) }
    func reset() {
        showing = .day(Date())
        showFavorites = false
        showHistory = false
        showSettings = false
    }
    func togglePin() { pinned.toggle() }

    // MARK: - Derived display text
    var text: VerseText { VerseText(zh: lang == .zh) }
    var headerTitle: String { text.title(current, on: displayedDate) }
    var blessing: String { text.blessing(current, on: displayedDate) }

    func copyFormatted() {
        guard let v = current else { return }
        copy(v, on: displayedDate)
    }

    // Always copies today's actual pick, independent of prev/next browsing —
    // used by the "Copy Today's Verse" menu item so its label stays true even
    // if the panel is currently showing a browsed-to verse.
    func copyTodayVerse() {
        guard let v = todayVerse else { return }
        copy(v, on: Date())
    }

    private func copy(_ v: Verse, on date: Date) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text.clipboard(v, on: date), forType: .string)
        copyFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.copyFeedback = false
        }
    }
}

struct SutraView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: VerseViewModel
    @State private var historyDate = Date()
    @State private var showExpanded = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                header
                Divider()
                if viewModel.showSettings {
                    settingsView
                } else if viewModel.showHistory {
                    historyView
                } else if viewModel.showFavorites {
                    favoritesList
                } else if showExpanded, let v = viewModel.current {
                    fullTextView(verse: v)
                } else {
                    verseCardView
                }
                controls
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.regularMaterial)
                    if viewModel.warmPaper {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(colorScheme == .dark
                                  ? Color(red: 0.22, green: 0.17, blue: 0.13).opacity(0.42)
                                  : Color(red: 0.98, green: 0.95, blue: 0.89).opacity(0.55))
                    }
                }
            }

            if viewModel.showShortcuts {
                shortcutsOverlay
            }
        }
        .alert(viewModel.lang == .zh ? "通知權限未開啟" : "Notifications Not Enabled", isPresented: $viewModel.notifyDeniedAlert) {
            Button(viewModel.lang == .zh ? "打開系統設定" : "Open System Settings") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Notifications.prefPane"))
            }
            Button(viewModel.lang == .zh ? "取消" : "Cancel", role: .cancel) { }
        } message: {
            Text(viewModel.lang == .zh ?
                 "Daily Sutra 需要通知權限以發送每日日課提醒。請在「系統設定 > 通知 > Daily Sutra」中啟用。" :
                 "Daily Sutra needs notification permission to send daily reminders. Enable it in System Settings > Notifications > Daily Sutra.")
        }
    }

    private static let cachedHeaderIcon: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenubarIcon", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        return img
    }()

    private var header: some View {
        HStack(spacing: 8) {
            if let icon = Self.cachedHeaderIcon {
                Image(nsImage: icon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            Text(viewModel.headerTitle)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .lineLimit(1)
            Spacer()

            // One-tap Language switcher pill
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.setLang(viewModel.lang == .en ? .zh : .en)
                }
            }) {
                Text(viewModel.lang == .en ? "中" : "EN")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(viewModel.lang == .en ? "切換至繁體中文" : "Switch to English")
            .accessibilityLabel(viewModel.lang == .en ? "Switch language to Traditional Chinese" : "切換語言至英文")

            // Attach to Menu Bar vs Draggable toggle button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.toggleAttachToMenubar()
                }
            }) {
                Image(systemName: viewModel.attachToMenubar ? "menubar.dock.rectangle" : "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(viewModel.attachToMenubar ? Color.secondary : Color.accentColor)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(viewModel.attachToMenubar
                  ? (viewModel.lang == .zh ? "視窗已依附選單列（點擊切換為自由拖曳）" : "Attached to menu bar (Click to make draggable)")
                  : (viewModel.lang == .zh ? "自由拖曳視窗（點擊依附至選單列）" : "Draggable window (Click to attach to menu bar)"))
            .accessibilityLabel(viewModel.attachToMenubar
                                ? (viewModel.lang == .zh ? "視窗已依附選單列" : "Window attached to menu bar")
                                : (viewModel.lang == .zh ? "自由拖曳視窗" : "Draggable window"))

            // Pin button
            Button(action: { viewModel.togglePin() }) {
                Image(systemName: viewModel.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(viewModel.pinned ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(viewModel.pinned ? (viewModel.lang == .zh ? "取消釘選視窗" : "Unpin panel") : (viewModel.lang == .zh ? "釘選視窗" : "Pin panel"))
            .accessibilityLabel(viewModel.pinned ? (viewModel.lang == .zh ? "取消釘選視窗" : "Unpin panel") : (viewModel.lang == .zh ? "釘選視窗" : "Pin panel"))

            // Settings button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.toggleSettings()
                }
            }) {
                Image(systemName: viewModel.showSettings ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(viewModel.showSettings ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(viewModel.lang == .zh ? "偏好設定" : "Preferences")
            .accessibilityLabel(viewModel.lang == .zh ? "偏好設定" : "Preferences")
        }
    }

    private var verseCardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.showOnboarding {
                    onboardingBanner
                }

                if let v = viewModel.current {
                    let s = viewModel.fontScale
                    let explanation = viewModel.text.explanation(v)

                    // Pull quote
                    Text(viewModel.text.quote(v))
                        .font(.system(size: 20 * s, weight: .semibold, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .accessibilityLabel(viewModel.lang == .zh ? "經文：\(viewModel.text.quote(v))" : "Verse: \(viewModel.text.quote(v))")

                    // Unified Explanation paragraph without duplicate label
                    if !explanation.isEmpty {
                        Text(explanation)
                            .font(.system(size: 13 * s, weight: .regular))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .accessibilityLabel(explanation)
                    }

                    Divider()

                    // Closing blessing: italics for English, upright for Chinese
                    Text(viewModel.blessing)
                        .font(.system(size: 13 * s, weight: .light, design: .serif))
                        .italic(viewModel.lang == .en)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityLabel(viewModel.blessing)

                    // Full text button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showExpanded = true
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "book.pages")
                            Text(viewModel.lang == .zh ? "完整經文與對照" : "Full Classical Text")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(viewModel.lang == .zh ? "閱讀完整文言文與對照" : "Read full classical text and translation")

                    Spacer(minLength: 0)
                } else {
                    Text(viewModel.lang == .zh ? "尚未載入經文。" : "No verses loaded.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var onboardingBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.lang == .zh ? "歡迎來到 Daily Sutra" : "Welcome to Daily Sutra")
                    .font(.system(size: 12, weight: .semibold))
                Text(viewModel.lang == .zh ?
                     "每日隨曆日推送一則金剛經與心經法語。使用 ← / → 瀏覽日期，按 T 回到今日，⌘C 複製經文。" :
                     "One verse each day for reflection. Use ← / → to browse, T for today, ⌘C to copy.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
            Button(action: {
                withAnimation { viewModel.completeOnboarding() }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help(viewModel.lang == .zh ? "關閉指引" : "Dismiss guide")
            .accessibilityLabel(viewModel.lang == .zh ? "關閉歡迎指引" : "Dismiss welcome guide")
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.bottom, 4)
    }

    private func fullTextView(verse v: Verse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(viewModel.lang == .en ? "Classical Translation" : "文言文譯文")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showExpanded = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(viewModel.lang == .zh ? "返回經句" : "Back to Verse")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                Text(viewModel.lang == .en ? v.en : v.zh)
                    .font(.system(size: 13 * viewModel.fontScale, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .foregroundStyle(.primary)

                Divider().padding(.vertical, 4)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showExpanded = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                        Text(viewModel.lang == .zh ? "收合完整經文" : "Collapse")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 2)
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.lang == .zh ? "依日期瀏覽" : "Browse by Date")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: {
                    withAnimation { viewModel.showHistory = false }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text(viewModel.lang == .zh ? "返回" : "Back")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            DatePicker("", selection: $historyDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()

            if let v = viewModel.verse(on: historyDate) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.text.title(v, on: historyDate))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.text.firstLine(v))
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            HStack {
                Button(viewModel.lang == .zh ? "前往此日經文" : "Go to this date") {
                    withAnimation { viewModel.jumpToDate(historyDate) }
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button(viewModel.lang == .zh ? "返回今日" : "Return to Today") {
                    withAnimation { viewModel.reset() }
                }
                .buttonStyle(.bordered)
            }
            Spacer(minLength: 0)
        }
    }

    private var favoritesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.lang == .zh ? "收藏經文 (\(viewModel.favoriteVerses.count))" : "Favorites (\(viewModel.favoriteVerses.count))")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: {
                    withAnimation { viewModel.showFavorites = false }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text(viewModel.lang == .zh ? "返回" : "Back")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.favoriteVerses.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "heart")
                                .font(.system(size: 24))
                                .foregroundStyle(.tertiary)
                            Text(viewModel.lang == .zh ?
                                 "尚未收藏任何經文。\n在經文下方輕點愛心圖示即可加入收藏。" :
                                 "No favorites yet.\nTap the heart icon on any verse to save it here.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(viewModel.favoriteVerses) { v in
                            Button {
                                withAnimation { viewModel.show(v) }
                            } label: {
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(viewModel.text.firstLine(v))
                                            .font(.system(size: 12, design: .serif))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .foregroundStyle(.primary)
                                        Text("\(viewModel.lang == .zh ? "第" : "Chapter ")\(v.index)\(viewModel.lang == .zh ? "章" : "")")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var settingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(viewModel.lang == .zh ? "設定與偏好" : "Settings & Preferences")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button(action: {
                        withAnimation { viewModel.showSettings = false }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text(viewModel.lang == .zh ? "完成" : "Done")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.lang == .zh ? "系統與提醒" : "System & Reminders")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Toggle(viewModel.lang == .zh ? "開機時自動啟動" : "Launch at Login", isOn: Binding(
                        get: { viewModel.launchAtLogin },
                        set: { _ in viewModel.toggleLaunchAtLogin() }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption)

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(viewModel.lang == .zh ? "每日定時提醒" : "Daily reminder", isOn: Binding(
                            get: { viewModel.notifyEnabled },
                            set: { _ in viewModel.toggleNotify() }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.caption)

                        if viewModel.notifyEnabled {
                            HStack {
                                Text(viewModel.lang == .zh ? "提醒時間：" : "Time:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                DatePicker("", selection: notifyTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.field)
                                    .font(.caption)
                                    .fixedSize()
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.lang == .zh ? "文字大小" : "Text Scale")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button(action: { viewModel.smaller() }) {
                            Image(systemName: "textformat.size.smaller")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .help(viewModel.lang == .zh ? "縮小文字" : "Smaller text")
                        .accessibilityLabel(viewModel.lang == .zh ? "縮小文字" : "Smaller text")

                        Text("\(Int(viewModel.fontScale * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .center)

                        Button(action: { viewModel.bigger() }) {
                            Image(systemName: "textformat.size.larger")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .help(viewModel.lang == .zh ? "放大文字" : "Larger text")
                        .accessibilityLabel(viewModel.lang == .zh ? "放大文字" : "Larger text")

                        Spacer()

                        Button(viewModel.lang == .zh ? "重設" : "Reset") {
                            viewModel.fontScale = 1.0
                            UserDefaults.standard.set(1.0, forKey: "FontScale")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.lang == .zh ? "閱讀氛圍" : "Reading Ambience")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Toggle(viewModel.lang == .zh ? "溫潤宣紙色調" : "Warm Paper Tint", isOn: Binding(
                        get: { viewModel.warmPaper },
                        set: { viewModel.setWarmPaper($0) }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption)

                    Text(viewModel.lang == .zh ? "為晨間靜心閱讀增添柔和的宣紙底色，舒緩雙眼。" : "Adds a gentle parchment warmth for quiet morning contemplation.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 20)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.lang == .zh ? "視窗位置" : "Window Placement")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Toggle(viewModel.lang == .zh ? "依附於選單列" : "Attach to Menu Bar", isOn: Binding(
                        get: { viewModel.attachToMenubar },
                        set: { viewModel.setAttachToMenubar($0) }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption)

                    Text(viewModel.lang == .zh ? "取消勾選後可自由拖曳視窗至螢幕任意位置，並記憶位置。" : "When unchecked, you can freely drag the window anywhere on screen and remember its position.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 20)

                    if !viewModel.attachToMenubar {
                        Button(action: {
                            (NSApp.delegate as? AppDelegate)?.snapToMenubar(animate: true)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.to.line")
                                Text(viewModel.lang == .zh ? "重置至選單列下方" : "Snap to Menu Bar")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .padding(.leading, 20)
                        .padding(.top, 2)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { viewModel.showShortcuts = true }) {
                        HStack {
                            Image(systemName: "command")
                            Text(viewModel.lang == .zh ? "快捷鍵指引" : "Keyboard Shortcuts")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        }
                        .font(.caption)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Button(action: { NSApp.terminate(nil) }) {
                        HStack {
                            Image(systemName: "power")
                            Text(viewModel.lang == .zh ? "結束 Daily Sutra" : "Quit Daily Sutra")
                            Spacer()
                            Text("⌘Q").font(.caption2).foregroundStyle(.tertiary)
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 2)
        }
    }

    private var controls: some View {
        HStack(spacing: 6) {
            // Day navigation
            iconButton("chevron.left", help: viewModel.lang == .zh ? "上一日 (←)" : "Previous verse (←)") {
                viewModel.prev()
            }

            // Today button with active state indicator
            Button(action: {
                withAnimation { viewModel.reset() }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isToday ? "calendar" : "calendar.badge.clock")
                        .font(.system(size: 11))
                    Text(viewModel.lang == .zh ? "今日" : "Today")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(viewModel.isToday ? .secondary : Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(viewModel.isToday ? Color.clear : Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(viewModel.lang == .zh ? "回到今日經文 (T)" : "Return to today (T)")
            .accessibilityLabel(viewModel.lang == .zh ? "回到今日經文" : "Return to today's verse")

            iconButton("chevron.right", help: viewModel.lang == .zh ? "下一日 (→)" : "Next verse (→)") {
                viewModel.next()
            }

            Divider().frame(height: 16).padding(.horizontal, 2)

            // Secondary contemplative actions
            iconButton(viewModel.isCurrentFavorite ? "heart.fill" : "heart",
                       help: viewModel.isCurrentFavorite ?
                            (viewModel.lang == .zh ? "從收藏中移除" : "Remove from favorites") :
                            (viewModel.lang == .zh ? "加入收藏" : "Save to favorites"),
                       activeColor: viewModel.isCurrentFavorite ? .red : nil) {
                viewModel.toggleFavorite()
            }

            iconButton("bookmark",
                       help: viewModel.lang == .zh ? "收藏經文清單" : "Favorites list",
                       activeColor: viewModel.showFavorites ? Color.accentColor : nil) {
                withAnimation { viewModel.toggleFavorites() }
            }

            iconButton("calendar",
                       help: viewModel.lang == .zh ? "依日期瀏覽" : "Browse by date",
                       activeColor: viewModel.showHistory ? Color.accentColor : nil) {
                withAnimation { viewModel.toggleHistory() }
            }

            Spacer()

            // Copy button with feedback animation
            Button(action: {
                viewModel.copyFormatted()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.copyFeedback ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                    if viewModel.copyFeedback {
                        Text(viewModel.lang == .zh ? "已複製" : "Copied")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .foregroundStyle(viewModel.copyFeedback ? Color.green : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(viewModel.copyFeedback ? Color.green.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(viewModel.lang == .zh ? "複製經文 (⌘C)" : "Copy formatted verse (⌘C)")
            .accessibilityLabel(viewModel.lang == .zh ? "複製經文" : "Copy formatted verse")
        }
    }

    private var notifyTime: Binding<Date> {
        Binding(
            get: {
                guard let date = Calendar.current.date(bySettingHour: viewModel.notifyMinutes / 60,
                                                        minute: viewModel.notifyMinutes % 60,
                                                        second: 0, of: Date()) else {
                    assertionFailure("Failed to construct notification time from \(viewModel.notifyMinutes) minutes")
                    return Date()
                }
                return date
            },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                viewModel.setNotifyMinutes((c.hour ?? 0) * 60 + (c.minute ?? 0))
            })
    }

    private func iconButton(_ sf: String, help: String, activeColor: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: sf)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(activeColor ?? .secondary)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private var shortcutsOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
                .onTapGesture { viewModel.showShortcuts = false }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(viewModel.lang == .zh ? "鍵盤快捷鍵" : "Keyboard Shortcuts")
                        .font(.headline)
                    Spacer()
                    Button(action: { viewModel.showShortcuts = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 8) {
                    shortcutRow(keys: "←", desc: viewModel.lang == .zh ? "上一日經文" : "Previous verse")
                    shortcutRow(keys: "→", desc: viewModel.lang == .zh ? "下一日經文" : "Next verse")
                    shortcutRow(keys: "T", desc: viewModel.lang == .zh ? "回到今日經文" : "Return to today's verse")
                    shortcutRow(keys: "⌘C", desc: viewModel.lang == .zh ? "複製整則經文與意解" : "Copy formatted verse")
                    shortcutRow(keys: "Esc", desc: viewModel.lang == .zh ? "關閉浮動視窗" : "Close panel")
                }

                Divider().padding(.vertical, 2)

                HStack {
                    Spacer()
                    Button(viewModel.lang == .zh ? "我知道了" : "Done") {
                        viewModel.showShortcuts = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(18)
            .frame(maxWidth: 300)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .shadow(radius: 12)
        }
    }

    private func shortcutRow(keys: String, desc: String) -> some View {
        HStack {
            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(keys)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}