import SwiftUI
import AppKit
import Combine
import ServiceManagement
import UserNotifications
import SutraKit

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
        panel.isMovableByWindowBackground = true   // borderless → drag by the body
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
        return false
    }

    @objc func togglePanel(_ sender: Any?) {
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

    private func openPanel() {
        guard let button = statusItem?.button, let panel else { return }
        // Place panel top-left just under the status item button, clamped to screen bounds.
        if let btnFrame = button.window?.convertToScreen(button.bounds) {
            var origin = btnFrame.origin
            origin.y -= 2                       // small gap below the menu bar
            let screen = button.window?.screen ?? NSScreen.main
            let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
            origin.x = min(max(origin.x, visible.minX), visible.maxX - panel.frame.width)
            origin.y = min(origin.y, visible.maxY - panel.frame.height)
            panel.setFrameTopLeftPoint(origin)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Right-click context menu on the menu-bar icon.
    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Verse", action: #selector(menuShowVerse(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy Today's Verse", action: #selector(menuCopyVerse(_:)), keyEquivalent: "")
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
    @Published var pinned = false      // keep panel open across focus loss
    @Published var showOnboarding = false
    @Published var notifyDeniedAlert = false

    private static let kLang = "AppLang", kScale = "FontScale", kFavs = "Favorites"
    private static let kNotify = "NotifyEnabled", kNotifyAt = "NotifyMinutes"
    private static let kOnboarded = "OnboardingCompleted"
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
    func reset() { showing = .day(Date()) }
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
    }
}

struct SutraView: View {
    @ObservedObject var viewModel: VerseViewModel
    @State private var historyDate = Date()
    @State private var showExpanded = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                header
                Divider()
                if viewModel.showHistory {
                    historyView
                } else if viewModel.showFavorites {
                    favoritesList
                } else if showExpanded, let v = viewModel.current {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(viewModel.lang == .en ? "Classical Translation" : "文言文譯文")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(viewModel.lang == .en ? v.en : v.zh)
                                .font(.system(size: 12, design: .serif))
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                                .foregroundStyle(.secondary)
                            Divider().padding(.vertical, 8)
                            Button(action: { showExpanded = false }) {
                                HStack {
                                    Image(systemName: "chevron.up")
                                    Text("Collapse")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 2)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if let v = viewModel.current {
                                let s = viewModel.fontScale
                                let explanation = viewModel.text.explanation(v)
                                Text(viewModel.text.quote(v))
                                    .font(.system(size: 20 * s, weight: .semibold, design: .serif))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Verse: \(viewModel.text.quote(v))")
                                if !explanation.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(viewModel.lang == .en ? "Meaning:" : "意解：")
                                            .font(.system(size: 11 * s, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                        Text(explanation)
                                            .font(.system(size: 13 * s, weight: .regular))
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .textSelection(.enabled)
                                            .accessibilityElement(children: .ignore)
                                            .accessibilityLabel("Explanation: \(explanation)")
                                    }
                                }
                                Divider()
                                Text(viewModel.blessing)
                                    .font(.system(size: 13 * s, weight: .light, design: .serif))
                                    .italic()
                                    .foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Blessing: \(viewModel.blessing)")
                                Button(action: { showExpanded = true }) {
                                    HStack {
                                        Image(systemName: "book.circle")
                                        Text("Full Text")
                                    }
                                    .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                Spacer(minLength: 0)
                            } else {
                                Text("No verses loaded.")
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                controls
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if viewModel.showOnboarding {
                OnboardingOverlay(viewModel: viewModel)
            }
        }
        .alert("Notifications Not Enabled", isPresented: $viewModel.notifyDeniedAlert) {
            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Notifications.prefPane"))
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Daily Sutra needs notification permission. Enable it in System Settings > Notifications > Daily Sutra.")
        }
    }

    private static let cachedHeaderIcon: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenubarIcon", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        return img
    }()

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let icon = Self.cachedHeaderIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, height: 16)
                }
                Text(viewModel.headerTitle)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .lineLimit(1)
                Spacer()
                Menu {
                    Picker("Language", selection: $viewModel.lang) {
                        ForEach(AppLang.allCases, id: \.self) { l in Text(l.label).tag(l) }
                    }
                    .onChange(of: viewModel.lang) { _, new in viewModel.setLang(new) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }
            if let v = viewModel.current {
                Text("\(viewModel.lang == .en ? "Chapter" : "第")\(v.index) · \(v.sutra.uppercased())")
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Toggle("Launch at Login", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { _ in viewModel.toggleLaunchAtLogin() }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)
                Spacer()
                Toggle("Daily reminder", isOn: Binding(
                    get: { viewModel.notifyEnabled },
                    set: { _ in viewModel.toggleNotify() }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)
                if viewModel.notifyEnabled {
                    DatePicker("", selection: notifyTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .font(.caption)
                        .fixedSize()
                }
            }
            Divider()
            HStack(spacing: 4) {
                Group {
                    iconButton("chevron.left", help: "Previous verse") { viewModel.prev() }
                    iconButton("arrow.counterclockwise", help: "Today's verse") { viewModel.reset() }
                    iconButton("chevron.right", help: "Next verse") { viewModel.next() }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Navigation")
                Divider().frame(height: 18)
                Group {
                    iconButton(viewModel.isCurrentFavorite ? "heart.fill" : "heart",
                               help: viewModel.isCurrentFavorite ? "Remove from favorites" : "Save to favorites") { viewModel.toggleFavorite() }
                    iconButton("list.bullet", help: "Favorites") {
                        viewModel.showHistory = false
                        viewModel.showFavorites.toggle()
                    }
                    iconButton("calendar", help: "Browse by date") {
                        viewModel.showFavorites = false
                        viewModel.showHistory.toggle()
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Collections")
                Divider().frame(height: 18)
                Group {
                    iconButton("textformat.size.smaller", help: "Smaller text") { viewModel.smaller() }
                    iconButton("textformat.size.larger", help: "Larger text") { viewModel.bigger() }
                    iconButton("doc.on.doc", help: "Copy verse") { viewModel.copyFormatted() }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Display")
                Spacer()
                Menu {
                    Button(action: { viewModel.togglePin() }) {
                        Image(systemName: viewModel.pinned ? "pin.fill" : "pin")
                        Text(viewModel.pinned ? "Unpin" : "Pin")
                    }
                    Button(action: { NSApp.terminate(nil) }) {
                        Image(systemName: "power")
                        Text("Quit")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .help("More")
                .accessibilityLabel("More options")
            }
        }
    }

    // The reminder time is stored as minutes since midnight; DatePicker wants a
    // Date, so map through today's date and keep only hour/minute.
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

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker("", selection: $historyDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            if let v = viewModel.verse(on: historyDate) {
                Text(viewModel.text.firstLine(v))
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Button("Go to this date") { viewModel.jumpToDate(historyDate) }
                .buttonStyle(.borderless)
            Spacer(minLength: 0)
        }
    }

    private var favoritesList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                if viewModel.favoriteVerses.isEmpty {
                    Text("No favorites yet. Tap the heart on a verse to save it.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    ForEach(viewModel.favoriteVerses) { v in
                        Button {
                            viewModel.show(v)
                        } label: {
                            HStack(alignment: .top) {
                                Text(viewModel.text.firstLine(v))
                                    .font(.system(size: 13, design: .serif))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func iconButton(_ sf: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: sf)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct OnboardingOverlay: View {
    @ObservedObject var viewModel: VerseViewModel
    @State private var step = 0
    let steps = [
        ("Welcome", "You get a new verse each day. Let me show you how to navigate and explore."),
        ("Navigate", "← → Move to previous or next verse. T returns to today's verse."),
        ("Save Favorites", "❤ Tap to save a verse to your favorites list for quick access later."),
        ("Browse by Date", "📅 Pick any date to see that day's verse and build your collection."),
        ("Copy & Customize", "Copy verses to share or adjust text size with the + and − buttons.")
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                Text(steps[step].0).font(.headline)
                Text(steps[step].1).font(.body).lineLimit(3)
                HStack(spacing: 12) {
                    if step > 0 {
                        Button("Back") { step -= 1 }.buttonStyle(.bordered)
                    }
                    Spacer()
                    Button("Skip") { viewModel.completeOnboarding() }.buttonStyle(.bordered)
                    if step < steps.count - 1 {
                        Button("Next") { step += 1 }.buttonStyle(.borderedProminent)
                    } else {
                        Button("Got it!") { viewModel.completeOnboarding() }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}