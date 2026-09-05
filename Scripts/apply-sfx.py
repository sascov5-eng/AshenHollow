#!/usr/bin/env python3
from pathlib import Path

scene_path = Path("Sources/GameSceneV14.swift")
view_path = Path("Sources/GameView.swift")
workflow_path = Path(".github/workflows/build-ipa.yml")
scene = scene_path.read_text()
view = view_path.read_text()

if "private let audio = GameAudio()" in scene:
    print("SFX already applied")
    raise SystemExit(0)

def need(text, old, new, label):
    if old not in text:
        raise SystemExit(f"SFX missing marker ({label}): {old[:120]}")
    return text.replace(old, new, 1)

scene = need(
    scene,
    "    private var platformContactGrace: TimeInterval = 0\n",
    "    private var platformContactGrace: TimeInterval = 0\n    private let audio = GameAudio()\n    private var footstepTimer: TimeInterval = 0\n",
    "audio properties",
)

scene = need(
    scene,
    "        initializeEnemySessionState()\n        beginTrialAttempt()\n    }\n",
    "        initializeEnemySessionState()\n        beginTrialAttempt()\n        audio.prepare()\n    }\n",
    "audio.prepare",
)

scene = need(
    scene,
    "        movePlayer(CGFloat(dt))\n        updateSafePosition()\n",
    "        movePlayer(CGFloat(dt))\n        updateFootsteps(dt)\n        updateSafePosition()\n",
    "updateFootsteps call",
)

scene = need(
    scene,
    "            tutorialController.register(action: .wallJump)\n            return\n",
    "            tutorialController.register(action: .wallJump)\n            audio.play(.wallJump)\n            return\n",
    "wall jump sfx",
)

scene = need(
    scene,
    "riderPlatformID=nil; platformContactGrace=0; velocity.dy = CGFloat(tuning.jumpVelocity); isGrounded = false; coyoteTimer = 0; jumpBufferTimer = 0; setAnimation(.jump, force: true)",
    "riderPlatformID=nil; platformContactGrace=0; velocity.dy = CGFloat(tuning.jumpVelocity); isGrounded = false; coyoteTimer = 0; jumpBufferTimer = 0; setAnimation(.jump, force: true); audio.play(.jump)",
    "jump sfx",
)

scene = need(
    scene,
    "        velocity.dx = CGFloat(direction * tuning.dashSpeed); velocity.dy = 0; setAnimation(.dash, force: true)\n    }\n",
    "        audio.stop(.heal)\n        velocity.dx = CGFloat(direction * tuning.dashSpeed); velocity.dy = 0; setAnimation(.dash, force: true); audio.play(.dash)\n    }\n",
    "dash sfx",
)

scene = need(
    scene,
    "        setAnimation(.attack1, force: true)\n        attackNearbySecretWall()\n",
    "        setAnimation(.attack1, force: true)\n        attackNearbySecretWall()\n        audio.stop(.heal)\n        audio.play(.attack)\n",
    "attack sfx",
)

scene = need(
    scene,
    "        beginHealFocusFX()\n    }\n",
    "        beginHealFocusFX()\n        audio.play(.heal)\n    }\n",
    "heal sfx",
)

scene = need(
    scene,
    "            currentHP = min(maxHP, currentHP + 1)\n            completeHealFocusFX()\n",
    "            currentHP = min(maxHP, currentHP + 1)\n            completeHealFocusFX()\n            audio.stop(.heal)\n            audio.play(.healComplete)\n",
    "heal complete sfx",
)

scene = need(
    scene,
    "    private func cancelHealFocusFX() {\n        essenceController.cancelFocus()\n",
    "    private func cancelHealFocusFX() {\n        essenceController.cancelFocus()\n        audio.stop(.heal)\n",
    "heal cancel stop",
)

scene = need(
    scene,
    "        var groundedDuringMove = false\n        for _ in 0..<steps { moveHorizontally(stepDX); if moveVertically(stepDY) { groundedDuringMove = true } }\n        if groundedDuringMove || isStandingOnSurface() { isGrounded = true; coyoteTimer = tuning.coyoteDuration; dashController.restoreAirDash() }\n        else { isGrounded = false }\n",
    "        let wasGrounded = isGrounded\n        var groundedDuringMove = false\n        for _ in 0..<steps { moveHorizontally(stepDX); if moveVertically(stepDY) { groundedDuringMove = true } }\n        if groundedDuringMove || isStandingOnSurface() {\n            if !wasGrounded { audio.play(.land) }\n            isGrounded = true; coyoteTimer = tuning.coyoteDuration; dashController.restoreAirDash()\n        }\n        else { isGrounded = false }\n",
    "land sfx",
)

footsteps = '''    private func updateFootsteps(_ dt: TimeInterval) {
        let running = isGrounded && abs(velocity.dx) > 55 && !dashController.isDashing && !essenceController.isFocusing && currentWallCling == nil && recoveryLockRemaining <= 0
        guard running else { footstepTimer = 0; return }
        footstepTimer -= dt
        if footstepTimer <= 0 {
            audio.play(.footstep)
            let speed = min(1, Double(abs(velocity.dx)) / tuning.runSpeed)
            footstepTimer = 0.30 - 0.08 * speed
        }
    }

'''
scene = need(
    scene,
    "    private func tryConsumeJump() {\n",
    footsteps + "    private func tryConsumeJump() {\n",
    "footstep function",
)

scene_path.write_text(scene)

if "v1.7 • DEVICE BUGFIX • SAFE TRIALS" in view and "• SFX" not in view:
    view = view.replace("v1.7 • DEVICE BUGFIX • SAFE TRIALS", "v1.7 • DEVICE BUGFIX • SAFE TRIALS • SFX", 1)
    view_path.write_text(view)

print("Applied action SFX to v1.7 scene")
