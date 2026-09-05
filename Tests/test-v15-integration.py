#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
scene = (root / "Sources/GameSceneV14.swift").read_text(encoding="utf-8")
layout = (root / "Sources/TestLocationLayout.swift").read_text(encoding="utf-8")
view = (root / "Sources/GameView.swift").read_text(encoding="utf-8")
plist = (root / "Info.plist").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/build-ipa.yml").read_text(encoding="utf-8")

# Release identity and visible install proof.
assert '<key>CFBundleShortVersionString</key><string>1.5</string>' in plist
assert 'v1.5 • ПОНЯТНЫЕ МЕХАНИКИ • RU' in view
assert '<key>CFBundleIdentifier</key><string>app.ashenhollow.prototype</string>' in plist
assert '<key>CFBundleVersion</key><string>2</string>' in plist

# Russian player-facing UI/tutorial contract.
for text in ["ПРЫЖОК", "АТАКА", "РЫВОК", "ЛЕЧЕНИЕ", "ДЕЙСТВИЕ", "ЗДОРОВЬЕ", "СВЕТ"]:
    assert text in scene, text
for text in ["ДВИЖЕНИЕ", "КОНТРОЛЬНАЯ ТОЧКА", "ШИПЫ", "ДВИЖУЩАЯСЯ ПЛАТФОРМА", "ПАТРУЛЬНЫЙ", "ЛЕТАЮЩИЙ", "АГРЕССИВНЫЙ", "РЫЧАГ", "СЕКРЕТНАЯ СТЕНА", "ТЕСТОВАЯ ЗОНА ПРОЙДЕНА"]:
    assert text in layout, text

# Enemy durability and visible health feedback.
assert 'kind: .aggressive' in layout and 'maxHP: 5' in layout
assert 'EnemyHealthBarNode' in scene
assert 'updateHealthBar' in scene
assert 'hitEnemiesThisAttack' in scene

# Universal action button for checkpoints/levers; secret wall remains attack-driven.
assert 'actionButton' in scene
assert 'startAction()' in scene
assert 'activateNearbyAction' in scene
assert 'attackSecretWall' in scene

# Tutorial targeting must support and visibly highlight the action button.
assert 'case "ACTION": pulseTutorial(actionButton)' in scene
assert 'tutorialArrow' in scene

# Moving-platform rider carry must use explicit ride support, not only visual movement.
assert 'MovingPlatformRideSupport' in scene
assert 'applyPlatformDelta' in scene

# Pixel Cave art is restored into the app and actually referenced by runtime rendering.
assert 'PixelCaveArt' in scene
assert 'PixelCave' in workflow
assert 'pixel_cave_tileset' in workflow
assert 'Resources/PixelCave' in workflow

print("v1.5 integration contract passed")
