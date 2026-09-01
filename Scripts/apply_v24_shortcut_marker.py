from pathlib import Path

path = Path("Sources/RoomRuntimeInstaller.swift")
text = path.read_text()

if 'shortcutMarker.name = "v24ShortcutMarker"' in text:
    print("V24 shortcut marker already integrated")
    raise SystemExit(0)


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"expected exactly one match, found {count}: {old[:120]!r}")
    text = text.replace(old, new, 1)

replace_once(
    '''        scene.childNode(withName: "v21ExitMarker")?.removeFromParent()\n        scene.childNode(withName: "v24AbilityShrine")?.removeFromParent()''',
    '''        scene.childNode(withName: "v21ExitMarker")?.removeFromParent()\n        scene.childNode(withName: "v24ShortcutMarker")?.removeFromParent()\n        scene.childNode(withName: "v24AbilityShrine")?.removeFromParent()'''
)

replace_once(
    '''        exitMarker.addChild(exitLabel)\n        scene.addChild(exitMarker)\n\n        let roomTitle = SKLabelNode(fontNamed: "AvenirNext-Bold")''',
    '''        exitMarker.addChild(exitLabel)\n        scene.addChild(exitMarker)\n\n        let shortcutMarker = SKShapeNode(\n            rectOf: CGSize(width: 52, height: 110),\n            cornerRadius: 10\n        )\n        shortcutMarker.name = "v24ShortcutMarker"\n        shortcutMarker.lineWidth = 2.5\n        shortcutMarker.zPosition = 32\n        shortcutMarker.isHidden = true\n\n        let shortcutLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")\n        shortcutLabel.name = "v24ShortcutLabel"\n        shortcutLabel.fontSize = 8\n        shortcutLabel.fontColor = UIColor(white: 0.96, alpha: 0.95)\n        shortcutLabel.verticalAlignmentMode = .center\n        shortcutLabel.horizontalAlignmentMode = .center\n        shortcutMarker.addChild(shortcutLabel)\n        scene.addChild(shortcutMarker)\n\n        let roomTitle = SKLabelNode(fontNamed: "AvenirNext-Bold")'''
)

old_refresh = '''        func refreshExitPresentation(for room: RoomDefinition) {\n            let combatLocked = room.requiresCombatClear && !context.combatStatus.isCleared\n            let abilityLocked: Bool\n            if let requiredAbility = room.exits.first?.requiredAbility {\n                abilityLocked = !context.progression.state.unlockedAbilities.contains(requiredAbility)\n            } else {\n                abilityLocked = false\n            }\n\n            if combatLocked || abilityLocked {\n                exitMarker.fillColor = UIColor(red: 0.42, green: 0.10, blue: 0.10, alpha: 0.34)\n                exitMarker.strokeColor = UIColor(red: 0.90, green: 0.24, blue: 0.18, alpha: 0.88)\n                exitLabel.text = abilityLocked ? "ABILITY" : "LOCKED"\n            } else {\n                exitMarker.fillColor = UIColor(red: 0.20, green: 0.78, blue: 0.92, alpha: 0.22)\n                exitMarker.strokeColor = UIColor(red: 0.42, green: 0.92, blue: 1.0, alpha: 0.88)\n                exitLabel.text = room.id == .wardenChamber ? "FINISH" : "EXIT"\n            }\n\n            if room.requiresCombatClear {\n                combatStatusLabel.isHidden = false\n                combatStatusLabel.text = context.combatStatus.isCleared\n                    ? "PATH OPEN"\n                    : "ENEMIES  \\(context.combatStatus.requiredAlive)"\n            } else {\n                combatStatusLabel.isHidden = true\n            }\n        }'''

