from pathlib import Path

path = Path("Sources/RoomRuntimeInstaller.swift")
text = path.read_text()
old = "    let controller = RoomController.makeV24Demo()\n"
new = "    let controller = RoomController.makeV24DemoV2()\n"

if new in text:
    print("V24 rebuild v2 already active")
elif old in text:
    path.write_text(text.replace(old, new, 1))
    print("Activated V24 rebuild v2 runtime")
else:
    raise SystemExit("RoomRuntimeInstaller controller signature not found")
