# Luma Visual Overhaul Design

## Goal
Replace AshenHollow's placeholder visual layer with the approved Luma art direction while preserving gameplay, collision geometry, interaction IDs, enemy behavior, and progression.

## Approved visual source
Use the two approved Luma environment/art-sheet concepts from the current design session as the visual reference. The implementation must preserve the canonical Veir/Luma visual language: charcoal/blue-black ruins, pale ash/stone, warm gold light, hand-painted inked silhouettes, restrained glow, readable mobile silhouettes.

## Scope
- Three parallax environment layers: far background, midground, near foreground.
- Terrain/platform/decor visual replacement.
- Door states and shortcut door.
- Lever OFF/ON and shortcut lever.
- Checkpoint.
- Breakable/hidden wall visuals.
- Hazards including spikes and visually compatible acid/death areas.
- Three core enemies: grub/groundPatrol, fly/flying, husk/aggressive.
- Preserve existing resource names where practical to avoid gameplay regressions.

## Runtime constraints
- Do not alter collision rectangles, patrol ranges, HP, rewards, interaction links, checkpoint positions, traversal specs, or movement physics as part of this art pass.
- Existing Swift/SpriteKit resource pipeline remains authoritative.
- Art must remain readable on Android/mobile-scale presentation despite the current Swift prototype runtime.
- Source sheets are concept sheets, not production-ready transparent sprites. Production assets must be clean isolated sprites rather than cropped panels with baked backgrounds/text.

## Asset mapping
- enemy_grub.png -> groundPatrol
- enemy_fly.png -> flying
- enemy_husk.png -> aggressive
- door visual -> door and shortcutDoor state presentation
- lever visual -> lever and shortcutLever state presentation
- environment -> far/mid/near parallax + terrain/platform/decor

## Acceptance
The playable map retains identical gameplay behavior while the visible placeholder art is replaced by a coherent Luma visual set. Missing production-quality isolated sprites must not be faked by shipping crops containing sheet labels/backgrounds; they must be supplied as isolated art before final replacement.