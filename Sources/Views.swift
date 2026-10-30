import SwiftUI
import AppKit

// MARK: - Theme

enum Theme {
    static let pink   = Color(red: 1.00, green: 0.36, blue: 0.62)
    static let violet = Color(red: 0.55, green: 0.38, blue: 1.00)
    static let cyan   = Color(red: 0.22, green: 0.78, blue: 1.00)
    static let mint   = Color(red: 0.25, green: 0.95, blue: 0.70)
    static let amber  = Color(red: 1.00, green: 0.70, blue: 0.25)
    static let ink    = Color(red: 0.04, green: 0.04, blue: 0.08)
    static let gradient = LinearGradient(colors: [pink, violet],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Root

struct ContentView: View {
    @ObservedObject var model: ClickerModel

    var body: some View {
        ZStack {
            AuroraBackground(state: model.state)

            VStack(spacing: 18) {
                Header(model: model)

                HStack(alignment: .top, spacing: 22) {
                    VStack(spacing: 18) {
                        BigButton(model: model)
                        Group {
                            if model.hasAccess {
                                StatsRow(model: model)
                            } else {
                                AccessBanner(model: model)
                            }
                        }
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                removal: .opacity))
                        Spacer(minLength: 0)
                        HotkeyHints(model: model)
                    }
                    .frame(width: 320)

                    SettingsCard(model: model)
                        .frame(width: 350)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 22)
        }
        .frame(width: 740, height: 560)
        .foregroundStyle(Color.white)
    }
}

// MARK: - Background

struct AuroraBackground: View {
    let state: RunState

    private var tint: Color {
        switch state {
        case .idle: return .clear
        case .countdown: return Theme.amber
        case .running: return Theme.mint
        }
    }

    var body: some View {
        ZStack {
            Theme.ink
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    Circle().fill(Theme.pink)
                        .frame(width: 380, height: 380)
                        .offset(x: -200 + sin(t * 0.31) * 110, y: -130 + cos(t * 0.27) * 90)
                    Circle().fill(Theme.violet)
                        .frame(width: 440, height: 440)
                        .offset(x: 210 + cos(t * 0.23) * 120, y: 70 + sin(t * 0.29) * 100)
                    Circle().fill(Theme.cyan)
                        .frame(width: 300, height: 300)
                        .offset(x: sin(t * 0.37 + 2) * 220, y: 210 + cos(t * 0.33) * 70)
                }
                .blur(radius: 90)
                .opacity(0.42)
            }
            RadialGradient(colors: [tint.opacity(0.28), .clear],
                           center: .init(x: 0.25, y: 0.45), startRadius: 20, endRadius: 420)
                .animation(.easeInOut(duration: 0.8), value: state)
            // soft vignette
            RadialGradient(colors: [.clear, Color.black.opacity(0.45)],
                           center: .center, startRadius: 250, endRadius: 560)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Header

struct Header: View {
    @ObservedObject var model: ClickerModel

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.gradient)
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 17, weight: .bold))
                    .symbolEffect(.pulse, isActive: model.isRunning)
            }
            .frame(width: 38, height: 38)
            .shadow(color: Theme.violet.opacity(0.5), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text("Clicky")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Auto clicker for macOS")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Spacer()
            StatusPill(state: model.state)
        }
    }
}

struct StatusPill: View {
    let state: RunState

    private var text: String {
        switch state {
        case .idle: return "Ready"
        case .countdown(let n): return "Starting in \(n)"
        case .running: return "Clicking"
        }
    }

    private var color: Color {
        switch state {
        case .idle: return Color.white.opacity(0.55)
        case .countdown: return Theme.amber
        case .running: return Theme.mint
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            PulseDot(color: color, active: state != .idle)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.07)))
        .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
        .animation(.snappy, value: state)
    }
}

