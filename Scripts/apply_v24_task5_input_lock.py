from pathlib import Path

path = Path("Sources/GameScene.swift")
text = path.read_text()

if "func setExternalInputLocked(_ locked: Bool)" in text:
    print("V24 external input lock already present")
    raise SystemExit(0)


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"expected exactly one match, found {count}: {old[:120]!r}")
    text = text.replace(old, new, 1)

replace_once(
    """    private var dashController = DashController()\n    private var wallTraversalController = WallTraversalController()\n    private var currentWallClingSide: WallSide?\n\n    // MARK: - Combat""",
    """    private var dashController = DashController()\n    private var wallTraversalController = WallTraversalController()\n    private var currentWallClingSide: WallSide?\n    private(set) var externalInputLocked = false\n\n    // MARK: - Combat""",
)

replace_once(
    """        dashController = DashController()\n        wallTraversalController = WallTraversalController()\n        currentWallClingSide = nil\n    }""",
    """        dashController = DashController()\n        wallTraversalController = WallTraversalController()\n        currentWallClingSide = nil\n        externalInputLocked = false\n    }""",
)

replace_once(
    """    // MARK: - Touch input\n\n    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {\n        guard let skView = view else { return }""",
    """    // MARK: - Touch input\n\n    func setExternalInputLocked(_ locked: Bool) {\n        externalInputLocked = locked\n        if locked {\n            activeControls.removeAll(keepingCapacity: true)\n            moveInput = 0\n            smoothedMoveInput = 0\n            cancelFocus()\n        }\n        refreshButtonVisuals()\n    }\n\n    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {\n        guard !externalInputLocked, let skView = view else { return }""",
)

replace_once(
    """    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {\n        guard let skView = view else { return }""",
    """    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {\n        guard !externalInputLocked, let skView = view else { return }""",
)

path.write_text(text)
print("Applied V24 external input lock to GameScene.swift")
