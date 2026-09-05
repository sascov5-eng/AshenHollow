from pathlib import Path

runtime = Path("Sources/V15RuntimeSupport.swift").read_text()
env = Path("Resources/EnvArt")
workflow = Path(".github/workflows/build-ipa.yml").read_text()

files = ["floor.png", "fill.png", "wall.png", "ceiling.png", "background.jpg"]
checks = {
    "env art loader": "enum EnvArt" in runtime,
    "painted terrain": "EnvArt.terrainNode" in runtime,
    "painted background": "EnvArt.addBackground" in runtime,
    "linear filtering": "filteringMode = .linear" in runtime,
    "ci copies env art": 'test -f "$APP/EnvArt/floor.png"' in workflow,
}
for name in files:
    checks[name] = (env / name).is_file() and (env / name).stat().st_size > 10_000

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit("Env art contract failures: " + ", ".join(failed))
print("Env art contract PASS")
