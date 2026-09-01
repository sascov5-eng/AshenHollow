from pathlib import Path

path = Path("Sources/RoomController.swift")
text = path.read_text()

replacements = [
    (
        "                platform(980, 166, 220),",
        "                platform(930, 166, 220),",
        "Watcher Hall entry-cover signature not found",
    ),
    (
        "                EnemySpawn(id: 1, archetype: .heavy, position: RoomPoint(x: 620, y: 130)),",
        "                EnemySpawn(id: 1, archetype: .heavy, position: RoomPoint(x: 620, y: 136)),",
        "Warden Gate Heavy spawn signature not found",
    ),
    (
        "                EnemySpawn(id: 1, archetype: .runner, position: RoomPoint(x: 820, y: 230)),",
        "                EnemySpawn(id: 1, archetype: .runner, position: RoomPoint(x: 180, y: 537)),",
        "Ashen Ascent Runner spawn signature not found",
    ),
]

for old, new, error in replacements:
    if old in text:
        text = text.replace(old, new, 1)
    elif new not in text:
        raise SystemExit(error)

path.write_text(text)
print("Watcher spawn cover, Warden Heavy support, and late Ashen Ascent Runner fixed")
