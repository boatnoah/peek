import AppKit
import SwiftUI

@MainActor class PreviewCardController {
    private var panel: NSPanel?

    static let xOffset: CGFloat = 12
    static let yOffset: CGFloat = 16
    static let cardSize = CGSize(width: 320, height: 200)

    func show(result: EnrichmentResult, near point: NSPoint) {
        let p = panel ?? makePanel()
        panel = p

        let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })
            ?? NSScreen.screens.first
            ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? CGRect(origin: .zero, size: CGSize(width: 1440, height: 900))

        let origin = Self.cardOrigin(for: point, cardSize: p.frame.size, screenFrame: screenFrame)
        p.setFrameOrigin(origin)

        p.contentView = NSHostingView(rootView: PreviewCardView(result: result))
        p.orderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.cardSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        return p
    }

    static func cardOrigin(for cursorPoint: NSPoint, cardSize: CGSize, screenFrame: CGRect) -> NSPoint {
        var x = cursorPoint.x + xOffset
        var y = cursorPoint.y + yOffset

        if x + cardSize.width > screenFrame.maxX {
            x = cursorPoint.x - cardSize.width - xOffset
        }

        if y + cardSize.height > screenFrame.maxY {
            y = cursorPoint.y - cardSize.height - yOffset
        }

        if x < screenFrame.minX {
            x = screenFrame.minX
        }

        if y < screenFrame.minY {
            y = screenFrame.minY
        }

        return NSPoint(x: x, y: y)
    }
}
