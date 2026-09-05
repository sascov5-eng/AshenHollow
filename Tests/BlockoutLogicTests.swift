import Foundation
import CoreGraphics

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct BlockoutLogicTests {
    static func main() {
        let layout = LargeWorldLayout.blockout
        expect(layout.bounds.width >= 844 * 8, "world must span at least eight reference screens horizontally")
        expect(layout.bounds.height >= 390 * 4, "world must span at least four reference screens vertically")
        expect(layout.collisionRects.count >= 20, "blockout needs architectural collision, not a few floating platforms")
        expect(layout.collisionRects.contains { $0.height >= 900 && $0.width <= 90 }, "blockout must contain tall shaft walls")
        expect(layout.spawnPoint.x > layout.bounds.minX && layout.spawnPoint.x < layout.bounds.maxX, "spawn must be inside world bounds")

        let viewport = CGSize(width: 844, height: 390)
        let zoom: CGFloat = 1.28
        var camera = CinematicCameraController()
        let start = CGPoint(x: 2200, y: 620)
        let initial = camera.reset(playerPosition: start, viewportSize: viewport, zoom: zoom, worldBounds: layout.bounds)

        let inside = camera.update(
            playerPosition: CGPoint(x: start.x + 20, y: start.y + 12),
            velocity: .zero,
            facing: 1,
            dt: 1.0 / 60.0,
            viewportSize: viewport,
            zoom: zoom,
            worldBounds: layout.bounds
        )
        expect(abs(inside.x - initial.x) < 1, "player motion inside horizontal dead zone should not drag camera")
        expect(abs(inside.y - initial.y) < 1, "small vertical motion should stay inside vertical dead zone")

        let outside = camera.update(
            playerPosition: CGPoint(x: start.x + 420, y: start.y),
            velocity: CGVector(dx: 315, dy: 0),
            facing: 1,
            dt: 0.20,
            viewportSize: viewport,
            zoom: zoom,
            worldBounds: layout.bounds
        )
        expect(outside.x > initial.x + 10, "leaving dead zone must move camera")
        expect(camera.lookAheadX > 0, "running right must create positive look-ahead")

        let lookBeforeReverse = camera.lookAheadX
        _ = camera.update(
            playerPosition: CGPoint(x: start.x + 410, y: start.y),
            velocity: CGVector(dx: -315, dy: 0),
            facing: -1,
            dt: 1.0 / 60.0,
            viewportSize: viewport,
            zoom: zoom,
            worldBounds: layout.bounds
        )
        expect(camera.lookAheadX > -lookBeforeReverse, "look-ahead must not snap fully across on one reverse frame")

        let clamped = camera.reset(
            playerPosition: CGPoint(x: layout.bounds.minX, y: layout.bounds.minY),
            viewportSize: viewport,
            zoom: zoom,
            worldBounds: layout.bounds
        )
        let halfW = viewport.width * zoom * 0.5
        let halfH = viewport.height * zoom * 0.5
        expect(clamped.x >= layout.bounds.minX + halfW - 0.1, "camera must clamp left edge")
        expect(clamped.y >= layout.bounds.minY + halfH - 0.1, "camera must clamp bottom edge")

        print("PASS: large world and cinematic camera logic")
    }
}
