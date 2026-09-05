from pathlib import Path

scene = Path("Sources/GameScene.swift").read_text()
view = Path("Sources/GameView.swift").read_text()
plist = Path("Info.plist").read_text()

checks = {
    "camera zoomed out": "private let cameraZoom: CGFloat = 1.75" in scene,
    "sprite feet aligned": "sprite.position = CGPoint(x: 0, y: -8)" in scene,
    "jump hit radius fixed": "button: jumpButton, radius: 55" in scene,
    "attack hit radius fixed": "button: attackButton, radius: 48" in scene,
    "dash hit radius fixed": "button: dashButton, radius: 48" in scene,
    "heal hit radius fixed": "button: healButton, radius: 44" in scene,
    "single attack animation": "activeAttackAnimation = .attack1" in scene and "useSecondAttack.toggle()" not in scene,
    "legacy slash removed": "let slash = SKShapeNode()" not in scene,
    "v1.3 label": "v1.3 • CAMERA • GROUND • ATTACK • CONTROLS" in view,
    "v1.3 plist": "<key>CFBundleShortVersionString</key><string>1.3</string>" in plist,
    "jump sfx": "audio.play(.jump)" in scene,
    "attack sfx": "audio.play(.attack)" in scene,
    "dash sfx": "audio.play(.dash)" in scene,
    "heal sfx": "audio.play(.heal)" in scene,
    "footstep sfx": "audio.play(.footstep)" in scene,
    "heal cancel stop": "audio.stop(.heal)" in scene,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit("v1.3 contract failures: " + ", ".join(failed))

attack_index = scene.find("button: attackButton, radius: 48")
dash_index = scene.find("button: dashButton, radius: 48")
heal_index = scene.find("button: healButton, radius: 44")
jump_index = scene.find("button: jumpButton, radius: 55")
if not (0 <= attack_index < dash_index < heal_index < jump_index):
    raise SystemExit("v1.3 contract failure: action button priority order")

print("v1.3 integration contract PASS")
