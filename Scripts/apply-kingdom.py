#!/usr/bin/env python3
from pathlib import Path
import re

scene_path = Path("Sources/GameSceneV14.swift")
view_path = Path("Sources/GameView.swift")
trial_path = Path("Sources/TrialModeSupport.swift")
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


def sub_once(text, old, new, required=True, label=""):
    if old not in text:
        if required:
            raise SystemExit(f"kingdom missing {label or old[:80]}")
        print("kingdom skip", label or old[:60])
        return text
    return text.replace(old, new, 1)


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

scene = sub_once(scene, "    private let maxHP = 5\n", "    private var maxHP = 5\n", True, "maxHP var")

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
            "        updateHUDStatus()\n        kingdom.refresh(hp: currentHP, maxHP: maxHP, soul: essenceController.essence, soulMax: essenceController.maxEssence, playerX: player.position.x)\n        if kingdom.extraMasks == 1 && maxHP < 6 { maxHP = 6; currentHP = min(maxHP, currentHP + 1) }\n",
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

if "kingdom.soulBonus" not in scene:
    scene = scene.replace(
        "                essenceController.gainFromAcceptedMeleeHit()\n",
        "                essenceController.gainFromAcceptedMeleeHit()\n                if kingdom.soulBonus { essenceController.gainFromAcceptedMeleeHit() }\n",
        1,
    )

if "kingdom.dashMultiplier" not in scene:
    scene = scene.replace(
        "if dashController.isDashing { velocity.dx = CGFloat(dashController.direction * tuning.dashSpeed); return }",
        "if dashController.isDashing { velocity.dx = CGFloat(dashController.direction * tuning.dashSpeed) * kingdom.dashMultiplier; return }",
        1,
    )
    scene = scene.replace(
        "velocity.dx = CGFloat(direction * tuning.dashSpeed); velocity.dy = 0; setAnimation(.dash, force: true)",
        "velocity.dx = CGFloat(direction * tuning.dashSpeed) * kingdom.dashMultiplier; velocity.dy = 0; setAnimation(.dash, force: true)",
        1,
    )

scene = replace_from(
    scene,
    "    private func addWorldCaption(_ text: String, at position: CGPoint, color: UIColor) {",
    "    private func addWorldCaption(_ text: String, at position: CGPoint, color: UIColor) {\n        return\n    }\n",
)

scene = sub_once(
    scene,
    "        guard !trialCompleted else { return }\n        guard trialDefinition.finishRect.contains(player.position) else { return }\n",
    "        guard !trialCompleted else { return }\n        guard trialDefinition.id != \"kingdom\" else { return }\n        guard trialDefinition.finishRect.contains(player.position) else { return }\n",
    False,
    "skip kingdom trial finish",
)

scene = sub_once(
    scene,
    "    private func configureTrialWorld() {\n        let wallWidth: CGFloat = 70\n",
    "    private func configureTrialWorld() {\n        guard trialDefinition.id != \"kingdom\" else { return }\n        let wallWidth: CGFloat = 70\n",
    False,
    "open kingdom walls",
)

scene = sub_once(scene, 'configureLabel(jumpLabel, text: "JUMP", size: 14)', 'configureLabel(jumpLabel, text: "ПРЫЖОК", size: 11)', False, "jump label")
scene = sub_once(scene, 'configureLabel(attackLabel, text: "ATK", size: 15)', 'configureLabel(attackLabel, text: "УДАР", size: 12)', False, "atk label")
scene = sub_once(scene, 'configureLabel(dashLabel, text: "DASH", size: 13)', 'configureLabel(dashLabel, text: "РЫВОК", size: 11)', False, "dash label")
scene = sub_once(scene, 'configureLabel(healLabel, text: "HEAL", size: 12)', 'configureLabel(healLabel, text: "СВЕТ", size: 11)', False, "heal label")

if "layoutHUD()" in scene and "kingdom.layout" in scene:
    scene = re.sub(
        r"(        statusLabel\.position = CGPoint\(x: halfW - \d+, y: halfH - 58\)\n)",
        r"\1        kingdom.layout(viewport: size)\n",
        scene,
        count=1,
    )

if "statusLabel.text =" in scene:
    scene = re.sub(
        r"        statusLabel\.text = .*",
        '        statusLabel.text = ""',
        scene,
        count=3,
    )

scene_path.write_text(scene)

trial = trial_path.read_text()
if 'id: "kingdom"' not in trial:
    marker = '    static let all: [TrialDefinition] = [\n'
    insert = marker + '        TrialDefinition(id: "kingdom", title: "ПЕПЕЛЬНОЕ КОРОЛЕВСТВО", subtitle: "Открытый путь • амулеты • боссы", startX: 220, spawnHintY: 130, safeSpawnRadius: 260, finishX: 25880, finishY: 180, rankA: 900, rankB: 1400, rankC: 2000),\n'
    if marker not in trial:
        raise SystemExit("kingdom missing trial catalog")
    trial = trial.replace(marker, insert, 1)
    trial_path.write_text(trial)

view = view_path.read_text()
view = view.replace("v1.7 • DEVICE BUGFIX • SAFE TRIALS • SFX", "Пепельный крест")
view = view.replace("v1.7 • DEVICE BUGFIX • SAFE TRIALS", "Пепельный крест")
view = view.replace("v1.6 • ИСПЫТАНИЯ • БОЙ + UI", "Пепельный крест")
view = view.replace("v1.4 • PERFECTED TEST LOCATION", "Пепельный крест")

banner = '''            VStack {
                Text("Пепельный крест")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.black.opacity(0.78))
                Spacer()
            }
            .padding(.top, 5)
            .allowsHitTesting(false)
'''
if banner in view:
    view = view.replace(banner, "")
else:
    view = re.sub(
        r"            VStack \{\n                Text\(\"Пепельный крест\"\)[\s\S]*?\.allowsHitTesting\(false\)\n",
        "",
        view,
        count=1,
    )

view = view.replace(
    'menuButton("ИГРАТЬ") { coordinator.showTrials() }',
    'menuButton("ИГРАТЬ") { coordinator.start(TrialCatalog.definition(id: "kingdom")) }\n            menuButton("ИСПЫТАНИЯ") { coordinator.showTrials() }',
    1,
)
view = view.replace(
    "Ashen Hollow — компактная демо-версия с комнатами испытаний, платформингом и боем.",
    "Ashen Hollow — странствие по Пепельному королевству: длинные пещеры, амулеты, мирные жуки и боссы.",
)
view = view.replace(
    'Text("ИСПЫТАНИЯ")\n                .font(.system(size: 16, weight: .bold, design: .monospaced))\n                .foregroundColor(.cyan.opacity(0.9))',
    'Text("КОРОЛЕВСТВО")\n                .font(.system(size: 16, weight: .bold, design: .monospaced))\n                .foregroundColor(.cyan.opacity(0.9))',
)
view_path.write_text(view)
print("Applied kingdom HUD, open-world start, silent captions, Russian shell")
