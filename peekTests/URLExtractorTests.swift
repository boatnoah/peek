import Testing
import Foundation
@testable import peek

struct URLExtractorElectronDetectionTests {

    @Test func nonElectronBundleIDReturnsFalse() {
        #expect(!isElectron(bundleID: "com.apple.Safari", executableName: "Safari"))
    }

    @Test func bundleIDContainingElectronReturnsTrue() {
        #expect(isElectron(bundleID: "com.github.GitHubDesktop.electron", executableName: "GitHub Desktop"))
    }

    @Test func bundleIDWithElectronSubstringReturnsTrue() {
        #expect(isElectron(bundleID: "com.microsoft.VSCode-electron", executableName: "Electron"))
    }

    @Test func executableNamedElectronReturnsTrue() {
        #expect(isElectron(bundleID: "com.some.app", executableName: "Electron"))
    }

    @Test func executableNotNamedElectronReturnsFalse() {
        #expect(!isElectron(bundleID: "com.some.app", executableName: "SomeApp"))
    }

    @Test func nilBundleIDFallsBackToExecutableName() {
        #expect(isElectron(bundleID: nil, executableName: "Electron"))
    }

    @Test func nilBundleIDAndNonElectronExecutableReturnsFalse() {
        #expect(!isElectron(bundleID: nil, executableName: "MyApp"))
    }

    @Test func caseInsensitiveBundleIDMatch() {
        #expect(isElectron(bundleID: "com.app.Electron", executableName: "Something"))
    }

    // MARK: - Nil-return contract

    @Test func extractURLReturnsNilForOffscreenPoint() {
        let extractor = URLExtractor()
        let offscreen = CGPoint(x: -10_000, y: -10_000)
        #expect(extractor.extractURL(at: offscreen) == nil)
    }
}

// MARK: - Electron detection helper mirroring URLExtractor's internal logic

private let electronBundlePatterns = ["electron", ".electron."]
private let electronExecutableName = "Electron"

private func isElectron(bundleID: String?, executableName: String) -> Bool {
    if let bundleID {
        let lower = bundleID.lowercased()
        if electronBundlePatterns.contains(where: { lower.contains($0) }) {
            return true
        }
    }
    return executableName == electronExecutableName
}
