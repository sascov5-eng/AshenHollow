import SpriteKit
import UIKit

private final class V21RoomRuntimeState {
    let controller = RoomController.makeV24Demo()
    var activeRoomID: RoomID = .approach
    var lastElapsed: CGFloat = 0
    var transitionCooldown: CGFloat = 0
}

enum RoomRuntimeInstaller {
    static func install(on scene: SKScene, context: V21RuntimeContext) {
        guard let player = scene.childNode(withName: "player"),
              let camera = scene.camera,
              let gameScene = scene as? GameScene else {
            return
        }

        scene.removeAction(forKey: "v21RoomRuntime")
        scene.removeAction(forKey: "v20RoomRuntime")
        scene.childNode(withName: "v20LeftMask")?.removeFromParent()
        scene.childNode(withName: "v20RightMask")?.removeFromParent()
        scene.childNode(withName: "v20ExitMarker")?.removeFromParent()
        scene.childNode(withName: "v21LeftMask")?.removeFromParent()
        scene.childNode(withName: "v21RightMask")?.removeFromParent()
        scene.childNode(withName: "v21ExitMarker")?.removeFromParent()
        scene.childNode(withName: "v24ShortcutMarker")?.removeFromParent()
        scene.childNode(withName: "v24AbilityShrine")?.removeFromParent()
        scene.childNode(withName: "v24CheckpointMarker")?.removeFromParent()
        camera.childNode(withName: "v20RoomTitle")?.removeFromParent()
        camera.childNode(withName: "v21RoomTitle")?.removeFromParent()
        camera.childNode(withName: "v21CombatStatus")?.removeFromParent()
        camera.childNode(withName: "v21LevelComplete")?.removeFromParent()
        camera.childNode(withName: "v24AbilityAcquired")?.removeFromParent()

        let state = V21RoomRuntimeState()

        if let legacyEnemy = scene.childNode(withName: "testEnemy") {
            legacyEnemy.removeAllActions()
            legacyEnemy.isHidden = true
            legacyEnemy.position = CGPoint(x: -10_000, y: -10_000)
        }

        let leftMask = SKShapeNode(rectOf: CGSize(width: 1800, height: 1200))
        leftMask.name = "v21LeftMask"
        leftMask.fillColor = .black
        leftMask.strokeColor = .clear
        leftMask.zPosition = 900
        scene.addChild(leftMask)

        let rightMask = SKShapeNode(rectOf: CGSize(width: 1800, height: 1200))
        rightMask.name = "v21RightMask"
        rightMask.fillColor = .black
        rightMask.strokeColor = .clear
        rightMask.zPosition = 900
        scene.addChild(rightMask)

        let exitMarker = SKShapeNode(
            rectOf: CGSize(width: 42, height: 118),
            cornerRadius: 10
        )
        exitMarker.name = "v21ExitMarker"
        exitMarker.lineWidth = 2.5
        exitMarker.zPosition = 32

        let exitLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        exitLabel.name = "v21ExitLabel"
        exitLabel.fontSize = 9
        exitLabel.fontColor = UIColor(white: 0.96, alpha: 0.95)
        exitLabel.verticalAlignmentMode = .center
        exitLabel.horizontalAlignmentMode = .center
        exitMarker.addChild(exitLabel)
        scene.addChild(exitMarker)

        let shortcutMarker = SKShapeNode(
            rectOf: CGSize(width: 52, height: 110),
            cornerRadius: 10
        )
        shortcutMarker.name = "v24ShortcutMarker"
        shortcutMarker.lineWidth = 2.5
        shortcutMarker.zPosition = 32
        shortcutMarker.isHidden = true

        let shortcutLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        shortcutLabel.name = "v24ShortcutLabel"
        shortcutLabel.fontSize = 8
        shortcutLabel.fontColor = UIColor(white: 0.96, alpha: 0.95)
        shortcutLabel.verticalAlignmentMode = .center
        shortcutLabel.horizontalAlignmentMode = .center
        shortcutMarker.addChild(shortcutLabel)
        scene.addChild(shortcutMarker)

        let roomTitle = SKLabelNode(fontNamed: "AvenirNext-Bold")
        roomTitle.name = "v21RoomTitle"
        roomTitle.fontSize = 13
        roomTitle.fontColor = UIColor(white: 0.92, alpha: 0.82)
        roomTitle.horizontalAlignmentMode = .center
        roomTitle.verticalAlignmentMode = .center
        roomTitle.position = CGPoint(x: 0, y: scene.size.height * 0.5 - 46)
        roomTitle.zPosition = 1250
        camera.addChild(roomTitle)

        let combatStatusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        combatStatusLabel.name = "v21CombatStatus"
        combatStatusLabel.fontSize = 10
        combatStatusLabel.fontColor = UIColor(red: 1.0, green: 0.67, blue: 0.42, alpha: 0.90)
        combatStatusLabel.horizontalAlignmentMode = .center
        combatStatusLabel.verticalAlignmentMode = .center
        combatStatusLabel.position = CGPoint(x: 0, y: scene.size.height * 0.5 - 61)
        combatStatusLabel.zPosition = 1250
        camera.addChild(combatStatusLabel)

        func layoutStatusHUD() {
            let bounds = scene.view?.bounds ?? CGRect(origin: .zero, size: scene.size)
            let viewWidth = bounds.width > 1 ? bounds.width : scene.size.width
            let viewHeight = bounds.height > 1 ? bounds.height : scene.size.height
            let insets = scene.view?.safeAreaInsets ?? .zero
            let layout = HUDOverlayLayout(
                viewWidth: Double(viewWidth),
                viewHeight: Double(viewHeight),
                safeTopInset: Double(insets.top),
                safeLeftInset: Double(insets.left),
                safeRightInset: Double(insets.right)
            )

            let roomLocal = layout.cameraLocalPosition(
                for: layout.roomTitleCenter,
                sceneWidth: Double(scene.size.width),
                sceneHeight: Double(scene.size.height)
            )
            roomTitle.position = CGPoint(x: CGFloat(roomLocal.x), y: CGFloat(roomLocal.y))

            let combatLocal = layout.cameraLocalPosition(
                for: layout.combatStatusCenter,
                sceneWidth: Double(scene.size.width),
                sceneHeight: Double(scene.size.height)
            )
            combatStatusLabel.position = CGPoint(x: CGFloat(combatLocal.x), y: CGFloat(combatLocal.y))
        }

        layoutStatusHUD()

        func applyExitStyle(
            marker: SKShapeNode,
            label: SKLabelNode,
            exit: RoomExit,
            room: RoomDefinition,
            shortcut: Bool
        ) {
            let presentation = RoomExitPresentationResolver.state(
                for: exit,
                roomRequiresCombatClear: room.requiresCombatClear,
                combatCleared: context.combatStatus.isCleared,
                unlockedAbilities: context.progression.state.unlockedAbilities
            )

            switch presentation {
            case .open:
                marker.fillColor = UIColor(red: 0.20, green: 0.78, blue: 0.92, alpha: 0.22)
                marker.strokeColor = UIColor(red: 0.42, green: 0.92, blue: 1.0, alpha: 0.88)
                label.text = shortcut ? "SHORTCUT" : (room.id == .wardenChamber ? "FINISH" : "EXIT")
            case .combatLocked:
                marker.fillColor = UIColor(red: 0.42, green: 0.10, blue: 0.10, alpha: 0.34)
                marker.strokeColor = UIColor(red: 0.90, green: 0.24, blue: 0.18, alpha: 0.88)
                label.text = "LOCKED"
            case .abilityLocked:
                marker.fillColor = UIColor(red: 0.28, green: 0.25, blue: 0.10, alpha: 0.32)
                marker.strokeColor = UIColor(red: 0.94, green: 0.74, blue: 0.24, alpha: 0.88)
                label.text = exit.requiredAbility == .wallTraversal ? "WALL" : "ABILITY"
            }
        }

        func refreshExitPresentation(for room: RoomDefinition) {
            if let primary = room.exits.first {
                applyExitStyle(
                    marker: exitMarker,
                    label: exitLabel,
                    exit: primary,
                    room: room,
                    shortcut: false
                )
            }

            if room.exits.count > 1 {
                shortcutMarker.isHidden = false
                applyExitStyle(
                    marker: shortcutMarker,
                    label: shortcutLabel,
                    exit: room.exits[1],
                    room: room,
                    shortcut: true
                )
            } else {
                shortcutMarker.isHidden = true
            }

            if room.requiresCombatClear {
                combatStatusLabel.isHidden = false
                combatStatusLabel.text = context.combatStatus.isCleared
                    ? "PATH OPEN"
                    : "ENEMIES  \(context.combatStatus.requiredAlive)"
            } else {
                combatStatusLabel.isHidden = true
            }
        }

        func shrineTitle(_ ability: PlayerAbility) -> String {
            switch ability {
            case .dash: return "DASH"
            case .wallTraversal: return "WALL"
            }
        }

        func acquisitionTitle(_ ability: PlayerAbility) -> String {
            switch ability {
            case .dash: return "DASH ACQUIRED"
            case .wallTraversal: return "WALL TRAVERSAL ACQUIRED"
            }
        }

        func buildShrine(_ placement: AbilityShrinePlacement) -> SKNode {
            let shrine = SKNode()
            shrine.name = "v24AbilityShrine"
            shrine.position = CGPoint(x: CGFloat(placement.position.x), y: CGFloat(placement.position.y))
            shrine.zPosition = 25

            let glow = SKShapeNode(ellipseOf: CGSize(width: 96, height: 82))
            glow.name = "glow"
            glow.fillColor = UIColor(red: 0.28, green: 0.78, blue: 1.0, alpha: 0.13)
            glow.strokeColor = UIColor(red: 0.38, green: 0.86, blue: 1.0, alpha: 0.42)
            glow.lineWidth = 2
            glow.position = CGPoint(x: 0, y: 12)
            shrine.addChild(glow)

            let pedestal = SKShapeNode(rectOf: CGSize(width: 78, height: 22), cornerRadius: 6)
            pedestal.fillColor = UIColor(red: 0.15, green: 0.17, blue: 0.21, alpha: 1)
            pedestal.strokeColor = UIColor(white: 0.55, alpha: 0.38)
            pedestal.lineWidth = 2
            pedestal.position = CGPoint(x: 0, y: -32)
            shrine.addChild(pedestal)

            let artifact = SKShapeNode(rectOf: CGSize(width: 34, height: 34), cornerRadius: 7)
            artifact.name = "artifact"
            artifact.fillColor = UIColor(red: 0.38, green: 0.84, blue: 1.0, alpha: 0.92)
            artifact.strokeColor = UIColor(white: 1.0, alpha: 0.72)
            artifact.lineWidth = 2
            artifact.zRotation = .pi * 0.25
            artifact.position = CGPoint(x: 0, y: 12)
            shrine.addChild(artifact)

            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.name = "shrineLabel"
            label.text = shrineTitle(placement.ability)
            label.fontSize = 9
            label.fontColor = UIColor(white: 0.96, alpha: 0.94)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: -56)
            shrine.addChild(label)

            scene.addChild(shrine)
            return shrine
        }

