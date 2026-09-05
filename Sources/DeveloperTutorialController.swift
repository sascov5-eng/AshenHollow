import Foundation
import CoreGraphics

struct TutorialPresentation: Equatable {
    let mechanic: TestMechanicID
    let text: String
    let target: TutorialTarget
}

final class DeveloperTutorialController {
    private let layout: TestLocationSpec
    private let session: TestSessionState
    private(set) var presentation: TutorialPresentation?

    init(layout: TestLocationSpec, session: TestSessionState) {
        self.layout = layout
        self.session = session
    }

    func update(playerPosition: CGPoint) {
        if let current = presentation, session.completedTutorials.contains(current.mechanic) {
            presentation = nil
        }
        guard presentation == nil else { return }
        guard let spec = layout.tutorials.first(where: {
            $0.trigger.contains(playerPosition) && !session.completedTutorials.contains($0.mechanic)
        }) else { return }
        presentation = TutorialPresentation(mechanic: spec.mechanic, text: spec.text, target: spec.target)
    }

    func register(action mechanic: TestMechanicID) {
        guard let current = presentation, current.mechanic == mechanic else { return }
        session.completedTutorials.insert(mechanic)
        presentation = nil
    }

    func completeCurrentNonInputHint() {
        guard let current = presentation else { return }
        session.completedTutorials.insert(current.mechanic)
        presentation = nil
    }
}
