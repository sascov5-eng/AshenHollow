#!/usr/bin/env python3
from pathlib import Path

scene_path=Path('Sources/GameSceneV14.swift'); view_path=Path('Sources/GameView.swift'); support_path=Path('Sources/TrialModeSupport.swift'); plist_path=Path('Info.plist')
scene=scene_path.read_text(); view=view_path.read_text(); support=support_path.read_text(); plist=plist_path.read_text()

def rep(text, old, new):
    if old not in text: raise SystemExit('missing marker: '+old[:100])
    return text.replace(old,new,1)

# Trial spawn metadata: Y is a hint only; runtime resolves the nearest safe top surface.
support=rep(support,'    let startX: CGFloat\n    let finishX: CGFloat','    let startX: CGFloat\n    let spawnHintY: CGFloat\n    let safeSpawnRadius: CGFloat\n    let finishX: CGFloat')
support=support.replace('startX: 220, finishX:', 'startX: 220, spawnHintY: 130, safeSpawnRadius: 260, finishX:')
support=support.replace('startX: 2200, finishX:', 'startX: 2200, spawnHintY: 130, safeSpawnRadius: 260, finishX:')
support=support.replace('startX: 3920, finishX:', 'startX: 3920, spawnHintY: 130, safeSpawnRadius: 260, finishX:')
support=support.replace('startX: 5350, finishX:', 'startX: 5350, spawnHintY: 1320, safeSpawnRadius: 300, finishX:')
support=support.replace('startX: 6900, finishX:', 'startX: 7120, spawnHintY: 130, safeSpawnRadius: 260, finishX:')
support=support.replace('startX: 220, finishX:', 'startX: 220, spawnHintY: 130, safeSpawnRadius: 260, finishX:')
support_path.write_text(support)

# Stable moving-platform rider contact with grace window.
scene=rep(scene,'    private var hitStopRemaining: TimeInterval = 0','    private var hitStopRemaining: TimeInterval = 0\n    private var riderPlatformID: String?\n    private var platformContactGrace: TimeInterval = 0')
old='''    private func updateMovingPlatforms(_ dt: TimeInterval) {
        let playerFrameBefore = playerColliderFrame()
        for (id, controller) in movingControllers {
            let oldFrame = controller.frame
            let delta = controller.update(dt: dt)
            movingNodes[id]?.position = controller.state.position
            let riding = isGrounded && abs(playerFrameBefore.minY - oldFrame.maxY) < 5 && playerFrameBefore.maxX > oldFrame.minX && playerFrameBefore.minX < oldFrame.maxX
            if riding {
                player.position.x += delta.dx
                player.position.y += delta.dy
                tutorialController.register(action: controller.spec.axis == .horizontal ? .movingPlatformHorizontal : .movingPlatformVertical)
            }
        }
    }'''
new='''    private func updateMovingPlatforms(_ dt: TimeInterval) {
        platformContactGrace = max(0, platformContactGrace - dt)
        let playerFrameBefore = playerColliderFrame()
        var contacted: String?
        for (id, controller) in movingControllers {
            let oldFrame = controller.frame
            let delta = controller.update(dt: dt)
            movingNodes[id]?.position = controller.state.position
            let horizontalOverlap = playerFrameBefore.maxX > oldFrame.minX + 6 && playerFrameBefore.minX < oldFrame.maxX - 6
            let feetGap = playerFrameBefore.minY - oldFrame.maxY
            let landing = horizontalOverlap && feetGap >= -8 && feetGap <= 14 && velocity.dy <= 40
            let retained = riderPlatformID == id && platformContactGrace > 0 && horizontalOverlap && feetGap >= -14 && feetGap <= 22 && velocity.dy <= 80
            if landing || retained {
                contacted = id
                riderPlatformID = id
                platformContactGrace = 0.14
                player.position.x += delta.dx
                player.position.y += delta.dy
                if velocity.dy <= 0 { isGrounded = true }
                tutorialController.register(action: controller.spec.axis == .horizontal ? .movingPlatformHorizontal : .movingPlatformVertical)
            }
        }
        if contacted == nil && platformContactGrace <= 0 { riderPlatformID = nil }
    }'''
scene=rep(scene,old,new)

