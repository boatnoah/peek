import AppKit
import SwiftUI

@MainActor class PreviewCardController {
    private var panel: NSPanel?

    nonisolated static let xOffset: CGFloat = 12
    nonisolated static let yOffset: CGFloat = 16
    nonisolated static let cardSize = CGSize(width: 320, height: 200)

    func show(result: EnrichmentResult, near quartzPoint: NSPoint) {
        // NSEvent.mouseLocation uses AppKit coords (y=0 at bottom) and EventMonitor
        // converts to Quartz (y=0 at top) for AX hit-testing. Convert back here for
        // AppKit window positioning.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let point = NSPoint(x: quartzPoint.x, y: primaryHeight - quartzPoint.y)

        let p = panel ?? makePanel()
        panel = p

        let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })
            ?? NSScreen.screens.first
            ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? CGRect(origin: .zero, size: CGSize(width: 1440, height: 900))

        let origin = Self.cardOrigin(for: point, cardSize: p.frame.size, screenFrame: screenFrame)
        p.setFrameOrigin(origin)
        peekLog("[Peek] Card origin=\(origin) screenFrame=\(screenFrame)")

        p.contentView = NSHostingView(rootView: PreviewCardView(result: result))
        p.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.cardSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = true
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        return p
    }

    nonisolated static func cardOrigin(for cursorPoint: NSPoint, cardSize: CGSize, screenFrame: CGRect) -> NSPoint {
        var x = cursorPoint.x + xOffset

        // In AppKit coords (y=0 at bottom), the card appears below the cursor by
        // placing its top edge at cursorPoint.y - yOffset, i.e. origin at:
        var y = cursorPoint.y - cardSize.height - yOffset

        // If it clips the bottom of the visible area, flip above the cursor instead.
        if y < screenFrame.minY {
            y = cursorPoint.y + yOffset
        }

        // If flipping above also clips the top, clamp to visible area.
        if y + cardSize.height > screenFrame.maxY {
            y = screenFrame.maxY - cardSize.height
        }

        if x + cardSize.width > screenFrame.maxX {
            x = cursorPoint.x - cardSize.width - xOffset
        }

        if x < screenFrame.minX {
            x = screenFrame.minX
        }

        return NSPoint(x: x, y: y)
    }
}
