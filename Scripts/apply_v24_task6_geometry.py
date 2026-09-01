from pathlib import Path

path = Path("Sources/RoomController.swift")
text = path.read_text()

replacements = [
    (
        """                platform(950, 60, 500, 80),""",
        """                platform(990, 60, 400, 80),""",
    ),
    (
        """                platform(430, 310, 40, 420),\n                platform(770, 310, 40, 420),""",
        """                platform(480, 345, 40, 350),\n                platform(720, 345, 40, 350),""",
    ),
]

changed = False
for old, new in replacements:
    if new in text:
        continue
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"expected exactly one geometry match, found {count}: {old!r}")
    text = text.replace(old, new, 1)
    changed = True

if not changed:
    print("V24 teaching geometry already tuned")
    raise SystemExit(0)

path.write_text(text)
print("Tuned V24 Dash Shrine gap and Hollow Shaft climb walls")
