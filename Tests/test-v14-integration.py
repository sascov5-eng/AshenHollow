from pathlib import Path
import plistlib

scene = Path("Sources/GameSceneV14.swift").read_text()
view = Path("Sources/GameView.swift").read_text()
workflow = Path(".github/workflows/build-ipa.yml").read_text()
with open("Info.plist", "rb") as f:
    plist = plistlib.load(f)

checks = {
    "GameView uses GameSceneV14": "GameSceneV14" in view,
    "v1.4 label": "v1.4 • PERFECTED TEST LOCATION" in view,
    "version 1.4": plist.get("CFBundleShortVersionString") == "1.4",
    "bundle id preserved": plist.get("CFBundleIdentifier") == "app.ashenhollow.prototype",
    "build preserved": plist.get("CFBundleVersion") == "2",
    "camera zoom preserved": "private let cameraZoom: CGFloat = 1.75" in scene,
    "cinematic camera preserved": "cameraController.update" in scene and "CinematicCameraController" in scene,
    "player visual 480": "sprite.size = CGSize(width: 480, height: 480)" in scene,
    "player feet aligned": "sprite.position = CGPoint(x: 0, y: -8)" in scene,
    "attack hit radius": "attackButton, radius: 48" in scene,
    "dash hit radius": "dashButton, radius: 48" in scene,
    "heal hit radius": "healButton, radius: 44" in scene,
    "jump hit radius": "jumpButton, radius: 55" in scene,
    "four checkpoint runtime": "updateCheckpoints" in scene,
    "spike and pit runtime": "updateHazards" in scene and "HazardController.event" in scene,
    "moving platforms runtime": "updateMovingPlatforms" in scene,
    "enemy runtime": "updateEnemies" in scene,
    "tutorial runtime": "updateTutorial" in scene,
    "interaction runtime": "activateNearbyLeverOrSecret" in scene,
    "hurt/death runtime": "case .dead: next = .death" in scene and "case .hurt: next = .hurt" in scene,
    "no v1.4 string transform": "apply-v1.4" not in workflow,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit("FAIL v1.4 integration: " + ", ".join(failed))
print("PASS: v1.4 integration contract")
