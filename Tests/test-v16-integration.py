#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]

def require(path: str, needle: str):
    text = (root / path).read_text(encoding='utf-8')
    assert needle in text, f"{path}: missing {needle!r}"

support = root / 'Sources/TrialModeSupport.swift'
assert support.exists(), 'Sources/TrialModeSupport.swift must exist'
text = support.read_text(encoding='utf-8')
for needle in [
    'enum TrialRank', 'case a', 'case b', 'case c', 'case d',
    'struct TrialDefinition', 'struct TrialRunResult', 'enum TrialCatalog',
    'ПЕРВЫЕ ШАГИ', 'ОХОТА', 'МЕХАНИЗМ', 'РЫВОК', 'СМЕШАННЫЙ БОЙ', 'ФИНАЛЬНОЕ ИСПЫТАНИЕ',
    'TrialProgressStore', 'DemoSettingsStore', 'UserDefaults'
]:
    assert needle in text, f'TrialModeSupport missing {needle!r}'

scene = (root / 'Sources/GameSceneV14.swift').read_text(encoding='utf-8')
for needle in [
    'trialDefinition', 'onTrialCompleted', 'applyMeleeKnockback', 'showMeleeImpact',
    'beginHealFocusFX', 'completeHealFocusFX', 'cancelHealFocusFX',
    'activateNearbyAction', 'nearestActionCandidate', 'openDoorVisual',
    'v1.6'
]:
    assert needle in scene, f'GameSceneV14 missing {needle!r}'

view = (root / 'Sources/GameView.swift').read_text(encoding='utf-8')
for needle in [
    'ИГРАТЬ', 'НАСТРОЙКИ', 'ОБ ИГРЕ', 'ИСПЫТАНИЯ', 'ПАУЗА',
    'ПРОДОЛЖИТЬ', 'ПЕРЕЗАПУСТИТЬ', 'В МЕНЮ', 'МУЗЫКА', 'ЭФФЕКТЫ',
    'ВИБРАЦИЯ', 'РЕЗУЛЬТАТ', 'РАНГ', 'TrialProgressStore'
]:
    assert needle in view, f'GameView missing {needle!r}'

runtime = (root / 'Sources/V15RuntimeSupport.swift').read_text(encoding='utf-8')
for needle in ['doorBody', 'doorFrame', 'leverHandle']:
    assert needle in runtime, f'V15RuntimeSupport missing {needle!r}'

require('Info.plist', '<key>CFBundleShortVersionString</key><string>1.6</string>')
require('Sources/GameView.swift', 'v1.6 • ИСПЫТАНИЯ • БОЙ + UI')
require('Info.plist', '<key>CFBundleIdentifier</key><string>app.ashenhollow.prototype</string>')
require('Info.plist', '<key>CFBundleVersion</key><string>2</string>')

plist = (root / 'Info.plist').read_text(encoding='utf-8')
for forbidden in ['MinimumOSVersion', 'DTPlatformName', 'CFBundleSupportedPlatforms']:
    assert forbidden not in plist, f'forbidden plist key present: {forbidden}'

print('v1.6 integration contract passed')