new_refresh = '''        func applyExitStyle(\n            marker: SKShapeNode,\n            label: SKLabelNode,\n            exit: RoomExit,\n            room: RoomDefinition,\n            shortcut: Bool\n        ) {\n            let presentation = RoomExitPresentationResolver.state(\n                for: exit,\n                roomRequiresCombatClear: room.requiresCombatClear,\n                combatCleared: context.combatStatus.isCleared,\n                unlockedAbilities: context.progression.state.unlockedAbilities\n            )\n\n            switch presentation {\n            case .open:\n                marker.fillColor = UIColor(red: 0.20, green: 0.78, blue: 0.92, alpha: 0.22)\n                marker.strokeColor = UIColor(red: 0.42, green: 0.92, blue: 1.0, alpha: 0.88)\n                label.text = shortcut ? "SHORTCUT" : (room.id == .wardenChamber ? "FINISH" : "EXIT")\n            case .combatLocked:\n                marker.fillColor = UIColor(red: 0.42, green: 0.10, blue: 0.10, alpha: 0.34)\n                marker.strokeColor = UIColor(red: 0.90, green: 0.24, blue: 0.18, alpha: 0.88)\n                label.text = "LOCKED"\n            case .abilityLocked:\n                marker.fillColor = UIColor(red: 0.28, green: 0.25, blue: 0.10, alpha: 0.32)\n                marker.strokeColor = UIColor(red: 0.94, green: 0.74, blue: 0.24, alpha: 0.88)\n                label.text = exit.requiredAbility == .wallTraversal ? "WALL" : "ABILITY"\n            }\n        }\n\n        func refreshExitPresentation(for room: RoomDefinition) {\n            if let primary = room.exits.first {\n                applyExitStyle(\n                    marker: exitMarker,\n                    label: exitLabel,\n                    exit: primary,\n                    room: room,\n                    shortcut: false\n                )\n            }\n\n            if room.exits.count > 1 {\n                shortcutMarker.isHidden = false\n                applyExitStyle(\n                    marker: shortcutMarker,\n                    label: shortcutLabel,\n                    exit: room.exits[1],\n                    room: room,\n                    shortcut: true\n                )\n            } else {\n                shortcutMarker.isHidden = true\n            }\n\n            if room.requiresCombatClear {\n                combatStatusLabel.isHidden = false\n                combatStatusLabel.text = context.combatStatus.isCleared\n                    ? "PATH OPEN"\n                    : "ENEMIES  \\(context.combatStatus.requiredAlive)"\n            } else {\n                combatStatusLabel.isHidden = true\n            }\n        }'''
replace_once(old_refresh, new_refresh)

replace_once(
    '''            exitMarker.isHidden = true\n            combatStatusLabel.isHidden = true''',
    '''            exitMarker.isHidden = true\n            shortcutMarker.isHidden = true\n            combatStatusLabel.isHidden = true'''
)

replace_once(
    '''            if let roomExit = room.exits.first {\n                exitMarker.isHidden = false\n                exitMarker.position = CGPoint(\n                    x: CGFloat(roomExit.trigger.x + roomExit.trigger.width * 0.5),\n                    y: CGFloat(roomExit.trigger.y + roomExit.trigger.height * 0.5)\n                )\n            } else {\n                exitMarker.isHidden = true\n            }\n\n            if let placement = room.shrine {''',
    '''            if let roomExit = room.exits.first {\n                exitMarker.isHidden = false\n                exitMarker.position = CGPoint(\n                    x: CGFloat(roomExit.trigger.x + roomExit.trigger.width * 0.5),\n                    y: CGFloat(roomExit.trigger.y + roomExit.trigger.height * 0.5)\n                )\n            } else {\n                exitMarker.isHidden = true\n            }\n\n            if room.exits.count > 1 {\n                let shortcutExit = room.exits[1]\n                shortcutMarker.isHidden = false\n                shortcutMarker.position = CGPoint(\n                    x: CGFloat(shortcutExit.trigger.x + shortcutExit.trigger.width * 0.5),\n                    y: CGFloat(shortcutExit.trigger.y + shortcutExit.trigger.height * 0.5)\n                )\n            } else {\n                shortcutMarker.isHidden = true\n            }\n\n            if let placement = room.shrine {'''
)

path.write_text(text)
print("Integrated V24 optional shortcut marker")
