#!/usr/bin/env python3
from pathlib import Path

scene_path = Path("Sources/GameSceneV14.swift")
scene = scene_path.read_text()
if "EnvArt.addForeground" in scene:
    print("Atmosphere already applied")
    raise SystemExit(0)

block = """        audio.prepare()
        audio.startAmbience()
        EnvArt.attachPlayerLight(to: player)
        EnvArt.installAtmosphere(in: self)
        EnvArt.addForeground(to: self, worldBounds: worldLayout.worldBounds)
        EnvArt.addParticles(to: self)
    }
"""

if "        audio.prepare()\n        EnvArt.attachPlayerLight(to: player)\n        EnvArt.installAtmosphere(in: self)\n    }\n" in scene:
    scene = scene.replace(
        "        audio.prepare()\n        EnvArt.attachPlayerLight(to: player)\n        EnvArt.installAtmosphere(in: self)\n    }\n",
        block,
        1,
    )
elif "        audio.prepare()\n    }\n" in scene:
    scene = scene.replace("        audio.prepare()\n    }\n", block, 1)
else:
    raise SystemExit("atmosphere missing audio.prepare marker")

scene_path.write_text(scene)
print("Applied Hallownest atmosphere")
