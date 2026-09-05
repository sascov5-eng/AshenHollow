#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def text(p): return (root/p).read_text(encoding='utf-8')
view=text('Sources/GameView.swift'); scene=text('Sources/GameSceneV14.swift'); support=text('Sources/TrialModeSupport.swift'); plist=text('Info.plist')
for needle in ['ScrollView(.horizontal','LazyHStack','pauseOverlay','ZStack(alignment: .topLeading)']: assert needle in view, f'GameView missing {needle}'
assert 'gameplay.overlay(pauseOverlay)' not in view
assert '.scrollTargetBehavior' not in view and '.scrollTargetLayout' not in view, 'must compile for iOS 15'
for needle in ['safeSpawnPosition','isSafeTrialSpawn','riderPlatformID','platformContactGrace','setLeverVisual','openDoorVisual']: assert needle in scene, f'scene missing {needle}'
assert 'player.position = CGPoint(x: trialDefinition.startX, y: worldLayout.spawnPoint.y)' not in scene
for needle in ['spawnHintY','safeSpawnRadius']: assert needle in support
assert '<key>CFBundleShortVersionString</key><string>1.7</string>' in plist
assert 'v1.7 • DEVICE BUGFIX • SAFE TRIALS' in view
print('v1.7 device bug regression contract passed')
