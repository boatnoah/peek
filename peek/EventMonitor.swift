import AppKit
import Foundation

final class EventMonitor: @unchecked Sendable {
    private let dwellInterval: TimeInterval
    private let onDwell: @Sendable (CGPoint) -> Void
    private let onMove: (@Sendable (CGPoint) -> Void)?
    private let queue: DispatchQueue

    private var globalMonitor: Any?
    private var timer: DispatchSourceTimer?
    private var pendingPoint: CGPoint = .zero

    init(
        dwellInterval: TimeInterval = 0.3,
        queue: DispatchQueue = DispatchQueue(label: "com.boatnoah.peek.eventmonitor", qos: .userInteractive),
        onMove: (@Sendable (CGPoint) -> Void)? = nil,
        onDwell: @escaping @Sendable (CGPoint) -> Void
    ) {
        self.dwellInterval = dwellInterval
        self.queue = queue
        self.onMove = onMove
        self.onDwell = onDwell
    }

    func start() {
        guard globalMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self else { return }
            // NSEvent.mouseLocation is in AppKit screen coords (y=0 at bottom-left).
            // AXUIElementCopyElementAtPosition expects Quartz coords (y=0 at top-left).
            let appKitPoint = NSEvent.mouseLocation
            let screenHeight = NSScreen.screens.first?.frame.height ?? 0
            let quartzPoint = CGPoint(x: appKitPoint.x, y: screenHeight - appKitPoint.y)
            self.queue.async {
                self.handleMouseMoved(to: quartzPoint)
            }
        }

        if globalMonitor == nil {
            peekLog("[Peek] EventMonitor: NSEvent global monitor FAILED — Accessibility permission likely missing")
        } else {
            peekLog("[Peek] EventMonitor: global monitor started, listening for mouse events")
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        queue.async { [weak self] in
            self?.cancelTimer()
        }
    }

    // MARK: - Private

    private func handleMouseMoved(to point: CGPoint) {
        onMove?(point)
        pendingPoint = point
        cancelTimer()

        let newTimer = DispatchSource.makeTimerSource(queue: queue)
        newTimer.schedule(deadline: .now() + dwellInterval)
        newTimer.setEventHandler { [weak self] in
            guard let self else { return }
            peekLog("[Peek] EventMonitor: dwell fired at \(self.pendingPoint)")
            self.onDwell(self.pendingPoint)
        }
        newTimer.resume()
        timer = newTimer
    }

    private func cancelTimer() {
        timer?.cancel()
        timer = nil
    }
}
