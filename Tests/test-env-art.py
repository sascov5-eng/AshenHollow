from pathlib import Path

runtime = Path("Sources/V15RuntimeSupport.swift").read_text()
audio = Path("Sources/GameAudio.swift").read_text()
env = Path("Resources/EnvArt")
workflow = Path(".github/workflows/build-ipa.yml").read_text()

files = [
    "cross_far.jpg", "cross_mid.jpg", "platform.png", "fg.png",
    "fg_ceil.png", "wall_ink.png", "rays.png", "spore.png", "soul.png",
]
checks = {
    "crossroads far": "cross_far.jpg" in runtime,
    "inked terrain": "lineWidth = 5.5" in runtime,
    "foreground": "addForeground" in runtime,
    "spores": "addParticles" in runtime,
    "god rays": "hkRays" in runtime,
    "soul glow": "soulGlow" in runtime,
    "ambience": "startAmbience" in audio,
    "ci far layer": 'test -f "$APP/EnvArt/cross_far.jpg"' in workflow,
}
for name in files:
    checks[name] = (env / name).is_file() and (env / name).stat().st_size > 400

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit("Env art contract failures: " + ", ".join(failed))
print("Env art contract PASS")