struct PulseDot: View {
    let color: Color
    let active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { tl in
            let p = active ? tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2 : 1.0
            ZStack {
                Circle().fill(color)
                    .frame(width: 14, height: 14)
                    .scaleEffect(0.5 + p * 1.1)
                    .opacity(active ? (1 - p) * 0.6 : 0)
                Circle().fill(color).frame(width: 7, height: 7)
            }
            .frame(width: 14, height: 14)
        }
    }
}

// MARK: - Big start/stop button

struct BigButton: View {
    @ObservedObject var model: ClickerModel
    @State private var hovering = false

    private var colors: [Color] {
        switch model.state {
        case .idle: return [Theme.pink, Theme.violet]
        case .countdown: return [Theme.amber, Theme.pink]
        case .running: return [Theme.cyan, Theme.mint]
        }
    }

    var body: some View {
        Button {
            model.toggle(countdown: true)
        } label: {
            ZStack {
                // breathing glow
                Circle()
                    .fill(RadialGradient(colors: [colors[1].opacity(0.55), .clear],
                                         center: .center, startRadius: 40, endRadius: 130))
                    .frame(width: 260, height: 260)
                    .phaseAnimator([0.86, 1.06]) { view, scale in
                        view.scaleEffect(scale)
                    } animation: { _ in .easeInOut(duration: 1.8) }

                if model.state == .running {
                    RippleRings(color: colors[0], speed: min(2.2, 0.5 + model.cps / 25))
                        .transition(.opacity)
                }

                if model.state != .idle {
                    SpinningRing(colors: colors)
                        .frame(width: 188, height: 188)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }

                Circle()
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        Circle().fill(LinearGradient(colors: [Color.white.opacity(0.35), .clear],
                                                     startPoint: .top, endPoint: .center))
                    )
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    .frame(width: 164, height: 164)
                    .shadow(color: colors[1].opacity(0.6), radius: hovering ? 30 : 18, y: 6)
                    .scaleEffect(hovering && model.state == .idle ? 1.04 : 1)

                centerContent
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 4, y: 2)
            }
            .frame(width: 280, height: 250)
            .contentShape(Circle().scale(0.62))
        }
        .buttonStyle(PressableStyle())
        .focusEffectDisabled()
        .onHover { h in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { hovering = h }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: model.state)
    }

    @ViewBuilder
    private var centerContent: some View {
        switch model.state {
        case .idle:
            VStack(spacing: 6) {
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 38, weight: .semibold))
                    .symbolEffect(.bounce, value: hovering)
                Text("START")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(3)
            }
            .transition(.scale(scale: 0.5).combined(with: .opacity))

        case .countdown(let n):
            VStack(spacing: 0) {
                Text("\(n)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .contentTransition(.numericText(countsDown: true))
                Text("GET READY")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .opacity(0.85)
            }
            .transition(.scale(scale: 0.5).combined(with: .opacity))

        case .running:
            VStack(spacing: 2) {
                Text(model.clicks.formatted())
                    .font(.system(size: model.clicks > 99_999 ? 26 : 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(model.clicks)))
                    .animation(model.cps <= 15 ? Animation.snappy(duration: 0.2) : nil, value: model.clicks)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: 130)
                Text("TAP TO STOP")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .opacity(0.85)
            }
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }
}

struct RippleRings: View {
    let color: Color
    let speed: Double

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate * speed
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let p = (t + Double(i) / 3.0).truncatingRemainder(dividingBy: 1.0)
                    Circle()
                        .stroke(color.opacity((1 - p) * 0.7), lineWidth: 2)
                        .frame(width: 164, height: 164)
                        .scaleEffect(1 + p * 0.55)
                }
            }
        }
    }
}

struct SpinningRing: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation) { tl in
            let angle = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4 * 360
            Circle()
                .stroke(AngularGradient(gradient: Gradient(colors: [.clear] + colors), center: .center),
                        lineWidth: 4)
                .rotationEffect(.degrees(angle))
        }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Stats

struct StatsRow: View {
    @ObservedObject var model: ClickerModel

