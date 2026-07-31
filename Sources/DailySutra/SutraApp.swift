import SwiftUI
import AppKit
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
        // Use NSHostingView as contentView (not contentViewController) so the
        // window keeps its 400x560 frame; a flexible SwiftUI frame inside a
        // contentViewController collapses to a 0 fitting size and renders blank.
        let hosting = NSHostingView(rootView: SutraView(viewModel: vm))
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.delegate = self
        self.panel = panel

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let url = Bundle.main.url(forResource: "MenubarIcon", withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                img.isTemplate = true          // transparent silhouette → auto light/dark
                img.size = NSSize(width: 26, height: 26)
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
    }

    @objc func togglePanel(_ sender: Any?) {
        guard let button = statusItem?.button, let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
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
    }
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

    private static let kLang = "AppLang", kScale = "FontScale", kFavs = "Favorites"

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
                            if !expl.isEmpty {
                                Text(expl)
                                    .font(.system(size: 13.5 * s))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                            if !meaning.isEmpty {
                                Divider()
                                Text(isZh ? "省思" : "Reflection")
                                    .font(.caption2).foregroundStyle(.tertiary)
                                Text(meaning)
                                    .font(.system(size: 13.5 * s))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
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
            Text("Daily Sutra")
                .font(.system(size: 15, weight: .semibold, design: .serif))
            Spacer()
            Text(weekday())
                .font(.caption).foregroundStyle(.tertiary)
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
                iconButton("doc.on.doc", help: "Copy verse") { copyCurrent() }
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

    private func weekday() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE"
        return f.string(from: Date())
    }

    private func copyCurrent() {
        guard let v = viewModel.current else { return }
        let isZh = viewModel.lang == .zh
        let verse = isZh ? v.verseZh : "\u{201C}\(v.verseEn)\u{201D}"
        let expl = isZh ? v.explZh : v.explEn
        let meaning = isZh ? v.meaningZh : v.meaning
        let s = "Daily Sutra Verse — \(weekday())\n\n\(verse)\n\n\(expl)\n\n\(meaning)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}