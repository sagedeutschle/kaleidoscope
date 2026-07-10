#!/usr/bin/env python3
"""Generate the Prismet 'Wizard King's Lens' app icon as SVG.

Fuses the app's identity:
  - kaleidoscope iris  -> a 12-fold jewel mandala (PrismetDesign.wheel palette)
  - illuminated scroll -> gilt bezel + warm rim light
  (The Wizard King figure — crown, face, beard — was removed by request; the
   icon is now purely the kaleidoscope lens.)
"""
import math
import os
import base64

W = 1024
C = W / 2  # center 512

# --- macOS squircle body (content inset ~100px, per Apple grid) ---
INSET = 100
BODY = W - 2 * INSET          # 824
RAD = 185                     # corner radius

# PrismetDesign.wheel jewel palette
GARNET  = "#DB474F"
AMBER   = "#E68C33"
GOLD    = "#CCA838"
JADE    = "#4C8C6B"
LAPIS   = "#3D75A8"
AMETHYST= "#76579E"
WHEEL = [GARNET, AMBER, GOLD, JADE, LAPIS, AMETHYST]

GILT      = "#D8A53B"   # gilt accent (PrismetDesign.gold-ish, brighter for leaf)
GILT_HI   = "#F4D77E"   # highlight gold
GILT_DEEP = "#9A6E22"   # shadow gold

def petal(cx, cy, angle_deg, length, width, color, opacity):
    """A tapered diamond 'facet' pointing outward from center."""
    a = math.radians(angle_deg)
    # tip (outer), base center (inner), two side points
    tipx = cx + math.cos(a) * length
    tipy = cy + math.sin(a) * length
    innerx = cx + math.cos(a) * (length * 0.18)
    innery = cy + math.sin(a) * (length * 0.18)
    perp = a + math.pi / 2
    midr = length * 0.55
    mx = cx + math.cos(a) * midr
    my = cy + math.sin(a) * midr
    s1x = mx + math.cos(perp) * width
    s1y = my + math.sin(perp) * width
    s2x = mx - math.cos(perp) * width
    s2y = my - math.sin(perp) * width
    return (f'<polygon points="{tipx:.1f},{tipy:.1f} {s1x:.1f},{s1y:.1f} '
            f'{innerx:.1f},{innery:.1f} {s2x:.1f},{s2y:.1f}" '
            f'fill="{color}" opacity="{opacity}"/>')

parts = []
parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">')

# ---- defs ----
parts.append('<defs>')
# midnight jewel field
parts.append(f'''<radialGradient id="field" cx="50%" cy="42%" r="72%">
  <stop offset="0%" stop-color="#2A2350"/>
  <stop offset="42%" stop-color="#1B1A3C"/>
  <stop offset="100%" stop-color="#0C0B1E"/>
</radialGradient>''')
# gilt bezel gradient
parts.append(f'''<linearGradient id="bezel" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0%" stop-color="{GILT_HI}"/>
  <stop offset="50%" stop-color="{GILT}"/>
  <stop offset="100%" stop-color="{GILT_DEEP}"/>
</linearGradient>''')
parts.append(f'''<radialGradient id="lens" cx="50%" cy="45%" r="60%">
  <stop offset="0%" stop-color="#FBF3D8" stop-opacity="0.9"/>
  <stop offset="35%" stop-color="{GOLD}" stop-opacity="0.25"/>
  <stop offset="100%" stop-color="#0C0B1E" stop-opacity="0"/>
</radialGradient>''')
parts.append(f'''<radialGradient id="medallion" cx="50%" cy="40%" r="65%">
  <stop offset="0%" stop-color="#241F45"/>
  <stop offset="100%" stop-color="#0E0C22"/>
</radialGradient>''')
parts.append(f'''<linearGradient id="goldfig" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0%" stop-color="{GILT_HI}"/>
  <stop offset="55%" stop-color="{GILT}"/>
  <stop offset="100%" stop-color="{GILT_DEEP}"/>
</linearGradient>''')
parts.append(f'''<radialGradient id="topglow" cx="50%" cy="0%" r="80%">
  <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.22"/>
  <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
</radialGradient>''')
# crisp drop shadow for the figure (no muddy blur of the artwork itself)
parts.append('<filter id="soft" x="-30%" y="-30%" width="160%" height="160%">'
             '<feDropShadow dx="0" dy="6" stdDeviation="6" flood-color="#000000" flood-opacity="0.45"/></filter>')
