import SpriteKit
import UIKit

private final class V21RoomRuntimeState {
    let controller = RoomController.makeV21Level()
    var activeRoomID: RoomID = .approach
    var lastElapsed: CGFloat = 0
    var transitionCooldown: CGFloat = 0
}

enum RoomRuntimeInstaller {
    static func install(on scene: SKScene, context: V21RuntimeContext) {
        guard let player = scene.childNode(withName: "player"),
              let camera = scene.camera else {
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
        camera.childNode(withName: "v20RoomTitle")?.removeFromParent()
        camera.childNode(withName: "v21RoomTitle")?.removeFromParent()
        camera.childNode(withName: "v21CombatStatus")?.removeFromParent()
        camera.childNode(withName: "v21LevelComplete")?.removeFromParent()

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

        func physicalOriginX(for roomID: RoomID) -> CGFloat {
            guard let index = state.controller.orderedRoomIDs.firstIndex(of: roomID) else { return 0 }
            // Recycle the two user-confirmed V20 collision segments. This keeps the
            // stable GameScene kinematic controller completely untouched in V21.
            return index.isMultiple(of: 2) ? 0 : 1200
        }

        func refreshExitPresentation(for room: RoomDefinition) {
            let locked = room.requiresCombatClear && !context.combatStatus.isCleared
            if locked {
                exitMarker.fillColor = UIColor(red: 0.42, green: 0.10, blue: 0.10, alpha: 0.34)
                exitMarker.strokeColor = UIColor(red: 0.90, green: 0.24, blue: 0.18, alpha: 0.88)
                exitLabel.text = "LOCKED"
            } else {
                exitMarker.fillColor = UIColor(red: 0.20, green: 0.78, blue: 0.92, alpha: 0.22)
                exitMarker.strokeColor = UIColor(red: 0.42, green: 0.92, blue: 1.0, alpha: 0.88)
                exitLabel.text = room.id == .wardenChamber ? "FINISH" : "EXIT"
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

        func showLevelComplete() {
            guard camera.childNode(withName: "v21LevelComplete") == nil else { return }
            context.levelComplete = true
            exitMarker.isHidden = true
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

            MultiEnemyRuntimeInstaller.clear(from: scene)
            BossRuntimeInstaller.clear(from: scene)
            context.damageInbox.clear()

            state.activeRoomID = roomID
            context.activeRoomID = roomID
            context.levelComplete = false
            state.transitionCooldown = 0.24

            let originX = physicalOriginX(for: roomID)
            let roomWidth = CGFloat(room.bounds.width)
            context.physicalRoomMinX = originX
            context.physicalRoomMaxX = originX + roomWidth

            let localSpawn = destinationSpawn ?? room.playerSpawn
            player.position = CGPoint(
                x: originX + CGFloat(localSpawn.x),
                y: CGFloat(localSpawn.y)
            )
            player.alpha = 1
            player.childNode(withName: "attackHitbox")?.alpha = 0

            leftMask.position = CGPoint(x: originX - 900, y: 500)
            rightMask.position = CGPoint(x: originX + roomWidth + 900, y: 500)

            if let exit = room.exits.first {
                exitMarker.isHidden = false
                exitMarker.position = CGPoint(
                    x: originX + CGFloat(exit.trigger.x + exit.trigger.width * 0.5),
                    y: CGFloat(exit.trigger.y + exit.trigger.height * 0.5)
                )
            } else {
                exitMarker.isHidden = true
            }

            roomTitle.text = title(for: roomID)
            context.combatStatus.reset(requiredAlive: room.enemySpawns.count)
            refreshExitPresentation(for: room)

            if let bossSpawn = room.enemySpawns.first(where: { $0.archetype == .boss }) {
                BossRuntimeInstaller.spawn(
                    spawn: bossSpawn,
                    physicalOriginX: originX,
                    roomWidth: roomWidth,
                    on: scene,
                    context: context
                )
            } else {
                MultiEnemyRuntimeInstaller.spawn(
                    spawns: room.enemySpawns,
                    physicalOriginX: originX,
                    roomWidth: roomWidth,
                    on: scene,
                    context: context
                )
            }

            let visibleHalfWidth = Double(scene.size.width * 0.5 * camera.xScale)
            let localTarget = Double(player.position.x - originX)
            let localCameraX = state.controller.clampedCameraX(
                targetX: localTarget,
                visibleHalfWidth: visibleHalfWidth,
                in: roomID
            )
            camera.position.x = originX + CGFloat(localCameraX)
        }

        let checkpoint = context.progression.state.checkpoint
        if state.controller.room(checkpoint.roomID) != nil {
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
            let originX = physicalOriginX(for: state.activeRoomID)
            let roomWidth = CGFloat(room.bounds.width)

            let halfPlayerWidth: CGFloat = 18
            let minPlayerX = originX + halfPlayerWidth
            let maxPlayerX = originX + roomWidth - halfPlayerWidth
            player.position.x = max(minPlayerX, min(maxPlayerX, player.position.x))

            refreshExitPresentation(for: room)

            if !context.levelComplete && state.transitionCooldown <= 0 {
                let localPlayer = RoomPoint(
                    x: Double(player.position.x - originX),
                    y: Double(player.position.y)
                )

                if let activation = state.controller.exitIfNeeded(
                    playerCenter: localPlayer,
                    playerSize: RoomSize(width: 36, height: 60),
                    in: state.activeRoomID,
                    combatCleared: context.combatStatus.isCleared
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

            // Final per-frame camera clamp after GameScene.update, preserving the
            // user-confirmed camera follow implementation while constraining it to
            // the currently recycled physical room segment.
            let visibleHalfWidth = Double(scene.size.width * 0.5 * camera.xScale)
            let localCameraTarget = Double(camera.position.x - originX)
            let clampedLocalCameraX = state.controller.clampedCameraX(
                targetX: localCameraTarget,
                visibleHalfWidth: visibleHalfWidth,
                in: state.activeRoomID
            )
            camera.position.x = originX + CGFloat(clampedLocalCameraX)
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