    var body: some View {
        HStack(spacing: 10) {
            StatTile(label: "CLICKS") {
                Text(model.clicks.formatted())
                    .contentTransition(.numericText(value: Double(model.clicks)))
            }
            StatTile(label: "LIVE CPS") {
                Text(String(format: "%.0f", model.liveCPS))
                    .contentTransition(.numericText(value: model.liveCPS))
                    .animation(.snappy, value: Int(model.liveCPS))
            }
            StatTile(label: "TIME") {
                if model.isRunning, let start = model.startDate {
                    Text(start, style: .timer)
                } else {
                    Text(Duration.seconds(model.lastDuration).formatted(.time(pattern: .minuteSecond)))
                }
            }
        }
    }
}

struct StatTile<V: View>: View {
    let label: String
    @ViewBuilder var value: () -> V

    var body: some View {
        VStack(spacing: 4) {
            value()
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08)))
    }
}

// MARK: - Access banner

struct AccessBanner: View {
    @ObservedObject var model: ClickerModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 24))
                .foregroundStyle(Theme.amber)
                .symbolEffect(.pulse)
            VStack(alignment: .leading, spacing: 3) {
                Text("Accessibility access needed")
                    .font(.system(size: 13, weight: .bold))
                Button {
                    model.openAccessibilitySettings()
                } label: {
                    Text("Open System Settings →")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.amber.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 4)
            Button("Grant") { model.requestAccess() }
                .buttonStyle(ChipStyle(selected: true))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.amber.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Theme.amber.opacity(0.35)))
        .modifier(Shake(animatableData: CGFloat(model.accessNudge)))
        .animation(.default, value: model.accessNudge)
    }
}

// MARK: - Settings

struct SettingsCard: View {
    @ObservedObject var model: ClickerModel

    var body: some View {
        VStack(spacing: 0) {
            speedSection
            divider
            row("Button", icon: "computermouse.fill") {
                PillPicker(selection: $model.button, options: MouseButton.allCases.map { ($0, $0.label) })
            }
            divider
            row("Click type", icon: "hand.tap.fill") {
                PillPicker(selection: $model.kind, options: ClickKind.allCases.map { ($0, $0.label) })
            }
            divider
            row("Target", icon: "scope") {
                PillPicker(selection: $model.target, options: TargetMode.allCases.map { ($0, $0.label) })
            }
            if model.target == .fixed {
                fixedPointRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            divider
            row("Stop after", icon: "flag.checkered",
                subtitle: model.limitEnabled ? "\(model.limit.formatted()) clicks" : "Never — runs until stopped") {
                stopAfterControl
            }
            divider
            row("Humanize", icon: "waveform.path", subtitle: "Randomize timing ±25%") {
                Toggle("", isOn: $model.humanize)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(Theme.violet)
                    .controlSize(.small)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color.white.opacity(0.1)))
        .overlay(alignment: .topTrailing) {
            if model.isBusy {
                Label("Locked while running", systemImage: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .offset(x: -14, y: -11)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .disabled(model.isBusy)
        .opacity(model.isBusy ? 0.6 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.target)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.isBusy)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.vertical, 10)
    }

    private var intervalText: String {
        let ms = 1000.0 / max(1, model.cps)
        return ms.rounded() == ms ? String(format: "every %.0f ms", ms) : String(format: "every %.1f ms", ms)
    }

    private var speedSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                IconBadge(name: "speedometer")
                Text("Speed").font(.system(size: 13, weight: .semibold))
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(model.cps))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: model.cps))
                        .animation(.snappy, value: model.cps)
                    Text("CPS")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            GlowSlider(value: $model.cps, range: 1...100)
            HStack(spacing: 6) {
                ForEach([5, 10, 20, 50], id: \.self) { preset in
                    Button("\(preset)") {
                        withAnimation(.snappy) { model.cps = Double(preset) }
                    }
                    .buttonStyle(ChipStyle(selected: Int(model.cps) == preset))
                }
                Spacer()
                Text(intervalText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
    }

    private var fixedPointRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.3))
                .frame(width: 26)
            Group {
                if let p = model.fixedPoint {
                    Text("x \(Int(p.x))   y \(Int(p.y))")
                        .foregroundStyle(Color.white.opacity(0.85))
                } else {
                    Text("No point set")
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .contentTransition(.numericText())
            Spacer()
            Button {
                model.pickPoint()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "scope")
                    Text(pickLabel).contentTransition(.numericText())
                }
            }
            .buttonStyle(ChipStyle(selected: model.pickCountdown != nil || model.fixedPoint == nil))
            .animation(.snappy, value: model.pickCountdown)
        }
        .padding(.top, 10)
        .modifier(Shake(animatableData: CGFloat(model.pointNudge)))
        .animation(.default, value: model.pointNudge)
    }

    private var pickLabel: String {
        if let n = model.pickCountdown { return "Hover target… \(n)" }
        return model.fixedPoint == nil ? "Pick point" : "Re-pick"
    }

    private var stopAfterControl: some View {
        HStack(spacing: 8) {
            if model.limitEnabled {
                TextField("", value: $model.limit, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(width: 62)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .transition(.scale.combined(with: .opacity))
            }
            Toggle("", isOn: $model.limitEnabled.animation(.spring(response: 0.3, dampingFraction: 0.75)))
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Theme.violet)
                .controlSize(.small)
        }
    }

    private func row<C: View>(_ title: String, icon: String, subtitle: String? = nil,
                              @ViewBuilder control: () -> C) -> some View {
        HStack(spacing: 10) {
            IconBadge(name: icon)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .frame(minHeight: 30)
    }
}

