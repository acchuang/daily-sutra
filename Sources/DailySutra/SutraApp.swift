import SwiftUI
import AppKit
import Combine
import ServiceManagement
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

final class CardPanel: NSPanel {
    override var canBecomeKey: Bool { true }    // needed for text selection
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var viewModel: VerseViewModel?
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

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
                let s = maxDim / max(img.size.width, img.size.height)
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
        // Place panel top-left just under the status item button.
        if let btnFrame = button.window?.convertToScreen(button.bounds) {
            var origin = btnFrame.origin
            origin.y -= 2                       // small gap below the menu bar
            origin.x = max(origin.x, 0)
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

    @MainActor @objc func menuShowVerse(_ s: Any?) { openPanel() }
    @MainActor @objc func menuCopyVerse(_ s: Any?) { viewModel?.copyFormatted() }
    @objc func menuQuit(_ s: Any?) { NSApp.terminate(nil) }
}

@MainActor
final class VerseViewModel: ObservableObject {
    @Published var verses: [Verse]
    @Published var offset: Int = 0          // days offset from today's verse
    @Published var lang: AppLang
    @Published var fontScale: Double
    @Published var launchAtLogin: Bool
    @Published var favorites: Set<Int>      // global indices into `verses`
    @Published var showFavorites = false
    @Published var pinned = false      // keep panel open across focus loss

    private static let kLang = "AppLang", kScale = "FontScale", kFavs = "Favorites"
    private var rolloverTimer: Timer?
    private var currentDay: Int = 0

    init(verses: [Verse]) {
        self.verses = verses
        self.offset = 0
        let saved = UserDefaults.standard.string(forKey: Self.kLang) ?? "en"
        self.lang = AppLang(rawValue: saved) ?? .en
        let raw = UserDefaults.standard.double(forKey: Self.kScale)
        self.fontScale = raw == 0 ? 1.0 : min(max(raw, 0.85), 1.8)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        if let data = UserDefaults.standard.data(forKey: Self.kFavs),
           let idx = try? JSONDecoder().decode([Int].self, from: data) {
            self.favorites = Set(idx)
        } else {
            self.favorites = []
        }
        self.currentDay = Self.dayKey(Date())
        startRollover()
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
        offset = 0          // new day → today's pick
        objectWillChange.send()   // force refresh even if offset was already 0
    }

    func setLang(_ l: AppLang) {
        lang = l
        UserDefaults.standard.set(l.rawValue, forKey: Self.kLang)
    }

    // Global index of the currently displayed verse within `verses`.
    var currentGlobalIndex: Int? {
        guard !verses.isEmpty else { return nil }
        let i = (todayIndex + offset) % verses.count
        return i < 0 ? i + verses.count : i
    }

    var isCurrentFavorite: Bool {
        guard let g = currentGlobalIndex else { return false }
        return favorites.contains(g)
    }

    func toggleFavorite() {
        guard let g = currentGlobalIndex else { return }
        if favorites.contains(g) { favorites.remove(g) } else { favorites.insert(g) }
        persistFavorites()
    }

    // Jump the daily view to a specific global index (from the favorites list).
    func showGlobalIndex(_ g: Int) {
        offset = g - todayIndex
        showFavorites = false
    }

    var favoriteVerses: [Verse] { favorites.sorted().compactMap { verses.indices.contains($0) ? verses[$0] : nil } }

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

    var todayIndex: Int { DailyPick.index(count: verses.count) }

    var current: Verse? {
        guard !verses.isEmpty else { return nil }
        let i = (todayIndex + offset) % verses.count
        return verses[i < 0 ? i + verses.count : i]
    }

    func prev() { offset -= 1 }
    func next() { offset += 1 }
    func reset() { offset = 0 }
    func togglePin() { pinned.toggle() }

