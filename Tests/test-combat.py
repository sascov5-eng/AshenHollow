from pathlib import Path

scene = Path("Sources/GameSceneV14.swift").read_text()
library = Path("Sources/PlayerAnimationLibrary.swift").read_text()
layout = Path("Sources/TestLocationLayout.swift").read_text()
runtime = Path("Sources/V15RuntimeSupport.swift").read_text()
knight = Path("Resources/KnightArt")

checks = {
    "up attack key": "attackUp" in library,
    "down attack key": "attackDown" in library,
    "directional start": "direction = .down" in scene,
    "lever strike": "strikeNearbyLevers" in scene,
    "pogo bounce": "currentDirection == .down" in scene,
    "door always opens": 'childNode(withName: "//doorBody") ?? root' in scene,
    "shaft doorway": "CGRect(x: 5320, y: 340, width: 56, height: 930)" in layout,
    "shortcut door in wall": "CGRect(x: 5320, y: 90, width: 56, height: 250)" in layout,
    "grub enemy": "enemy_grub.png" in runtime,
    "idle strip": (knight / "Idle.png").is_file(),
    "pogo strip": (knight / "AttackDown.png").is_file(),
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit("combat contract failures: " + ", ".join(failed))
print("Combat contract PASS")
