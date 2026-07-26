#!/usr/bin/env python3
"""Validate that every manifest key resolves to a real, correctly-formatted asset."""
import json, sys, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent
man = json.loads((ROOT / "manifest.json").read_text())
scales = man["canvas"]["scales"]
errors = []

def png_size_and_alpha(p: Path):
    b = p.read_bytes()
    if b[:8] != b"\x89PNG\r\n\x1a\n":
        return None, None, "not a PNG"
    w, h = struct.unpack(">II", b[16:24])
    color_type = b[25]
    has_alpha = color_type in (4, 6)  # grayscale+alpha or RGBA
    return (w, h), has_alpha, None

# poses
for char, cfg in man["characters"].items():
    for pose in cfg["poses"]:
        for scale, px in scales.items():
            rel = f"{char}/{pose}@{scale}.png"
            p = ROOT / rel
            if not p.exists():
                errors.append(f"MISSING {rel}"); continue
            size, alpha, err = png_size_and_alpha(p)
            if err: errors.append(f"{rel}: {err}"); continue
            if size != (px, px): errors.append(f"{rel}: expected {px}x{px}, got {size[0]}x{size[1]}")
            if not alpha: errors.append(f"{rel}: expected transparency (RGBA), got opaque")

# icon
icon = man["icon"]; ip = ROOT / icon["file"]
if not ip.exists():
    errors.append(f"MISSING {icon['file']}")
else:
    size, alpha, err = png_size_and_alpha(ip)
    if err: errors.append(f"{icon['file']}: {err}")
    elif size != (icon["w"], icon["h"]): errors.append(f"{icon['file']}: expected {icon['w']}x{icon['h']}, got {size}")

if errors:
    print(f"FAIL — {len(errors)} problem(s):"); [print("  -", e) for e in errors]; sys.exit(1)
print("PASS — all manifest assets present and well-formed."); sys.exit(0)
