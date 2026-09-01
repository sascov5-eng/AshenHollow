from pathlib import Path

path = Path("Sources/V24LevelRebuildV2.swift")
text = path.read_text()
replacements = [
    (
        "EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 720, y: 300))",
        "EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 660, y: 300))",
        "Lower Hall landing safety"
    ),
    (
        "platform(1050, 60, 300, 80)",
        "platform(1000, 60, 400, 80)",
        "Ashen Ascent entry arena width"
    ),
    (
        "EnemySpawn(id: 1, archetype: .runner, position: RoomPoint(x: 930, y: 130))",
        "EnemySpawn(id: 1, archetype: .runner, position: RoomPoint(x: 850, y: 130))",
        "Ashen Ascent Runner spawn safety"
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
