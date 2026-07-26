#!/usr/bin/env python3
"""Background-remove chosen masters -> transparent, square, 1024 & 512 PNGs per pose."""
import json, subprocess
from pathlib import Path
from rembg import remove
from PIL import Image
import io

ROOT = Path(__file__).resolve().parents[1]
man = json.loads((ROOT / "manifest.json").read_text())
M = ROOT / "masters"

def process(src: Path, char: str, pose: str):
    cut = remove(src.read_bytes())               # -> PNG bytes w/ alpha
    im = Image.open(io.BytesIO(cut)).convert("RGBA")
    # trim to content, pad to square, resize to 1024 then 512
    bbox = im.getbbox(); im = im.crop(bbox) if bbox else im
    side = max(im.size); sq = Image.new("RGBA", (side, side), (0,0,0,0))
    sq.paste(im, ((side-im.width)//2, (side-im.height)//2))
    outdir = ROOT / char; outdir.mkdir(exist_ok=True)
    sq.resize((1024,1024), Image.LANCZOS).save(outdir / f"{pose}@2x.png")
    sq.resize((512,512),  Image.LANCZOS).save(outdir / f"{pose}@1x.png")
    print("processed", char, pose)

for char, cfg in man["characters"].items():
    for pose in cfg["poses"]:
        src = M / f"{char}-{pose}.jpg"
        if not src.exists():
            print("!! missing chosen master:", src.name, "(pick a winner in Task 4 Step 4)"); continue
        process(src, char, pose)
print("done")