        func refreshShrinePresentation(_ shrine: SKNode, placement: AbilityShrinePlacement) {
            let consumed = context.progression.state.consumedShrines.contains(placement.id)
            shrine.alpha = consumed ? 0.34 : 1.0
            if let label = shrine.childNode(withName: "shrineLabel") as? SKLabelNode {
                label.text = consumed ? "DORMANT" : shrineTitle(placement.ability)
            }
            if let artifact = shrine.childNode(withName: "artifact") as? SKShapeNode {
                artifact.fillColor = consumed
                    ? UIColor(white: 0.32, alpha: 0.72)
                    : UIColor(red: 0.38, green: 0.84, blue: 1.0, alpha: 0.92)
            }
        }

        func showAcquisition(_ ability: PlayerAbility) {
            camera.childNode(withName: "v24AbilityAcquired")?.removeFromParent()
            gameScene.setExternalInputLocked(true)
            state.transitionCooldown = max(state.transitionCooldown, 0.50)

            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.name = "v24AbilityAcquired"
            label.text = acquisitionTitle(ability)
            label.fontSize = 25
            label.fontColor = UIColor(red: 0.64, green: 0.91, blue: 1.0, alpha: 1)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: 28)
            label.zPosition = 1500
            label.alpha = 0
            label.setScale(0.84)
            camera.addChild(label)