    // MARK: - Derived display text (weekday, blessing, copy)
    var weekdayEn: String { Self.weekdayString(Date(), "en_US") }
    var weekdayZh: String { Self.weekdayString(Date(), "zh_TW") }
    private static func weekdayString(_ d: Date, _ loc: String) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: loc); f.dateFormat = "EEEE"
        return f.string(from: d)
    }

    var headerTitle: String {
        guard let v = current else { return weekdayEn }
        return lang == .zh ? "\(weekdayZh) — 第\(v.index)章" : "\(weekdayEn) — Chapter \(v.index)"
    }

    var blessing: String {
        let isZh = lang == .zh
        let day = isZh ? weekdayZh : weekdayEn
        if let v = current {
            let raw = isZh ? v.blessingZh : v.blessing
            if !raw.isEmpty { return raw.replacingOccurrences(of: "{weekday}", with: day) }
        }
        return isZh ? "願你\(day)輕安。🙏" : "May your \(day) be light. 🙏"
    }

    func copyFormatted() {
        guard let v = current else { return }
        let isZh = lang == .zh
        let verse = isZh ? v.verseZh : "\u{201C}\(v.verseEn)\u{201D}"
        let expl = isZh ? v.explZh : v.explEn
        let meaning = isZh ? v.meaningZh : v.meaning
        let title = isZh ? "\(weekdayZh) — 第\(v.index)章" : "\(weekdayEn) — Chapter \(v.index)"
        let body = isZh
            ? "解釋：\(expl)\(meaning.isEmpty ? "" : " \(meaning)")"
            : "Explanation: \(expl)\(meaning.isEmpty ? "" : " \(meaning)")"
        let s = "\(title)\n\n\(verse)\n\n\(body)\n\n\(blessing)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}

struct SutraView: View {
    @ObservedObject var viewModel: VerseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            if viewModel.showFavorites {
                favoritesList
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let v = viewModel.current {
                            let isZh = viewModel.lang == .zh
                            let s = viewModel.fontScale
                            let verse = isZh ? v.verseZh : "\u{201C}\(v.verseEn)\u{201D}"
                            let expl = isZh ? v.explZh : v.explEn
                            let meaning = isZh ? v.meaningZh : v.meaning
                            Text(verse)
                                .font(.system(size: 19 * s, weight: .medium, design: .serif))
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                            if !expl.isEmpty || !meaning.isEmpty {
                                Text(isZh
                                     ? "解釋：\(expl)\(meaning.isEmpty ? "" : " \(meaning)")"
                                     : "Explanation: \(expl)\(meaning.isEmpty ? "" : " \(meaning)")")
                                    .font(.system(size: 13.5 * s))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                            Divider()
                            Text(viewModel.blessing)
                                .font(.system(size: 13 * s, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
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
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let icon = headerIcon {
                Image(nsImage: icon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            Text(viewModel.headerTitle)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .lineLimit(1)
            Spacer()
            Picker("", selection: $viewModel.lang) {
                ForEach(AppLang.allCases, id: \.self) { l in Text(l.label).tag(l) }
            }
            .pickerStyle(.segmented).frame(width: 90)
            .onChange(of: viewModel.lang) { _, new in viewModel.setLang(new) }
        }
    }

    private var headerIcon: NSImage? {
        guard let url = Bundle.main.url(forResource: "MenubarIcon", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        return img
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Toggle("Launch at Login", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { _ in viewModel.toggleLaunchAtLogin() }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)
                Spacer()
            }
            HStack(spacing: 8) {
                iconButton("chevron.left", help: "Previous verse") { viewModel.prev() }
                iconButton("arrow.counterclockwise", help: "Today's verse") { viewModel.reset() }
                iconButton("chevron.right", help: "Next verse") { viewModel.next() }
                iconButton(viewModel.isCurrentFavorite ? "heart.fill" : "heart",
                           help: viewModel.isCurrentFavorite ? "Remove from favorites" : "Save to favorites") { viewModel.toggleFavorite() }
                iconButton("list.bullet", help: "Favorites") { viewModel.showFavorites.toggle() }
                Spacer()
                iconButton("textformat.size.smaller", help: "Smaller text") { viewModel.smaller() }
                iconButton("textformat.size.larger", help: "Larger text") { viewModel.bigger() }
                iconButton("doc.on.doc", help: "Copy verse") { viewModel.copyFormatted() }
                iconButton(viewModel.pinned ? "pin.fill" : "pin",
                           help: viewModel.pinned ? "Unpin — hide on focus loss" : "Pin — keep open") { viewModel.togglePin() }
                iconButton("power", help: "Quit Daily Sutra") { NSApp.terminate(nil) }
            }
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
                        let firstLine = (viewModel.lang == .zh ? v.verseZh : v.verseEn)
                            .components(separatedBy: "\n").first ?? ""
                        Button {
                            if let g = viewModel.favorites.first(where: { viewModel.verses[$0].id == v.id }) {
                                viewModel.showGlobalIndex(g)
                            }
                        } label: {
                            HStack(alignment: .top) {
                                Text(firstLine)
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}