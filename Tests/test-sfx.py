from pathlib import Path

scene = Path("Sources/GameSceneV14.swift").read_text()
audio = Path("Sources/GameAudio.swift").read_text()
view = Path("Sources/GameView.swift").read_text()
workflow = Path(".github/workflows/build-ipa.yml").read_text()

checks = {
    "audio engine": "final class GameAudio" in audio,
    "footstep synth": "case footstep" in audio,
    "playback session": ".playback" in audio,
    "audio prepared": "audio.prepare()" in scene,
    "jump sfx": "audio.play(.jump)" in scene,
    "wall jump sfx": "audio.play(.wallJump)" in scene,
    "land sfx": "audio.play(.land)" in scene,
    "footstep sfx": "audio.play(.footstep)" in scene,
    "attack sfx": "audio.play(.attack)" in scene,
    "dash sfx": "audio.play(.dash)" in scene,
    "heal sfx": "audio.play(.heal)" in scene,
    "heal complete sfx": "audio.play(.healComplete)" in scene,
    "avfoundation compile": "-framework AVFoundation" in workflow,
    "v1.7 label kept": "v1.7 • DEVICE BUGFIX • SAFE TRIALS" in view,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit("SFX contract failures: " + ", ".join(failed))
print("SFX contract PASS")
