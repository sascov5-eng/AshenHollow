#!/usr/bin/env python3
from pathlib import Path

scene_path = Path("Sources/GameSceneV14.swift")
view_path = Path("Sources/GameView.swift")
scene = scene_path.read_text()
if "private let kingdom = KingdomDirector()" in scene:
    print("Kingdom already applied")
    raise SystemExit(0)

def replace_from(text, start, replacement):
    a = text.find(start)
    if a < 0:
        raise SystemExit(f"kingdom missing: {start[:90]}")
    b = text.find("    private func ", a + len(start))
    if b < 0:
        raise SystemExit(f"kingdom missing next func after {start[:40]}")
    return text[:a] + replacement.rstrip() + "\n\n" + text[b:]

if "private let audio = GameAudio()" in scene:
    scene = scene.replace(
        "    private let audio = GameAudio()\n",
        "    private let audio = GameAudio()\n    private let kingdom = KingdomDirector()\n",
        1,
    )
else:
    scene = scene.replace(
        "    private var lastUpdateTime: TimeInterval = 0\n",
        "    private var lastUpdateTime: TimeInterval = 0\n    private let kingdom = KingdomDirector()\n",
        1,
    )

if "EnvArt.installAtmosphere(in: self)" in scene and "kingdom.install" not in scene:
    scene = scene.replace(
        "        EnvArt.installAtmosphere(in: self)\n",
        "        EnvArt.installAtmosphere(in: self)\n        kingdom.install(on: hud, camera: gameCamera)\n        kingdom.layout(viewport: size)\n",
        1,
    )
elif "buildHUD()" in scene and "kingdom.install" not in scene:
    scene = scene.replace(
        "        layoutHUD()\n",
        "        layoutHUD()\n        kingdom.install(on: hud, camera: gameCamera)\n        kingdom.layout(viewport: size)\n",
        1,
    )

if "kingdom.refresh" not in scene:
    if "        updateHUDStatus()\n" in scene:
        scene = scene.replace(
            "        updateHUDStatus()\n",
            "        updateHUDStatus()\n        kingdom.refresh(hp: currentHP, maxHP: maxHP, soul: essenceController.essence, soulMax: essenceController.maxEssence, playerX: player.position.x)\n",
            1,
        )

if "controller.spec.damagesOnTouch" not in scene:
    scene = scene.replace(
        "            guard controller.isAlive else { continue }\n",
        "            guard controller.isAlive, controller.spec.damagesOnTouch else { continue }\n",
        1,
    )

if "kingdom.addGeo" not in scene:
    scene = scene.replace(
        "            if controller.receiveMeleeHit() {",
        "            if controller.receiveMeleeHit(damage: kingdom.nailDamage) {\n                kingdom.addGeo(controller.spec.geoReward)",
        1,
    )

scene = replace_from(
    scene,
    "    private func addWorldCaption(_ text: String, at position: CGPoint, color: UIColor) {",
    "    private func addWorldCaption(_ text: String, at position: CGPoint, color: UIColor) {\n        return\n    }\n",
)

if "layoutHUD()" in scene and "kingdom.layout" in scene:
    scene = scene.replace(
        "        statusLabel.position = CGPoint(x: halfW - 175, y: halfH - 58)\n",
        "        statusLabel.position = CGPoint(x: halfW - 175, y: halfH - 58)\n        kingdom.layout(viewport: size)\n",
        1,
    )

# Hide debug status line; real HUD is the masks.
if "statusLabel.text =" in scene:
    import re
    scene = re.sub(
        r"        statusLabel\.text = .*",
        '        statusLabel.text = ""',
        scene,
        count=3,
    )

scene_path.write_text(scene)

view = view_path.read_text()
replacements = {
    "v1.4 • PERFECTED TEST LOCATION": "Пепельный крест",
    "v1.7 • DEVICE BUGFIX • SAFE TRIALS • SFX": "Пепельный крест",
    "v1.7 • DEVICE BUGFIX • SAFE TRIALS": "Пепельный крест",
    "TRIALS": "ИСПЫТАНИЯ",
    "PLAY": "ИГРАТЬ",
    "SETTINGS": "НАСТРОЙКИ",
    "ABOUT": "ОБ ИГРЕ",
    "RESUME": "ПРОДОЛЖИТЬ",
    "RESTART": "ЗАНОВО",
    "MENU": "МЕНЮ",
    "PAUSED": "ПАУЗА",
    "RESULTS": "ИТОГ",
}
for old, new in replacements.items():
    view = view.replace(old, new)
view_path.write_text(view)
print("Applied kingdom HUD, charms, silent captions, Russian shell")
