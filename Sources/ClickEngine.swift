import Foundation
import CoreGraphics

/// Posts synthetic mouse clicks on a high-priority background queue.
/// All mutable state is only touched on `queue`.
final class ClickEngine {
    struct Config {
        var interval: TimeInterval
        var humanize: Bool
        var button: MouseButton
        var double: Bool
        var point: CGPoint?      // nil = click wherever the cursor is
        var limit: Int?          // nil = unlimited
    }

    typealias ClickHandler = @Sendable (_ gen: Int, _ count: Int) -> Void
    typealias FinishHandler = @Sendable (_ gen: Int) -> Void

    private let queue = DispatchQueue(label: "app.clicky.engine", qos: .userInteractive)
    private let source = CGEventSource(stateID: .hidSystemState)
    private var timer: DispatchSourceTimer?
    private var generation = 0
    private var count = 0
    private var config: Config?
    private var onClick: ClickHandler?
    private var onFinish: FinishHandler?

    /// Starts clicking. Returns a generation id so stale callbacks can be ignored.
    func start(_ config: Config, onClick: @escaping ClickHandler, onFinish: @escaping FinishHandler) -> Int {
        return queue.sync { () -> Int in
            timer?.cancel()
            generation += 1
            let gen = generation
            self.count = 0
            self.config = config
            self.onClick = onClick
            self.onFinish = onFinish

            let t = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
            t.setEventHandler { [weak self] in
                self?.tick(gen: gen)
            }
            timer = t
            t.schedule(deadline: .now(), leeway: .nanoseconds(0))
            t.resume()
            return gen
        }
    }

    func stop() {
        queue.sync {
            generation += 1
            timer?.cancel()
            timer = nil
            onClick = nil
            onFinish = nil
        }
    }

    // Runs on `queue`.
    private func tick(gen: Int) {
        guard generation == gen, let timer, let config else { return }
        performClick(config)
        count += 1
        onClick?(gen, count)
        if let limit = config.limit, count >= limit {
            timer.cancel()
            self.timer = nil
            onFinish?(gen)
            return
        }
        timer.schedule(deadline: .now() + nextDelay(config), leeway: .nanoseconds(0))
    }

    private func nextDelay(_ c: Config) -> TimeInterval {
        guard c.humanize else { return c.interval }
        return max(0.001, c.interval * Double.random(in: 0.75...1.25))
    }

    private func performClick(_ c: Config) {
        let position = c.point ?? CGEvent(source: nil)?.location ?? .zero

        let downType: CGEventType
        let upType: CGEventType
        let cgButton: CGMouseButton
        switch c.button {
        case .left:
            downType = .leftMouseDown; upType = .leftMouseUp; cgButton = .left
        case .right:
            downType = .rightMouseDown; upType = .rightMouseUp; cgButton = .right
        case .middle:
            downType = .otherMouseDown; upType = .otherMouseUp; cgButton = .center
        }

        let presses = c.double ? 2 : 1
        for i in 1...presses {
            let down = CGEvent(mouseEventSource: source, mouseType: downType,
                               mouseCursorPosition: position, mouseButton: cgButton)
            let up = CGEvent(mouseEventSource: source, mouseType: upType,
                             mouseCursorPosition: position, mouseButton: cgButton)
            down?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
            up?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
}
