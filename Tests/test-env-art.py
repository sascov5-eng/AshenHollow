from pathlib import Path

runtime = Path("Sources/V15RuntimeSupport.swift").read_text()
env = Path("Resources/EnvArt")
workflow = Path(".github/workflows/build-ipa.yml").read_text()

files = [
    "far.jpg", "mid.jpg", "near.jpg", "chamber.jpg",
    "ground.jpg", "ceiling.jpg", "wall.jpg", "fill.jpg",
    "darkness.png", "shadow.png",
]
checks = {
    "env art loader": "enum EnvArt" in runtime,
    "world layers": "addWorldLayers" in runtime,
    "player light": "SKLightNode" in runtime,
    "drop shadows": "addDropShadow" in runtime,
    "atmosphere": "installAtmosphere" in runtime,
    "ci copies far layer": 'test -f "$APP/EnvArt/far.jpg"' in workflow,
}
for name in files:
    checks[name] = (env / name).is_file() and (env / name).stat().st_size > 4000

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit("Env art contract failures: " + ", ".join(failed))
print("Env art contract PASS")