# clip to body squircle
parts.append(f'<clipPath id="bodyclip"><rect x="{INSET}" y="{INSET}" width="{BODY}" height="{BODY}" rx="{RAD}" ry="{RAD}"/></clipPath>')
parts.append('</defs>')

# ---- body background ----
parts.append(f'<g clip-path="url(#bodyclip)">')
parts.append(f'<rect x="{INSET}" y="{INSET}" width="{BODY}" height="{BODY}" fill="url(#field)"/>')
parts.append(f'<rect x="{INSET}" y="{INSET}" width="{BODY}" height="{BODY}" fill="url(#topglow)"/>')

# ---- kaleidoscope mandala (two rings of facets, 12-fold) ----
N = 12
# outer ring of long facets
for i in range(N):
    ang = i * (360 / N) - 90
    col = WHEEL[i % len(WHEEL)]
    parts.append(petal(C, C, ang, 360, 60, col, 0.55))
# inner ring offset, brighter
for i in range(N):
    ang = i * (360 / N) - 90 + (360 / N) / 2
    col = WHEEL[(i + 3) % len(WHEEL)]
    parts.append(petal(C, C, ang, 250, 42, col, 0.72))
# faceting overlay: thin gold radial spokes
for i in range(N):
    ang = math.radians(i * (360 / N) - 90)
    x2 = C + math.cos(ang) * 372
    y2 = C + math.sin(ang) * 372
    parts.append(f'<line x1="{C}" y1="{C}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{GILT}" stroke-width="2" opacity="0.30"/>')

# lens glow over mandala
parts.append(f'<circle cx="{C}" cy="{C}" r="380" fill="url(#lens)"/>')

# ---- gilt bezel rings ----
parts.append(f'<circle cx="{C}" cy="{C}" r="372" fill="none" stroke="url(#bezel)" stroke-width="16"/>')
parts.append(f'<circle cx="{C}" cy="{C}" r="372" fill="none" stroke="{GILT_DEEP}" stroke-width="2" opacity="0.7"/>')
parts.append(f'<circle cx="{C}" cy="{C}" r="356" fill="none" stroke="{GILT_HI}" stroke-width="1.5" opacity="0.6"/>')

# ---- central medallion ----
MED_R = 250
parts.append(f'<circle cx="{C}" cy="{C}" r="{MED_R}" fill="url(#medallion)"/>')
parts.append(f'<circle cx="{C}" cy="{C}" r="{MED_R}" fill="none" stroke="url(#bezel)" stroke-width="10"/>')
parts.append(f'<circle cx="{C}" cy="{C}" r="{MED_R-9}" fill="none" stroke="{GILT_DEEP}" stroke-width="1.5" opacity="0.8"/>')

# small jewel dots around medallion (constellation)
for i in range(N):
    ang = math.radians(i * (360 / N) - 90)
    r = MED_R - 26
    x = C + math.cos(ang) * r
    y = C + math.sin(ang) * r
    col = WHEEL[i % len(WHEEL)]
    parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="5" fill="{col}" opacity="0.9"/>')

parts.append('</g>')  # end bodyclip for background layers

# ============================================================
# CENTER EMOJI — a REAL, natural-looking earth: Microsoft Fluent Emoji 3D
# "Globe showing Americas" (U+1F30E), MIT-licensed. It's a glossy 3D render
# (not a flat pictograph), embedded as a raster image centered in the medallion
# so North + South America face the viewer.
# ============================================================
_here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(_here, "fluent_globe_americas_3d.png"), "rb") as _f:
    _png_b64 = base64.b64encode(_f.read()).decode("ascii")
EMOJI_SIZE = 372.0           # fills the medallion cleanly (Ø ~482)
_ex = C - EMOJI_SIZE / 2     # center the square on C
parts.append(f'<image x="{_ex:.1f}" y="{_ex:.1f}" width="{EMOJI_SIZE:.1f}" '
             f'height="{EMOJI_SIZE:.1f}" href="data:image/png;base64,{_png_b64}"/>')

parts.append('</svg>')

svg = "\n".join(parts)
out = "/private/tmp/claude-501/-Users-gtrktscrb-Desktop-GtrktscrB/b3310d87-fa82-4b6f-816f-eef28e4187f6/scratchpad/kaleidoscope_icon.svg"
with open(out, "w") as f:
    f.write(svg)
print("wrote", out)
