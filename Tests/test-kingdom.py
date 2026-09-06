from pathlib import Path

layout = Path("Sources/TestLocationLayout.swift").read_text()
director = Path("Sources/KingdomArt.swift").read_text()
model = Path("Sources/TestLocationModel.swift").read_text()
king = Path("Resources/Kingdom")
wavs = list(king.glob("*.wav"))
total = sum(p.stat().st_size for p in king.iterdir())

checks = {
    "wide world": "width: 26500" in layout,
    "kingdom solids": "KingdomMap.extraSolids" in layout,
    "boss enemy": "miniBoss, boss" in model or ".boss" in model,
    "passive enemy": "passive, miniBoss" in model or ".passive" in model,
    "charms": "Прочный панцирь" in director,
    "geo": "Гео" in director,
    "music files": len(wavs) >= 8,
    "payload size": total >= 50_000_000,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit("kingdom contract failures: " + ", ".join(failed) + f" size={total}")
print(f"Kingdom contract PASS ({total/1e6:.1f} MB resources)")
