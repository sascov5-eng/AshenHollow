from pathlib import Path

path = Path("Sources/V24LevelRebuildV2.swift")
text = path.read_text()
replacements = [
    (
        "EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 720, y: 300))",
        "EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 660, y: 300))",
        "Lower Hall landing safety"
    ),
]

changed = False
for old, new, label in replacements:
    if old in text:
        text = text.replace(old, new, 1)
        changed = True
    elif new not in text:
        raise SystemExit(f"Missing signature: {label}")

if changed:
    path.write_text(text)
    print("Applied V24 rebuild v2 safety tuning")
else:
    print("V24 rebuild v2 safety tuning already applied")
