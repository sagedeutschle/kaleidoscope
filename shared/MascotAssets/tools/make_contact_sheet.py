#!/usr/bin/env python3
import subprocess, sys
from pathlib import Path
M = Path(__file__).resolve().parents[1] / "masters"
files = sorted(str(p) for p in M.glob("*.jpg"))
# requires ImageMagick `montage`; falls back to a note if absent
try:
    subprocess.run(["montage", *files, "-tile", "6x", "-geometry", "200x200+4+4",
                    str(M.parent / "contact-sheet.png")], check=True)
    print("wrote contact-sheet.png")
except FileNotFoundError:
    print("ImageMagick 'montage' not found — open masters/*.jpg directly to review.")
