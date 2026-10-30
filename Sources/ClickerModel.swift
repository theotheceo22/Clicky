import SwiftUI
import AppKit
import Carbon
import ApplicationServices

// MARK: - Options

enum MouseButton: String, CaseIterable {
    case left, right, middle
    var label: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .middle: return "Middle"
        }
    }
}

enum ClickKind: String, CaseIterable {
    case single, double
    var label: String { self == .single ? "Single" : "Double" }
}

enum TargetMode: String, CaseIterable {
    case cursor, fixed
    var label: String { self == .cursor ? "Cursor" : "Fixed" }
}

enum RunState: Equatable {
    case idle
    case countdown(Int)
    case running
}

// MARK: - Model

@MainActor
final class ClickerModel: ObservableObject {
    static let shared = ClickerModel()

    private enum Keys {
        static let cps = "cps", button = "button", kind = "kind", target = "target"
        static let hasPoint = "hasPoint", px = "px", py = "py"
        static let limitOn = "limitOn", limit = "limit", humanize = "humanize"
    }

    private let store = UserDefaults.standard

    // Settings (persisted)
    @Published var cps: Double { didSet { store.set(cps, forKey: Keys.cps) } }
    @Published var button: MouseButton { didSet { store.set(button.rawValue, forKey: Keys.button) } }
    @Published var kind: ClickKind { didSet { store.set(kind.rawValue, forKey: Keys.kind) } }
    @Published var target: TargetMode { didSet { store.set(target.rawValue, forKey: Keys.target) } }
    @Published var fixedPoint: CGPoint? {
        didSet {
            store.set(fixedPoint != nil, forKey: Keys.hasPoint)
            if let p = fixedPoint {
                store.set(Double(p.x), forKey: Keys.px)
                store.set(Double(p.y), forKey: Keys.py)
            }
        }
    }
    @Published var limitEnabled: Bool { didSet { store.set(limitEnabled, forKey: Keys.limitOn) } }
    @Published var limit: Int {
        didSet {
            if limit < 1 { limit = 1 }
            store.set(limit, forKey: Keys.limit)
        }
    }
    @Published var humanize: Bool { didSet { store.set(humanize, forKey: Keys.humanize) } }

    // Live state
    @Published private(set) var state: RunState = .idle
    @Published private(set) var clicks = 0
    @Published private(set) var liveCPS: Double = 0
    @Published private(set) var startDate: Date?
    @Published private(set) var lastDuration: TimeInterval = 0
    @Published private(set) var hasAccess = false
    @Published private(set) var pickCountdown: Int?
    @Published private(set) var accessNudge = 0
    @Published private(set) var pointNudge = 0

    var isBusy: Bool { state != .idle }
    var isRunning: Bool { state == .running }

    private let engine = ClickEngine()
    private var currentGen = 0
    private var stamps: [TimeInterval] = []
    private var countdownTask: Task<Void, Never>?
    private var pickTask: Task<Void, Never>?
    private var accessTimer: Timer?
    private var toggleKey: HotKey?
    private var escKey: HotKey?

    private init() {
        let d = UserDefaults.standard
        cps = (d.object(forKey: Keys.cps) as? Double) ?? 10
        button = MouseButton(rawValue: d.string(forKey: Keys.button) ?? "") ?? .left
        kind = ClickKind(rawValue: d.string(forKey: Keys.kind) ?? "") ?? .single
        target = TargetMode(rawValue: d.string(forKey: Keys.target) ?? "") ?? .cursor
        if d.bool(forKey: Keys.hasPoint) {
            fixedPoint = CGPoint(x: d.double(forKey: Keys.px), y: d.double(forKey: Keys.py))
        } else {
            fixedPoint = nil
        }
        limitEnabled = d.bool(forKey: Keys.limitOn)
        limit = max(1, (d.object(forKey: Keys.limit) as? Int) ?? 100)
        humanize = d.bool(forKey: Keys.humanize)

        hasAccess = AXIsProcessTrusted()
        // The timer fires on the main run loop.
        accessTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccess() }
        }
        // Register the global hotkey once the app's event loop is running.
        Task { @MainActor [weak self] in
            self?.registerHotKey()
        }
    }

    /// ⌥⌘K — start / stop from anywhere, no countdown.
    private func registerHotKey() {
        toggleKey = HotKey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
            self?.toggle(countdown: false)
        }
    }

    // MARK: Control

    func toggle(countdown: Bool) {
        if isBusy { stop() } else { start(countdown: countdown) }
    }

    func start(countdown: Bool) {
        guard state == .idle else { return }
        refreshAccess()
        guard hasAccess else {
            accessNudge += 1
            requestAccess()
            return
        }
        if target == .fixed && fixedPoint == nil {
            pointNudge += 1
            return
        }
        armEscape()
        if countdown {
            state = .countdown(3)
            countdownTask = Task { @MainActor [weak self] in
                for n in [3, 2, 1] {
                    self?.state = .countdown(n)
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { return }
                }
                self?.beginClicking()
            }
        } else {
            beginClicking()
        }
    }

    func stop() {
        countdownTask?.cancel()
        countdownTask = nil
        engine.stop()
        currentGen = 0
        if state == .running, let s = startDate {
            lastDuration = Date().timeIntervalSince(s)
        }
        state = .idle
        liveCPS = 0
        escKey = nil
    }

    private func beginClicking() {
        clicks = 0
        liveCPS = 0
        stamps.removeAll()
        startDate = Date()
        state = .running

        let config = ClickEngine.Config(
            interval: 1.0 / max(1, cps),
            humanize: humanize,
            button: button,
            double: kind == .double,
            point: target == .fixed ? fixedPoint : nil,
            limit: limitEnabled ? max(1, limit) : nil
        )
        // Callbacks arrive on the engine's queue; hop to the main thread in order.
        let model = self
        currentGen = engine.start(config, onClick: { @Sendable gen, count in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { model.didClick(gen: gen, count: count) }
            }
        }, onFinish: { @Sendable gen in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if model.currentGen == gen { model.stop() }
                }
            }
        })
    }

    private func didClick(gen: Int, count: Int) {
        guard gen == currentGen, state == .running else { return }
        clicks = max(clicks, count)
        let now = ProcessInfo.processInfo.systemUptime
        stamps.append(now)
        while let first = stamps.first, now - first > 1.0 { stamps.removeFirst() }
        if stamps.count >= 2, let first = stamps.first, now > first {
            liveCPS = Double(stamps.count - 1) / (now - first)
        }
    }

    /// Esc stops clicking — only grabbed while a run is active.
    private func armEscape() {
        guard escKey == nil else { return }
        escKey = HotKey(keyCode: UInt32(kVK_Escape), modifiers: 0) { [weak self] in
            // Defer so the hot key isn't torn down from inside its own callback.
            Task { @MainActor [weak self] in self?.stop() }
        }
    }

    // MARK: Fixed point picking

    func pickPoint() {
        pickTask?.cancel()
        pickTask = Task { @MainActor [weak self] in
            for n in [3, 2, 1] {
                self?.pickCountdown = n
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }
            guard let self else { return }
            let p = CGEvent(source: nil)?.location ?? .zero
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                self.fixedPoint = p
                self.pickCountdown = nil
            }
            PointFlash.show(at: p)
        }
    }

    // MARK: Accessibility permission

    func refreshAccess() {
        let ok = AXIsProcessTrusted()
        if ok != hasAccess {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { hasAccess = ok }
        }
    }

    func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