            let enter = SKAction.group([
                SKAction.fadeIn(withDuration: 0.06),
                SKAction.scale(to: 1.0, duration: 0.06)
            ])
            let leave = SKAction.fadeOut(withDuration: 0.06)
            label.run(
                SKAction.sequence([
                    enter,
                    SKAction.wait(forDuration: 0.33),
                    leave,
                    SKAction.run { gameScene.setExternalInputLocked(false) },
                    SKAction.removeFromParent()
                ])
            )
        }

        func showLevelComplete() {
            guard camera.childNode(withName: "v21LevelComplete") == nil else { return }
            context.levelComplete = true
            exitMarker.isHidden = true
            shortcutMarker.isHidden = true
            combatStatusLabel.isHidden = true

            let complete = SKLabelNode(fontNamed: "AvenirNext-Bold")
            complete.name = "v21LevelComplete"
            complete.text = "LEVEL COMPLETE"
            complete.fontSize = 30
            complete.fontColor = UIColor(red: 0.74, green: 0.94, blue: 1.0, alpha: 1)
            complete.horizontalAlignmentMode = .center
            complete.verticalAlignmentMode = .center
            complete.position = .zero
            complete.zPosition = 1500
            complete.setScale(0.82)
            complete.alpha = 0
            camera.addChild(complete)
            complete.run(
                SKAction.group([
                    SKAction.fadeIn(withDuration: 0.28),
                    SKAction.scale(to: 1.0, duration: 0.32)
                ])
            )
        }

        func applyRoom(_ roomID: RoomID, destinationSpawn: RoomPoint?) {
            guard let room = state.controller.room(roomID) else { return }

            gameScene.setExternalInputLocked(false)
            camera.childNode(withName: "v24AbilityAcquired")?.removeFromParent()
            scene.childNode(withName: "v24AbilityShrine")?.removeFromParent()
            scene.childNode(withName: "v24CheckpointMarker")?.removeFromParent()
            MultiEnemyRuntimeInstaller.clear(from: scene)
            BossRuntimeInstaller.clear(from: scene)
            context.damageInbox.clear()

            state.activeRoomID = roomID
            context.activeRoomID = roomID
            if roomID != .approach {
                context.onboarding.leaveOnboardingArea()
            }
            context.levelComplete = false
            state.transitionCooldown = 0.24

            let roomWidth = CGFloat(room.bounds.width)
            let roomHeight = CGFloat(room.bounds.height)
            context.physicalRoomMinX = 0
            context.physicalRoomMaxX = roomWidth

            gameScene.replaceRoomGeometry(
                platforms: room.platforms,
                roomWidth: roomWidth,
                roomHeight: roomHeight
            )

            let spawn = destinationSpawn ?? room.playerSpawn
            player.position = CGPoint(
                x: CGFloat(spawn.x),
                y: CGFloat(spawn.y)
            )
            player.alpha = 1
            player.childNode(withName: "attackHitbox")?.alpha = 0

            leftMask.position = CGPoint(x: -900, y: 500)
            rightMask.position = CGPoint(x: roomWidth + 900, y: 500)

            if let roomExit = room.exits.first {
                exitMarker.isHidden = false
                exitMarker.position = CGPoint(
                    x: CGFloat(roomExit.trigger.x + roomExit.trigger.width * 0.5),
                    y: CGFloat(roomExit.trigger.y + roomExit.trigger.height * 0.5)
                )
            } else {
                exitMarker.isHidden = true
            }

            if room.exits.count > 1 {
                let shortcutExit = room.exits[1]
                shortcutMarker.isHidden = false
                shortcutMarker.position = CGPoint(
                    x: CGFloat(shortcutExit.trigger.x + shortcutExit.trigger.width * 0.5),
                    y: CGFloat(shortcutExit.trigger.y + shortcutExit.trigger.height * 0.5)
                )
            } else {
                shortcutMarker.isHidden = true
            }

            if let placement = room.shrine {
                let shrine = buildShrine(placement)
                refreshShrinePresentation(shrine, placement: placement)
            }

            if let trigger = room.checkpointTriggers.first {
                let marker = SKShapeNode(ellipseOf: CGSize(width: 34, height: 72))
                marker.name = "v24CheckpointMarker"
                marker.fillColor = UIColor(red: 0.26, green: 0.66, blue: 0.92, alpha: 0.14)
                marker.strokeColor = UIColor(red: 0.48, green: 0.86, blue: 1.0, alpha: 0.58)
                marker.lineWidth = 2
                marker.position = CGPoint(
                    x: CGFloat(trigger.trigger.x + trigger.trigger.width * 0.5),
                    y: CGFloat(trigger.trigger.y + trigger.trigger.height * 0.5)
                )
                marker.zPosition = 23
                scene.addChild(marker)
            }

            roomTitle.text = title(for: roomID)
            context.combatStatus.reset(requiredAlive: room.enemySpawns.count)
            refreshExitPresentation(for: room)

            if let bossSpawn = room.enemySpawns.first(where: { $0.archetype == .boss }) {
                BossRuntimeInstaller.spawn(
                    spawn: bossSpawn,
                    physicalOriginX: 0,
                    roomWidth: roomWidth,
                    on: scene,
                    context: context
                )
            } else {
                MultiEnemyRuntimeInstaller.spawn(
                    spawns: room.enemySpawns,
                    physicalOriginX: 0,
                    roomWidth: roomWidth,
                    on: scene,
                    context: context
                )
            }

            let visibleHalfWidth = Double(scene.size.width * 0.5 * camera.xScale)
            let cameraX = state.controller.clampedCameraX(
                targetX: Double(player.position.x),
                visibleHalfWidth: visibleHalfWidth,
                in: roomID
            )
            camera.position.x = CGFloat(cameraX)
        }

        let checkpoint = context.progression.state.checkpoint
        if state.controller.room(checkpoint.roomID) != nil {
            state.activeRoomID = checkpoint.roomID
            applyRoom(checkpoint.roomID, destinationSpawn: checkpoint.spawn)
        } else {
            applyRoom(state.controller.initialRoomID, destinationSpawn: nil)
        }

        let runtimeAction = SKAction.customAction(withDuration: 1_000_000) { _, elapsed in
            let dt: CGFloat
            if state.lastElapsed == 0 {
                dt = 1.0 / 60.0
            } else {
                dt = min(max(elapsed - state.lastElapsed, 0), 1.0 / 30.0)
            }
            state.lastElapsed = elapsed
            state.transitionCooldown = max(0, state.transitionCooldown - dt)

            layoutStatusHUD()

            guard let room = state.controller.room(state.activeRoomID) else { return }
            let roomWidth = CGFloat(room.bounds.width)

            let halfPlayerWidth: CGFloat = 18
            let minPlayerX = halfPlayerWidth
            let maxPlayerX = roomWidth - halfPlayerWidth
            player.position.x = max(minPlayerX, min(maxPlayerX, player.position.x))

            refreshExitPresentation(for: room)

            let playerCenter = RoomPoint(
                x: Double(player.position.x),
                y: Double(player.position.y)
            )
            let playerSize = RoomSize(width: 36, height: 60)

            if let placement = DemoRoomProgressionResolver.shrineToActivate(
                in: room,
                playerCenter: playerCenter,
                playerSize: playerSize,
                consumedShrines: context.progression.state.consumedShrines
            ), context.progression.claimShrine(
                placement.id,
                ability: placement.ability,
                checkpoint: placement.checkpoint
            ) {
                if let shrine = scene.childNode(withName: "v24AbilityShrine") {
                    refreshShrinePresentation(shrine, placement: placement)
                }
                showAcquisition(placement.ability)
            }

            if (!room.requiresCombatClear || context.combatStatus.isCleared),
               let checkpoint = DemoRoomProgressionResolver.checkpointToActivate(
                   in: room,
                   playerCenter: playerCenter,
                   playerSize: playerSize,
                   currentCheckpoint: context.progression.state.checkpoint
               ) {
                context.progression.activateCheckpoint(checkpoint)
            }

            if !context.levelComplete && state.transitionCooldown <= 0 {
                if let activation = state.controller.exitIfNeeded(
                    playerCenter: playerCenter,
                    playerSize: playerSize,
                    in: state.activeRoomID,
                    combatCleared: context.combatStatus.isCleared,
                    unlockedAbilities: context.progression.state.unlockedAbilities
                ) {
                    if activation.completesLevel {
                        showLevelComplete()
                    } else if let destinationRoomID = activation.destinationRoomID,
                              let destinationSpawn = activation.destinationSpawn {
                        applyRoom(destinationRoomID, destinationSpawn: destinationSpawn)
                        return
                    }
                }
            }

            // Final per-frame camera clamp after GameScene.update. V24 uses one
            // room-local physical space, so no recycled world segment offset exists.
            let visibleHalfWidth = Double(scene.size.width * 0.5 * camera.xScale)
            let clampedCameraX = state.controller.clampedCameraX(
                targetX: Double(camera.position.x),
                visibleHalfWidth: visibleHalfWidth,
                in: state.activeRoomID
            )
            camera.position.x = CGFloat(clampedCameraX)
        }

        scene.run(runtimeAction, withKey: "v21RoomRuntime")
    }

    static func install(on scene: SKScene) {
        if let context = V21RuntimeBootstrap.context(from: scene) {
            install(on: scene, context: context)
            return
        }

        scene.userData = scene.userData ?? NSMutableDictionary()
        let context = V21RuntimeContext(
            progression: DemoProgressionRuntime(launchMode: .continueGame)
        )
        scene.userData?["v21RuntimeContext"] = context
        install(on: scene, context: context)
    }

    private static func title(for roomID: RoomID) -> String {
        switch roomID {
        case .approach: return "ROOM 1 — APPROACH"
        case .lowerHall: return "ROOM 2 — LOWER HALL"
        case .brokenGallery: return "ROOM 3 — BROKEN GALLERY"
        case .dashShrine: return "ROOM 4 — DASH SHRINE"
        case .furnacePassage: return "ROOM 5 — FURNACE PASSAGE"
        case .watcherHall: return "ROOM 6 — WATCHER HALL"
        case .hollowShaft: return "ROOM 7 — HOLLOW SHAFT"
        case .ashenAscent: return "ROOM 8 — ASHEN ASCENT"
        case .wardenGate: return "ROOM 9 — WARDEN GATE"
        case .wardenChamber: return "ROOM 10 — WARDEN CHAMBER"
        }
    }
}
