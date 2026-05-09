import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestAccessibilityPermission()
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

@main
struct peekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isEnabled = true
    @State private var linkCount = 0

    var body: some Scene {
        MenuBarExtra("Peek", systemImage: "eye") {
            Toggle("Enable Peek", isOn: $isEnabled)

            Divider()

            Text("\(linkCount) links today")
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
