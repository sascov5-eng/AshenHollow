#!/usr/bin/env python3
from pathlib import Path
scene_path=Path('Sources/GameSceneV14.swift'); view_path=Path('Sources/GameView.swift'); support_path=Path('Sources/TrialModeSupport.swift'); plist_path=Path('Info.plist')
scene=scene_path.read_text(); view=view_path.read_text(); support=support_path.read_text(); plist=plist_path.read_text()
def rep(t,a,b):
    if a not in t: raise SystemExit('missing marker: '+a[:100])
    return t.replace(a,b,1)
def block(t,start,end,new):
    a=t.find(start); b=t.find(end,a)
    if a<0 or b<0: raise SystemExit('block marker missing '+start)
    return t[:a]+new.rstrip()+'\n\n'+t[b:]
support=rep(support,'    let startX: CGFloat\n    let finishX: CGFloat','    let startX: CGFloat\n    let spawnHintY: CGFloat\n    let safeSpawnRadius: CGFloat\n    let finishX: CGFloat')
for a,b in [('startX: 220, finishX:','startX: 220, spawnHintY: 130, safeSpawnRadius: 260, finishX:'),('startX: 2200, finishX:','startX: 2200, spawnHintY: 130, safeSpawnRadius: 260, finishX:'),('startX: 3920, finishX:','startX: 3920, spawnHintY: 130, safeSpawnRadius: 260, finishX:'),('startX: 5350, finishX:','startX: 5350, spawnHintY: 1294, safeSpawnRadius: 320, finishX:'),('startX: 6900, finishX:','startX: 7120, spawnHintY: 130, safeSpawnRadius: 300, finishX:')]: support=support.replace(a,b)
support=support.replace('startX: 220, finishX:','startX: 220, spawnHintY: 130, safeSpawnRadius: 260, finishX:'); support_path.write_text(support)
scene=rep(scene,'    private var hitStopRemaining: TimeInterval = 0','    private var hitStopRemaining: TimeInterval = 0\n    private var riderPlatformID: String?\n    private var platformContactGrace: TimeInterval = 0')
newplat='''    private func updateMovingPlatforms(_ dt: TimeInterval) {
        platformContactGrace = max(0, platformContactGrace - dt)
        let pf = playerColliderFrame(); var contacted: String?
        for (id, controller) in movingControllers {
            let old = controller.frame; let delta = controller.update(dt: dt); movingNodes[id]?.position = controller.state.position
            let overlap = pf.maxX > old.minX + 6 && pf.minX < old.maxX - 6; let gap = pf.minY - old.maxY
            let landing = overlap && gap >= -8 && gap <= 14 && velocity.dy <= 40
            let retained = riderPlatformID == id && platformContactGrace > 0 && overlap && gap >= -14 && gap <= 22 && velocity.dy <= 80
            if landing || retained { contacted=id; riderPlatformID=id; platformContactGrace=0.14; player.position.x += delta.dx; player.position.y += delta.dy; if velocity.dy <= 0 { isGrounded=true }; tutorialController.register(action: controller.spec.axis == .horizontal ? .movingPlatformHorizontal : .movingPlatformVertical) }
        }
        if contacted == nil && platformContactGrace <= 0 { riderPlatformID=nil }
    }'''
scene=block(scene,'    private func updateMovingPlatforms(_ dt: TimeInterval) {','    private func refreshCollisionRects()',newplat)
scene=scene.replace('velocity.dy = CGFloat(tuning.jumpVelocity); isGrounded = false;', 'riderPlatformID=nil; platformContactGrace=0; velocity.dy = CGFloat(tuning.jumpVelocity); isGrounded = false;',1)
scene=scene.replace('player.position = CGPoint(x: trialDefinition.startX, y: worldLayout.spawnPoint.y)','player.position = safeSpawnPosition()').replace('position: CGPoint(x: trialDefinition.startX, y: worldLayout.spawnPoint.y),','position: safeSpawnPosition(),')
insert='''    private func isSafeTrialSpawn(_ point: CGPoint) -> Bool {
        let frame=CGRect(x:point.x-18,y:point.y-30,width:36,height:60)
        return !worldLayout.hazards.contains(where:{$0.rect.insetBy(dx:-24,dy:-18).intersects(frame)})
    }
    private func safeSpawnPosition() -> CGPoint {
        let direct=staticPlatformRects.compactMap { r -> CGPoint? in guard trialDefinition.startX >= r.minX+42 && trialDefinition.startX <= r.maxX-42 else{return nil}; let p=CGPoint(x:trialDefinition.startX,y:r.maxY+30); return isSafeTrialSpawn(p) ? p:nil }.sorted{abs($0.y-trialDefinition.spawnHintY)<abs($1.y-trialDefinition.spawnHintY)}
        if let p=direct.first, abs(p.y-trialDefinition.spawnHintY)<=trialDefinition.safeSpawnRadius{return p}
        for off in stride(from:CGFloat(40),through:trialDefinition.safeSpawnRadius,by:40){for x in [trialDefinition.startX-off,trialDefinition.startX+off]{for r in staticPlatformRects where x>=r.minX+42 && x<=r.maxX-42{let p=CGPoint(x:x,y:r.maxY+30);if isSafeTrialSpawn(p){return p}}}}
        return worldLayout.spawnPoint
    }'''
scene=rep(scene,'    private func updateTrialCompletion() {',insert+'\n\n    private func updateTrialCompletion() {'); scene_path.write_text(scene)
view=rep(view,'            case .playing: gameplay\n            case .paused: gameplay.overlay(pauseOverlay)','            case .playing, .paused: gameplay')
view=rep(view,'            }\n\n            VStack {','            }\n            if coordinator.screen == .paused { pauseOverlay }\n\n            VStack {')
view=rep(view,'            HStack(spacing: 10) {\n                ForEach(TrialCatalog.all) { trial in','            ScrollView(.horizontal, showsIndicators: false) {\n                LazyHStack(spacing: 12) {\n                ForEach(TrialCatalog.all) { trial in')
view=rep(view,'                    .buttonStyle(.plain)\n                }\n            }\n            Button("В МЕНЮ")','                    .buttonStyle(.plain)\n                }\n                }\n                .scrollTargetLayout()\n                .padding(.horizontal, 24)\n            }\n            .scrollTargetBehavior(.viewAligned)\n            .frame(maxWidth: .infinity, maxHeight: 126)\n            Button("В МЕНЮ")')
view=view.replace('v1.6 • ИСПЫТАНИЯ • БОЙ + UI','v1.7 • DEVICE BUGFIX • SAFE TRIALS'); view_path.write_text(view)
plist=rep(plist,'<key>CFBundleShortVersionString</key><string>1.6</string>','<key>CFBundleShortVersionString</key><string>1.7</string>'); plist_path.write_text(plist)
print('Applied v1.7 device bugfix patch')
