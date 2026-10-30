import AppKit
import SwiftUI

/// Briefly shows an animated target marker on screen where a fixed point was picked.
@MainActor
enum PointFlash {
    static func show(at cgPoint: CGPoint) {
        guard let primary = NSScreen.screens.first else { return }
        let size: CGFloat = 140
        // CoreGraphics uses a top-left origin; AppKit windows use bottom-left.
        let center = NSPoint(x: cgPoint.x, y: primary.frame.height - cgPoint.y)
        let rect = NSRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)

        let panel = NSPanel(contentRect: rect,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: FlashView())
        panel.orderFrontRegardless()

        panel.isReleasedWhenClosed = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            panel.orderOut(nil)
        }
    }
}

private struct FlashView: View {
    @State private var go = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Theme.gradient, lineWidth: 3)
                    .frame(width: 130, height: 130)
                    .scaleEffect(go ? 1 : 0.1)
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: 1.2).delay(Double(i) * 0.18), value: go)
            }
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.white)
                .shadow(color: Theme.violet, radius: 6)
                .scaleEffect(go ? 1 : 0.2)
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: go)
        }
        .frame(width: 140, height: 140)
        .onAppear { go = true }
    }
}
