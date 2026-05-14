import Combine
import SwiftUI
import AppKit

// Debug logger — writes to /tmp/peek-debug.log so output is visible outside Xcode
func peekLog(_ msg: String) {
    let line = msg + "\n"
    if let data = line.data(using: .utf8) {
        let logPath = (NSHomeDirectory() as NSString).appendingPathComponent("peek-debug.log")
        if FileManager.default.fileExists(atPath: logPath) {
            let handle = FileHandle(forWritingAtPath: logPath)
            handle?.seekToEndOfFile()
            handle?.write(data)
            handle?.closeFile()
        } else {
            try? data.write(to: URL(fileURLWithPath: logPath))
        }
    }
    print(msg)
}

@MainActor class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var isEnabled: Bool = true {
        didSet { isEnabled ? monitor?.start() : disableMonitor() }
    }
    @Published var linkCount: Int = 0

    private var monitor: EventMonitor?
    private var cardController: PreviewCardController?
    private var pipeline: EnrichmentPipeline?
    private var enrichTask: Task<Void, Never>?
    private var permissionTimer: Timer?
    private var dwellPoint: CGPoint = .zero
    private let moveCancelThreshold: CGFloat = 50

    func applicationDidFinishLaunching(_ notification: Notification) {
        peekLog("[Peek] applicationDidFinishLaunching fired — pid=\(ProcessInfo.processInfo.processIdentifier)")
        NSApp.setActivationPolicy(.accessory)
        guard !Self.isRunningUnitTests() else { return }
        requestAccessibilityPermissionAndSetup()
    }

    private func requestAccessibilityPermissionAndSetup() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        if AXIsProcessTrustedWithOptions(options as CFDictionary) {
            peekLog("[Peek] Accessibility already trusted — starting setup")
            setup()
        } else {
            peekLog("[Peek] Accessibility NOT trusted — waiting for permission. Open System Settings → Privacy & Security → Accessibility and enable Peek.")
            // Poll until the user grants access, then start without requiring a relaunch.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    Task { @MainActor [weak self] in
                        peekLog("[Peek] Accessibility permission granted — starting setup")
                        self?.permissionTimer = nil
                        self?.setup()
                    }
                }
            }
        }
    }

    private func setup() {
        let card = PreviewCardController()
        cardController = card
        pipeline = EnrichmentPipeline(
            cache: PreviewCache(),
            resolver: RedirectResolver(),
            threatChecker: SafeBrowsingClient(
                apiKey: ProcessInfo.processInfo.environment["SAFE_BROWSING_API_KEY"]
            ),
            llm: GeminiProvider(
                apiKey: ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
            )
        )

        let mon = EventMonitor(
            onMove: { [weak self] point in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let dx = point.x - self.dwellPoint.x
                    let dy = point.y - self.dwellPoint.y
                    if dx * dx + dy * dy > self.moveCancelThreshold * self.moveCancelThreshold {
                        self.cancelEnrichAndHide()
                    }
                }
            },
            onDwell: { [weak self] point in
                Task { @MainActor [weak self] in self?.handleDwell(at: point) }
            }
        )
        monitor = mon
        mon.start()
    }

    private func handleDwell(at point: CGPoint) {
        dwellPoint = point
        let url = URLExtractor().extractURL(at: point)
        peekLog("[Peek] Dwell at \(point) — URL extracted: \(url?.absoluteString ?? "nil")")
        guard let url else {
            cancelEnrichAndHide()
            return
        }
        guard let pipeline, let cardController else {
            peekLog("[Peek] pipeline or cardController is nil — setup may not have run")
            return
        }
        enrichTask?.cancel()
        enrichTask = Task {
            peekLog("[Peek] Enriching \(url.absoluteString)")
            let result = await pipeline.enrich(url)
            guard !Task.isCancelled else {
                peekLog("[Peek] Enrich task cancelled before card shown")
                return
            }
            peekLog("[Peek] Showing card for \(result.resolvedDomain) — badge: \(result.trustBadge)")
            cardController.show(result: result, near: point)
            self.linkCount += 1
        }
    }

    private func cancelEnrichAndHide() {
        enrichTask?.cancel()
        enrichTask = nil
        cardController?.hide()
    }

    private func disableMonitor() {
        monitor?.stop()
        cancelEnrichAndHide()
    }

    nonisolated static func isRunningUnitTests(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}

@main
struct peekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Peek", systemImage: "eye") {
            Toggle("Enable Peek", isOn: Binding(
                get: { appDelegate.isEnabled },
                set: { appDelegate.isEnabled = $0 }
            ))

            Divider()

            Text("\(appDelegate.linkCount) links this session")
                .foregroundStyle(.secondary)

            Divider()

            Button("Quit Peek") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
