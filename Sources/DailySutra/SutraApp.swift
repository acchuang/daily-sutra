import SwiftUI
import AppKit
import ServiceManagement

@main
struct DiamondSutraBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

func diag(_ msg: String) {
    let line = "\(Date())  \(msg)\n"
    if let h = FileHandle(forWritingAtPath: "/tmp/dsb_diag.txt") {
        h.seekToEndOfFile(); h.write(Data(line.utf8)); h.closeFile()
    } else {
        try? line.write(toFile: "/tmp/dsb_diag.txt", atomically: true, encoding: .utf8)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var viewModel: VerseViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vm = VerseViewModel(verses: VerseStore.load())
        viewModel = vm

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 560),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
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
            button.image = NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: "Diamond Sutra")
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

    private static let kLang = "AppLang", kScale = "FontScale"

    init(verses: [Verse]) {
        self.verses = verses
        self.offset = 0
        let saved = UserDefaults.standard.string(forKey: Self.kLang) ?? "en"
        self.lang = AppLang(rawValue: saved) ?? .en
        let raw = UserDefaults.standard.double(forKey: Self.kScale)
        self.fontScale = raw == 0 ? 1.0 : min(max(raw, 0.85), 1.8)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLang(_ l: AppLang) {
        lang = l
        UserDefaults.standard.set(l.rawValue, forKey: Self.kLang)
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

    var todayIndex: Int { seededDailyIndex() % max(verses.count, 1) }

    var current: Verse? {
        guard !verses.isEmpty else { return nil }
        let i = (todayIndex + offset) % verses.count
        return verses[i < 0 ? i + verses.count : i]
    }

    func prev() { offset -= 1 }
    func next() { offset += 1 }
    func reset() { offset = 0 }

    // Deterministic per-date pseudo-random pick across the whole pool
    // (Diamond + Heart): same verse all day, a new random one tomorrow.
    private func seededDailyIndex() -> Int {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: Date())
        let y = c.year ?? 0, m = c.month ?? 0, d = c.day ?? 0
        var s = UInt64(bitPattern: Int64(y * 10000 + m * 100 + d))
        s ^= s << 13; s ^= s >> 7; s ^= s << 17   // xorshift64
        return Int(s % UInt64(max(verses.count, 1)))
    }
}

struct SutraView: View {
    @ObservedObject var viewModel: VerseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let v = viewModel.current {
                        let isZh = viewModel.lang == .zh
                        let s = viewModel.fontScale
                        let verse = isZh ? v.verseZh : "\u{201C}\(v.verseEn)\u{201D}"
                        let expl = isZh ? v.explZh : v.explEn
                        let meaning = isZh ? v.meaningZh : v.meaning
                        Text(verse)
                            .font(.system(size: 17 * s, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                        if !expl.isEmpty {
                            Text(expl)
                                .font(.system(size: 13 * s))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        if !meaning.isEmpty {
                            Divider()
                            Text(isZh ? "省思" : "Reflection")
                                .font(.caption2).foregroundStyle(.tertiary)
                            Text(meaning)
                                .font(.system(size: 13 * s))
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
            Divider()
            controls
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Sutra Verse")
                    .font(.system(size: 15, weight: .semibold))
                Text("— \(weekday())").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $viewModel.lang) {
                ForEach(AppLang.allCases, id: \.self) { l in Text(l.label).tag(l) }
            }
            .pickerStyle(.segmented).frame(width: 90)
            .onChange(of: viewModel.lang) { _, new in viewModel.setLang(new) }
        }
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
            HStack {
                Button("‹ Prev") { viewModel.prev() }
                Spacer()
                Button("Today") { viewModel.reset() }
                Button("Next ›") { viewModel.next() }
                Divider().frame(height: 18)
                Button { viewModel.smaller() } label: { Image(systemName: "textformat.size.smaller") }
                    .help("Smaller text")
                Button { viewModel.bigger() } label: { Image(systemName: "textformat.size.larger") }
                    .help("Larger text")
                Button { copyCurrent() } label: { Image(systemName: "doc.on.doc") }
                    .help("Copy verse")
                Button("Quit") { NSApp.terminate(nil) }.help("Quit Daily Sutra")
            }
        }
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