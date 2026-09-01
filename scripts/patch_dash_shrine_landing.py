from pathlib import Path

path = Path("Sources/RoomController.swift")
text = path.read_text()

old = "                platform(850, 190, 180),"
new = "                platform(860, 160, 260),"

if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("Dash Shrine landing platform signature not found")

path.write_text(text)
print("Dash Shrine landing platform: x=860 y=160 width=260")
