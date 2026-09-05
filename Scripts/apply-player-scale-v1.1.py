from pathlib import Path

path = Path("Sources/GameScene.swift")
text = path.read_text()
old = "sprite.size = CGSize(width: 112, height: 112)"
new = "sprite.size = CGSize(width: 480, height: 480)"
if old not in text:
    raise SystemExit("player sprite size contract not found")
path.write_text(text.replace(old, new, 1))
print("PLAYER SCALE 112 -> 480")