struct IconBadge: View {
    let name: String
    var body: some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.gradient)
            .frame(width: 26, height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.08)))
    }
}

// MARK: - Controls

struct PillPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let value = options[i].0
                let isSelected = value == selection
                Text(options[i].1)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.6))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Theme.gradient)
                                .shadow(color: Theme.violet.opacity(0.5), radius: 6, y: 2)
                                .matchedGeometryEffect(id: "pill", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selection = value }
                    }
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.07)))
    }
}

struct GlowSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let span = range.upperBound - range.lowerBound
            let frac = (value - range.lowerBound) / span
            let x = max(0, min(w, w * frac))
            let knob: CGFloat = dragging ? 20 : 16

            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                Capsule().fill(Theme.gradient)
                    .frame(width: max(6, x), height: 6)
                    .shadow(color: Theme.violet.opacity(0.7), radius: 6)
                Circle().fill(Color.white)
                    .frame(width: knob, height: knob)
                    .shadow(color: Theme.pink.opacity(0.8), radius: dragging ? 10 : 5)
                    .offset(x: min(max(0, x - knob / 2), w - knob))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        dragging = true
                        let f = max(0, min(1, g.location.x / max(1, w)))
                        value = (range.lowerBound + f * span).rounded()
                    }
                    .onEnded { _ in dragging = false }
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragging)
        }
        .frame(height: 22)
    }
}

struct ChipStyle: ButtonStyle {
    var selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(selected ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.white.opacity(0.08)))
            )
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat = 7
    var shakes: CGFloat = 4
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakes), y: 0))
    }
}

// MARK: - Hotkey hints

struct HotkeyHints: View {
    @ObservedObject var model: ClickerModel

    var body: some View {
        HStack(spacing: 5) {
            Keycap("⌥"); Keycap("⌘"); Keycap("K")
            Text("start / stop anywhere")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.leading, 3)
            Spacer()
            if model.isBusy {
                HStack(spacing: 5) {
                    Keycap("esc")
                    Text("stop")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.isBusy)
    }
}

struct Keycap: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(minWidth: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .shadow(color: Color.black.opacity(0.4), radius: 0, y: 1.5)
            )
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12)))
    }
}
