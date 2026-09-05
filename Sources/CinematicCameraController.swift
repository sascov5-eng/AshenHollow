import Foundation
import CoreGraphics

struct CinematicCameraController {
    private(set) var position: CGPoint = .zero
    private(set) var lookAheadX: CGFloat = 0

    let horizontalDeadZone: CGFloat = 128
    let verticalDeadZone: CGFloat = 78
    let lookAheadDistance: CGFloat = 150
    let horizontalFollowSpeed: CGFloat = 4.4
    let verticalFollowSpeed: CGFloat = 2.1
    let lookAheadResponse: CGFloat = 3.2

    mutating func reset(
        playerPosition: CGPoint,
        viewportSize: CGSize,
        zoom: CGFloat,
        worldBounds: CGRect
    ) -> CGPoint {
        lookAheadX = 0
        position = clamp(
            point: playerPosition,
            viewportSize: viewportSize,
            zoom: zoom,
            worldBounds: worldBounds
        )
        return position
    }

    mutating func update(
        playerPosition: CGPoint,
        velocity: CGVector,
        facing: CGFloat,
        dt: CGFloat,
        viewportSize: CGSize,
        zoom: CGFloat,
        worldBounds: CGRect
    ) -> CGPoint {
        let safeDT = max(0, min(dt, 0.25))
        let speedFactor = min(abs(velocity.dx) / 315, 1)
        let direction: CGFloat
        if abs(velocity.dx) > 8 {
            direction = velocity.dx >= 0 ? 1 : -1
        } else {
            direction = facing >= 0 ? 1 : -1
        }

        let desiredLookAhead = direction * lookAheadDistance * speedFactor
        let lookAlpha = smoothingAlpha(speed: lookAheadResponse, dt: safeDT)
        lookAheadX += (desiredLookAhead - lookAheadX) * lookAlpha

        var target = position
        let trackedX = playerPosition.x + lookAheadX
        if trackedX < position.x - horizontalDeadZone {
            target.x = trackedX + horizontalDeadZone
        } else if trackedX > position.x + horizontalDeadZone {
            target.x = trackedX - horizontalDeadZone
        }

        if playerPosition.y < position.y - verticalDeadZone {
            target.y = playerPosition.y + verticalDeadZone
        } else if playerPosition.y > position.y + verticalDeadZone {
            target.y = playerPosition.y - verticalDeadZone
        }

        let xAlpha = smoothingAlpha(speed: horizontalFollowSpeed, dt: safeDT)
        let yAlpha = smoothingAlpha(speed: verticalFollowSpeed, dt: safeDT)
        position.x += (target.x - position.x) * xAlpha
        position.y += (target.y - position.y) * yAlpha

        position = clamp(
            point: position,
            viewportSize: viewportSize,
            zoom: zoom,
            worldBounds: worldBounds
        )
        return position
    }

    private func smoothingAlpha(speed: CGFloat, dt: CGFloat) -> CGFloat {
        guard speed > 0, dt > 0 else { return 0 }
        return 1 - CGFloat(exp(Double(-speed * dt)))
    }

    private func clamp(
        point: CGPoint,
        viewportSize: CGSize,
        zoom: CGFloat,
        worldBounds: CGRect
    ) -> CGPoint {
        let halfWidth = viewportSize.width * zoom * 0.5
        let halfHeight = viewportSize.height * zoom * 0.5

        let minX = worldBounds.minX + halfWidth
        let maxX = worldBounds.maxX - halfWidth
        let minY = worldBounds.minY + halfHeight
        let maxY = worldBounds.maxY - halfHeight

        let x = minX <= maxX ? max(minX, min(maxX, point.x)) : worldBounds.midX
        let y = minY <= maxY ? max(minY, min(maxY, point.y)) : worldBounds.midY
        return CGPoint(x: x, y: y)
    }
}
