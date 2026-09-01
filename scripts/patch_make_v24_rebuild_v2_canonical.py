from pathlib import Path

room_path = Path("Sources/RoomController.swift")
room_text = room_path.read_text()
old_sig = "    static func makeV24Demo() -> RoomController {\n"
legacy_sig = "    static func makeV24DemoLegacy() -> RoomController {\n"
if old_sig in room_text:
    room_text = room_text.replace(old_sig, legacy_sig, 1)
    room_path.write_text(room_text)
elif legacy_sig not in room_text:
    raise SystemExit("makeV24Demo signature not found")

v2_path = Path("Sources/V24LevelRebuildV2.swift")
v2_text = v2_path.read_text()
marker = "extension RoomController {\n"
wrapper = "extension RoomController {\n    static func makeV24Demo() -> RoomController {\n        makeV24DemoV2()\n    }\n\n"
if wrapper not in v2_text:
    if marker not in v2_text:
        raise SystemExit("V24LevelRebuildV2 extension marker not found")
    v2_text = v2_text.replace(marker, wrapper, 1)
    v2_path.write_text(v2_text)

print("V24 rebuild v2 is canonical makeV24Demo")
