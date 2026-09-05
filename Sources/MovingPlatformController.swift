import Foundation
import CoreGraphics

struct MovingPlatformRuntimeState: Equatable {
    var position: CGPoint
    var direction: CGFloat
}

final class MovingPlatformController {
    let spec: MovingPlatformSpec
    private(set) var state: MovingPlatformRuntimeState

    init(spec: MovingPlatformSpec) {
        self.spec = spec
        self.state = MovingPlatformRuntimeState(position: spec.start, direction: 1)
    }

    func update(dt: TimeInterval) -> CGVector {
        guard dt > 0 else { return .zero }
        let old = state.position
        let distance = spec.speed * CGFloat(dt) * state.direction
        switch spec.axis {
        case .horizontal:
            state.position.x += distance
            if state.position.x >= spec.end.x { state.position.x = spec.end.x; state.direction = -1 }
            if state.position.x <= spec.start.x { state.position.x = spec.start.x; state.direction = 1 }
            state.position.y = spec.start.y
        case .vertical:
            state.position.y += distance
            if state.position.y >= spec.end.y { state.position.y = spec.end.y; state.direction = -1 }
            if state.position.y <= spec.start.y { state.position.y = spec.start.y; state.direction = 1 }
            state.position.x = spec.start.x
        }
        return CGVector(dx: state.position.x - old.x, dy: state.position.y - old.y)
    }

    var frame: CGRect {
        CGRect(x: state.position.x - spec.size.width * 0.5,
               y: state.position.y - spec.size.height * 0.5,
               width: spec.size.width, height: spec.size.height)
    }
}
