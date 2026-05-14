import CoreGraphics
import Foundation

final class EventMonitor: @unchecked Sendable {
    private let dwellInterval: TimeInterval
    private let onDwell: @Sendable (CGPoint) -> Void
    private let queue: DispatchQueue

    private var tapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: DispatchSourceTimer?
    private var pendingPoint: CGPoint = .zero

    init(
        dwellInterval: TimeInterval = 0.3,
        queue: DispatchQueue = DispatchQueue(label: "com.boatnoah.peek.eventmonitor", qos: .userInteractive),
        onDwell: @escaping @Sendable (CGPoint) -> Void
    ) {
        self.dwellInterval = dwellInterval
        self.queue = queue
        self.onDwell = onDwell
    }

    func start() {
        let selfPtr = Unmanaged.passRetained(self)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.mouseMoved.rawValue),
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                let point = event.location
                monitor.queue.async {
                    monitor.handleMouseMoved(to: point)
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr.toOpaque()
        ) else {
            selfPtr.release()
            return
        }

        tapPort = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        queue.async { [weak self] in
            self?.cancelTimer()
        }

        if let tap = tapPort {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = tapPort {
            CFMachPortInvalidate(tap)
        }
        tapPort = nil
        runLoopSource = nil
    }

    // MARK: - Private

    private func handleMouseMoved(to point: CGPoint) {
        pendingPoint = point
        cancelTimer()

        let newTimer = DispatchSource.makeTimerSource(queue: queue)
        newTimer.schedule(deadline: .now() + dwellInterval)
        newTimer.setEventHandler { [weak self] in
            guard let self else { return }
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
