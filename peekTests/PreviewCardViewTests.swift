import Testing
import AppKit
@testable import peek

struct PreviewCardViewTests {

    // MARK: - Helpers

    private let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let cardSize = PreviewCardController.cardSize

    private func origin(for point: NSPoint) -> NSPoint {
        PreviewCardController.cardOrigin(for: point, cardSize: cardSize, screenFrame: screenFrame)
    }

    // MARK: - Default positioning

    @Test func cardIsPlaced12RightAnd16BelowCursor() {
        let cursor = NSPoint(x: 400, y: 400)
        let result = origin(for: cursor)

        #expect(result.x == cursor.x + PreviewCardController.xOffset)
        #expect(result.y == cursor.y - cardSize.height - PreviewCardController.yOffset)
    }

    // MARK: - Horizontal overflow

    @Test func cardFlipsLeftWhenItWouldOverflowRightEdge() {
        let cursor = NSPoint(x: 1400, y: 400)
        let result = origin(for: cursor)

        #expect(result.x < cursor.x)
    }

    // MARK: - Vertical overflow

    @Test func cardFlipsUpWhenItWouldOverflowBottomEdge() {
        let cursor = NSPoint(x: 400, y: 20)
        let result = origin(for: cursor)

        #expect(result.y > cursor.y)
    }

    // MARK: - Both edges overflow

    @Test func cardClampsToScreenWhenBothEdgesOverflow() {
        let cursor = NSPoint(x: 1430, y: 890)
        let result = origin(for: cursor)

        #expect(result.x >= screenFrame.minX)
        #expect(result.y >= screenFrame.minY)
    }

    // MARK: - No overflow

    @Test func cardRemainsCentreScreenWithoutFlipping() {
        let cursor = NSPoint(x: 600, y: 400)
        let result = origin(for: cursor)

        #expect(result.x == cursor.x + PreviewCardController.xOffset)
        #expect(result.y == cursor.y - cardSize.height - PreviewCardController.yOffset)
    }
}
