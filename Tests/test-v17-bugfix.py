#!/usr/bin/env python3
from pathlib import Path
root = Path(__file__).resolve().parents[1]

def text(path): return (root/path).read_text(encoding='utf-8')

view = text('Sources/GameView.swift')
scene = text('Sources/GameSceneV14.swift')
support = text('Sources/TrialModeSupport.swift')
plist = text('Info.plist')

# Device regressions from 2026-09-05 recording.
for needle in ['ScrollView(.horizontal', '.scrollTargetBehavior(.viewAligned)', 'pauseOverlay', 'ZStack(alignment: .topLeading)']:
    assert needle in view, f'GameView missing {needle}'
assert 'gameplay.overlay(pauseOverlay)' not in view, 'pause must not rebuild gameplay through switch overlay expression'

for needle in ['safeSpawnPosition', 'isSafeTrialSpawn', 'riderPlatformID', 'platformContactGrace', 'setLeverVisual', 'openDoorVisual']:
    assert needle in scene, f'GameSceneV14 missing {needle}'
assert 'player.position = CGPoint(x: trialDefinition.startX, y: worldLayout.spawnPoint.y)' not in scene, 'raw X + global spawn Y is unsafe'

for needle in ['spawnHintY', 'safeSpawnRadius']:
    assert needle in support, f'TrialModeSupport missing {needle}'

assert '<key>CFBundleShortVersionString</key><string>1.7</string>' in plist
assert 'v1.7 • DEVICE BUGFIX • SAFE TRIALS' in view
print('v1.7 device bug regression contract passed')
