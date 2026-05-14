import ApplicationServices
import AppKit
import Foundation

struct URLExtractor {
    private static let electronBundlePatterns = ["electron", ".electron."]
    private static let electronExecutableName = "Electron"
    private static let maxElectronDepth = 3

    func extractURL(at point: CGPoint) -> URL? {
        let systemElement = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemElement, Float(point.x), Float(point.y), &elementRef) == .success,
              let element = elementRef else {
            return nil
        }

        if let url = readURL(from: element) {
            return url
        }

        guard isElectronApp(for: element) else {
            return nil
        }

        return searchChildren(of: element, depth: Self.maxElectronDepth)
    }

    // MARK: - Private

    private func readURL(from element: AXUIElement) -> URL? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? URL
    }

    private func searchChildren(of element: AXUIElement, depth: Int) -> URL? {
        guard depth > 0 else { return nil }

        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else {
            return nil
        }

        for child in children {
            if let url = readURL(from: child) {
                return url
            }
            if let url = searchChildren(of: child, depth: depth - 1) {
                return url
            }
        }
        return nil
    }

    private func isElectronApp(for element: AXUIElement) -> Bool {
        guard let pid = pid(for: element),
              let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }

        if let bundleID = app.bundleIdentifier {
            let lower = bundleID.lowercased()
            if Self.electronBundlePatterns.contains(where: { lower.contains($0) }) {
                return true
            }
        }

        if let executableURL = app.executableURL {
            return executableURL.lastPathComponent == Self.electronExecutableName
        }

        return false
    }

    private func pid(for element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return pid
    }
}
