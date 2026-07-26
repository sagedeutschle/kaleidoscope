# Style guide

## Art direction
Cartoonish ("Classic Toon"): bold clean outlines, rounded chunky shapes, warm friendly
expressions, vibrant flat colors. Placeholder art is AI-generated and swap-able (see
`shared/MascotAssets/README.md`).

## Locked palette (hex)
- Mookie fur — ink `#1A1A1E`, white `#F5F3EC`
- Signature hat purple — primary `#7C5CFF`, deep accent `#4B2E83`
- Reynard fur — orange `#F0692A`, deep `#E8531E`, belly cream `#F3E3C8`
- Reynard dealer — vest charcoal `#2A2A30`, bow tie `#B3122B`
- App neutrals — near-black `#0B0B0F`, panel `#141420`

## Canvas & scale rules (placeholders)
- Master art generated at **1024×1024**, transparent background after processing.
- Exported per pose as square transparent PNG: **`<pose>@2x.png` = 1024px** (native),
  **`<pose>@1x.png` = 512px** (downscaled). No upscaling.
- App icon master: **1024×1024**, opaque brand background (iOS icons forbid alpha).
