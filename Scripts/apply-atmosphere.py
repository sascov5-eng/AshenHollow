#!/usr/bin/env python3
from pathlib import Path

scene_path = Path("Sources/GameSceneV14.swift")
scene = scene_path.read_text()
if "EnvArt.attachPlayerLight" in scene:
    print("Atmosphere already applied")
    raise SystemExit(0)

old = "        audio.prepare()\n    }\n"
new = "        audio.prepare()\n        EnvArt.attachPlayerLight(to: player)\n        EnvArt.installAtmosphere(in: self)\n    }\n"
if old not in scene:
    raise SystemExit("atmosphere missing audio.prepare marker")
scene_path.write_text(scene.replace(old, new, 1))
print("Applied Hallownest atmosphere")
