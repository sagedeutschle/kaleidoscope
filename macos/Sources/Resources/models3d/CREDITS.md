# 3D Chess Piece Models — Credits & Attribution

## Set
**Staunton-Pieces** — an open-source 3D Staunton chess set (the set used by the
lichess.org 3D board).

- **Author / Copyright holder:** clarkerubber
- **Source:** https://github.com/clarkerubber/Staunton-Pieces
- **Original files used:** `Source/Staunton/{King,Queen,Rook,Bishop,Knight,Pawn}/*.STL`
- **License:** MIT License — Copyright (c) 2014 clarkerubber

### Required attribution string (MIT — include in app credits/about)
```
Chess piece models: "Staunton-Pieces" by clarkerubber
https://github.com/clarkerubber/Staunton-Pieces
Licensed under the MIT License. Copyright (c) 2014 clarkerubber.
```

### Full MIT license text
```
The MIT License (MIT)

Copyright (c) 2014 clarkerubber

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Files in this folder

| Piece  | File         | Material    |
|--------|--------------|-------------|
| King   | `king.obj`   | `king.mtl`  |
| Queen  | `queen.obj`  | `queen.mtl` |
| Rook   | `rook.obj`   | `rook.mtl`  |
| Bishop | `bishop.obj` | `bishop.mtl`|
| Knight | `knight.obj` | `knight.mtl`|
| Pawn   | `pawn.obj`   | `pawn.mtl`  |

Each `.obj` is ASCII Wavefront OBJ (positions + smooth per-vertex normals, no
UVs). The accompanying `.mtl` defines a single white `DefaultMaterial`
(`Kd 1 1 1`) — tint per-piece in code (see below). Format is natively loadable
by Apple Model I/O / SceneKit.

## How these were produced (reproducible)
Original source is binary STL. Converted with Assimp 6.0.0:

```sh
# download (per piece P in Bishop King Knight Pawn Queen Rook):
curl -sL https://raw.githubusercontent.com/clarkerubber/Staunton-Pieces/master/Source/Staunton/$P/$P.STL -o $P.STL
# 1) STL -> OBJ (keeps flat per-face normals, split verts)
assimp export $P.STL ${p}_raw.obj
# 2) strip normals so coincident positions can weld
sed -e '/^vn /d' -e 's#//[0-9]*##g' ${p}_raw.obj > ${p}_pos.obj
# 3) re-import: join identical vertices + generate smooth normals
assimp export ${p}_pos.obj ${p}.obj -jiv -gsn
```
This welds the STL's split vertices (~6x vertex reduction) and bakes smooth
per-vertex normals, so the curved bodies shade smoothly instead of faceted.

## Geometry (verified via `assimp info` and a live SceneKit/Model I/O render)

| Piece  | Vertices | Faces (tris) | Bounding box W×H×D (model units) |
|--------|----------|--------------|----------------------------------|
| Pawn   | 4,701    | 9,398        | 24 × 43 × 24                     |
| Rook   | 5,741    | 11,478       | 30 × 49 × 30                     |
| Knight | 31,273   | 62,500       | 30 × 59 × 30                     |
| Bishop | 5,951    | 11,898       | 30 × 59 × 30                     |
| Queen  | 11,886   | 23,768       | 30 × 68 × 30                     |
| King   | 9,484    | 18,964       | 30 × 78 × 30                     |

## Orientation / scale notes (read before placing on a board)
- **Up axis: Y.** Pieces already stand upright (height is along +Y). No rotation
  needed for SceneKit (Y-up).
- **Units:** roughly millimeters (king ≈ 78, pawn ≈ 43). Heights are
  proportional to a real Staunton set.
- **Origin is NOT centered.** Each piece's base sits on the Y=0 plane (good),
  but it is offset in X/Z — the model origin is at the bounding-box corner, not
  the central axis. The **Queen is especially offset (X spans 65.9 → 95.9).**
  You MUST re-center horizontally per piece (set `node.pivot` to the bbox
  center in X/Z and bbox-min in Y) before positioning on a tile. See snippet.
- **Recommended uniform scale: ≈ 0.017** (i.e. `scale = 1.0/59`). That gives:
  pawn ≈ 0.73, rook ≈ 0.83, knight ≈ 1.00, bishop ≈ 1.00, queen ≈ 1.16,
  king ≈ 1.33 SceneKit units tall — pawn in the 0.7–0.9 band, king ≈ 1.3.
  (The real set's king:pawn ratio is a bit steeper than the requested target,
  so a single scale lands the pawn at the low end ~0.73.)
- Footprint after scaling: ~0.4–0.5 units wide, comfortably inside a 1-unit tile.