# Jump explicitly detaches from a moving platform.
scene=scene.replace('velocity.dy = CGFloat(tuning.jumpVelocity); isGrounded = false;', 'riderPlatformID = nil; platformContactGrace = 0; velocity.dy = CGFloat(tuning.jumpVelocity); isGrounded = false;',1)

# Resolve trial spawn from actual collision geometry and reject hazards/death zones.
old='''        player.position = CGPoint(x: trialDefinition.startX, y: worldLayout.spawnPoint.y)
        velocity = .zero
        safeTracker.reset(to: player.position)'''
new='''        player.position = safeSpawnPosition()
        velocity = .zero
        riderPlatformID = nil
        platformContactGrace = 0
        safeTracker.reset(to: player.position)'''
scene=scene.replace(old,new)
scene=scene.replace('position: CGPoint(x: trialDefinition.startX, y: worldLayout.spawnPoint.y),','position: safeSpawnPosition(),')
insert='''
    private func isSafeTrialSpawn(_ point: CGPoint) -> Bool {
        let frame = CGRect(x: point.x - 18, y: point.y - 30, width: 36, height: 60)
        return !worldLayout.hazards.contains(where: { $0.rect.insetBy(dx: -24, dy: -18).intersects(frame) })
    }

    private func safeSpawnPosition() -> CGPoint {
        let candidates = staticPlatformRects.compactMap { rect -> CGPoint? in
            guard trialDefinition.startX >= rect.minX + 42, trialDefinition.startX <= rect.maxX - 42 else { return nil }
            let p = CGPoint(x: trialDefinition.startX, y: rect.maxY + 30)
            guard isSafeTrialSpawn(p) else { return nil }
            return p
        }.sorted { abs($0.y - trialDefinition.spawnHintY) < abs($1.y - trialDefinition.spawnHintY) }
        if let exact = candidates.first, abs(exact.y - trialDefinition.spawnHintY) <= trialDefinition.safeSpawnRadius { return exact }
        for offset in stride(from: CGFloat(40), through: trialDefinition.safeSpawnRadius, by: 40) {
            for x in [trialDefinition.startX - offset, trialDefinition.startX + offset] {
                for rect in staticPlatformRects where x >= rect.minX + 42 && x <= rect.maxX - 42 {
                    let p = CGPoint(x: x, y: rect.maxY + 30)
                    if isSafeTrialSpawn(p) { return p }
                }
            }
        }
        return worldLayout.spawnPoint
    }
'''
scene=rep(scene,'    private func updateTrialCompletion() {',insert+'\n    private func updateTrialCompletion() {')
scene_path.write_text(scene)

# Scrollable/paged trial selection + pause as stable overlay in the same root ZStack.
old='''            switch coordinator.screen {
            case .mainMenu: mainMenu
            case .trials: trialSelection
            case .playing: gameplay
            case .paused: gameplay.overlay(pauseOverlay)
            case .results: resultsView
            case .settings: settingsView
            case .about: aboutView
            }
'''
new='''            switch coordinator.screen {
            case .mainMenu: mainMenu
            case .trials: trialSelection
            case .playing, .paused: gameplay
            case .results: resultsView
            case .settings: settingsView
            case .about: aboutView
            }
            if coordinator.screen == .paused { pauseOverlay }
'''
view=rep(view,old,new)
old='''            HStack(spacing: 10) {
                ForEach(TrialCatalog.all) { trial in'''
new='''            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                ForEach(TrialCatalog.all) { trial in'''
view=rep(view,old,new)
old='''                    .buttonStyle(.plain)
                }
            }
            Button("В МЕНЮ")'''
new='''                    .buttonStyle(.plain)
                }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 24)
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(maxWidth: .infinity, maxHeight: 126)
            Button("В МЕНЮ")'''
view=rep(view,old,new)
view=view.replace('v1.6 • ИСПЫТАНИЯ • БОЙ + UI','v1.7 • DEVICE BUGFIX • SAFE TRIALS')
view_path.write_text(view)

plist=rep(plist,'<key>CFBundleShortVersionString</key><string>1.6</string>','<key>CFBundleShortVersionString</key><string>1.7</string>')
plist_path.write_text(plist)
print('Applied v1.7 device bugfix patch')
