from pathlib import Path

path = Path("Sources/RoomController.swift")
text = path.read_text()

old = "                platform(980, 166, 220),"
new = "                platform(930, 166, 220),"

if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("Watcher Hall entry-cover signature not found")

path.write_text(text)
print("Watcher Hall entry cover moved clear of player spawn")
