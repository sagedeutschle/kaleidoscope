# Axiom-style Arrow Move Gizmo — Research Findings

**Purpose:** Inform the design of an "Axiom-like" three-axis RGB arrow move gizmo for **Brick Bench**, a macOS SwiftUI + SceneKit LEGO building app. The user explicitly likes the RGB arrow gizmo and wants arrow colors to be user-customizable via a tucked-away/advanced setting.

**Date:** 2026-06-26
**Scope:** Axiom UX, standard 3D translate-gizmo conventions, snapping + smooth motion, customizable axis colors, SceneKit implementation notes, and concrete Brick Bench recommendations.

---

## 1. Axiom (Moulberry's Minecraft building mod) — how movement works

Axiom ships two relevant systems: a block-builder **Move** tool (for nudging cuboid selections) and an editor **Gizmo** (for free 3D transform of objects/entities with colored arrows). Both are well-documented, so we can lean on Axiom directly rather than only on general conventions.

### 1a. The Gizmo (the part the user likes — colored arrows)

From Axiom's gizmo docs (https://axiomdocs.moulberry.com/editor/gizmos.html):

- **Axis arrows are RGB and map to XYZ.** Direct quote: *"The red, green and blue arrows allow the gizmo to be dragged along the X, Y and Z axis respectively."* This is exactly the convention the user likes, and it matches the universal standard (Section 2).
- **Center node = free move.** The center node is the primary grab handle; dragging it moves the gizmo across all three axes while *"the gizmo will maintain the same distance to the camera"* — i.e., it slides on a camera-facing plane.
- **Plane nodes = two-axis drag.** Secondary handles move along two axes at once (the "plane" handles between axes).
- **Rotation rings** mirror the same RGB axis coloring for rotation around X/Y/Z.
- **Scale nodes** appear at the arrow tips (for display entities / "Move Selection") to stretch along an axis.
- **Selection:** *"use left-click on the Center Node"* to engage the gizmo; right-click adjusts other elements.
- **Global vs. local orientation:** the gizmo can lock axes to world space (global) or to the object's own rotation (local).

### 1b. Snapping behavior on the gizmo (the "intuitive and smooth" feel)

Axiom's gizmo offers **three snapping modes** layered onto an otherwise smooth drag:

- **Default snapping** — moves on the natural grid.
- **Increased snapping — hold Control** — *"locks to one-block increments and 15-degree rotations."*
- **No snapping — hold Shift** — free, continuous motion.

This hold-to-modify pattern is the core of why it feels good: the object glides continuously under the cursor, but a held modifier lets you toggle between coarse discrete steps and fully free motion without leaving the drag. This is the same pattern used by Blender/Unity/Unreal (Section 3).

### 1c. The block Move tool (cuboid selections)

From the Move tool docs (https://axiomdocs.moulberry.com/builder/buildertools/move.html):

- Create a selection (left-click corner 1, right-click corner 2; middle-click for face-select).
- Scrolling starts a **hologram preview** of the move — you see the result before committing.
- **Arrows on the selection faces indicate the scroll-up direction.** *"Scrolling up will push the selection away from the player and scrolling down will bring the selection closer... the direction the player is facing determines the direction the selection is pulled or pushed."*
- **Axis constraint by holding X / Y / Z** during nudging — force movement to one axis.
- Flip (Ctrl+F) and Rotate (Ctrl+R) relative to player facing; right-click confirms; Ctrl+Z/Y undo/redo.

**Takeaways that explain the "intuitive and smooth" feel:**
1. RGB arrows = instant axis legibility, no labels needed.
2. A **center free-move handle** that stays at constant camera distance, so casual moves "just work" without picking an axis.
3. **Hold-to-snap modifiers** (Ctrl = coarse, Shift = free) layered over continuous drag.
4. A **live hologram/ghost preview** so the user sees the destination before committing.
5. Constant **visual feedback** (face arrows showing direction).

---

## 2. Standard 3D translate-gizmo conventions (Blender / Unity / Unreal / Godot / Maya / 3ds Max)

### 2a. RGB = XYZ is the near-universal standard (confirmed, multiple vendors)

The X=red, Y=green, Z=blue convention is essentially universal. The mnemonic is **RGB → XYZ**:

- **Blender:** *"A gizmo always has three color-coded axes: X (red), Y (green), and Z (blue)."* (Viewport Gizmos manual.)
- **Unity:** axes *"are represented by the colors red, green, and blue respectively."* (Transforms manual.)
- **Unreal Engine:** *"red represents the X axis, green represents the Y axis, and blue represents the Z axis"*; the translation gizmo is *"a set of color-coded arrows pointing down the positive direction of each axis."* (Transforming Actors docs.)
- **Godot:** *"the rings and arrows are color-coded to match the axis colors"* — red X, green Y, blue Z. (Godot 3D editor docs / recipes.)
- **3ds Max:** *"each axis is assigned one of three colors: X is red, Y is green, and Z is blue."*
- **ZBrush:** *"Click and drag on the red (X), green (Y) or blue (Z) arrow to perform a translation."*
- **After Effects:** red = X (horizontal), green = Y (vertical), blue = Z (depth).

Conclusion: ship X=red, Y=green, Z=blue as the default. It is what every 3D user already expects, including Axiom users.

### 2b. Handle shapes / anatomy of a translate gizmo

The de-facto standard widget (consistent across Blender, Unity, Unreal, Godot, Maya, 3ds Max):

- **Three axis arrows** (cylinder/line shaft + **cone (or cube) tip**) for single-axis translation. Drag the arrow head to move along that one axis.
- **Plane-drag squares** in the corner where two axes meet — drag the square to move on that plane (XY, XZ, YZ), constraining the third axis. Blender: *"if you click and drag the square, you can move the object along the plane... The red square... will move the object on the Z and Y axis, omitting the X axis."* Unreal: *"click the square near the point where the two axes meet, then drag to move the actor along the plane."*
- **Center free-move handle** (grey square or circle) at the axis intersection — Unreal: *"click and drag the grey square or circle at the point where all three axes intersect"* to move freely on the camera plane. (Axiom's center node behaves the same way.)

### 2c. Hover / active highlight states

- Hovering a handle highlights it; the active/selected axis is typically recolored to **yellow** (and/or brightened) to signal "this is the one that will move." This is the standard affordance across Blender/Unity/Unreal/Maya. (Blender forum/feature history: hovering an axis or the little plane square highlights it.)
- The convention: base color = identity (R/G/B), **yellow = "armed / hovered / active."** Yellow is chosen because it reads as "selected" against any of R/G/B without colliding with them.

### 2d. Drag → single-axis translation math (the load-bearing part)

The robust, camera-angle-independent approach (Our Machinery "Gizmo Repair", https://ruby0x1.github.io/machinery_blog_archive/post/linear-algebra-shenanigans-gizmo-repair/) is **project in 2D screen space, not 3D**:

1. **Axis → screen space.** Take two points on the world-space axis line and project them to screen coords (`world_to_screen` / SceneKit `projectPoint`). This gives a 2D line: a screen position `a` and a screen direction `u`.
2. **Project the mouse onto the 2D line.** Classic point-on-line projection: for cursor point `p`,
   `t = dot(u, p - a) / dot(u, u)`, then closest point `= a + t*u`.
   This is the screen point on the axis nearest the cursor.
3. **Back to world.** Cast a ray from that projected screen point into the scene (`screen_to_world` / SceneKit `unprojectPoint`) and intersect it with the 3D axis line (line–line closest point) to get the exact world position on the axis.

Key insight, quoted: the fix is to *"pull the axis of the gizmo into screen space and project the mouse position onto that"* — doing the projection in 2D *"eliminates the ambiguity present in 3D-to-2D coordinate conversion, ensuring the cursor always maps correctly to the axis regardless of camera angle."* A naive "unproject cursor straight into 3D" approach drifts badly when the axis points toward/away from the camera.

A simpler-but-adequate alternative (used by many drag implementations, see SceneKit Section 5): track the **delta** between the previous and current cursor positions projected onto the axis, and add that delta to the object's position each frame — this avoids absolute-position snapping/jumps.

---

## 3. Snapping + smooth motion (grid snap that still feels smooth)

The goal: the brick **glides** under the cursor but **settles** on discrete lattice steps. How editors achieve this:

### 3a. Hold-to-snap modifiers layered over continuous drag

- **Unity:** *"To move, rotate, or scale by increment snap values, hold down the Control key (Windows) or Command key (macOS) while using one of the transform gizmos."* Snap values are per-axis (linked or unlinked X/Y/Z). With automatic grid snapping on, the tools *"snap the selected GameObject(s) to the grid along the active gizmo axis."* (Unity Snap Increments / Grid Snapping manuals.)
- **Blender:** snapping is a held modifier (Ctrl) during transform; Blender can *"break the overall transformation into multiple steps, performing a snap each time"* for better incremental results. (Snapping manual.)
- **Axiom:** Ctrl = "increased snapping" (one-block increments), Shift = no snapping (Section 1b).

The consistent pattern: **drag is continuous; a modifier decides whether the committed value is snapped, and to what increment.** Default can be either (snap-on with Shift to free, like Axiom; or free with Ctrl to snap, like Blender/Unity).

### 3b. How "glide but settle" is implemented

Two layers, kept separate:

1. **Continuous target** — compute the raw, un-snapped world position from the drag math (Section 2d). This is where the cursor "wants" the object.
2. **Quantized commit** — snap that target to the grid: `snapped = round(raw / step) * step` per axis (different `step` per axis is fine — see LEGO lattice below).

To make the settle feel smooth rather than teleporting between cells, **interpolate the rendered position toward the snapped target** instead of hard-setting it: e.g. `pos += (snappedTarget - pos) * k` each frame (exponential smoothing / lerp), or a short eased tween (ease-out, ~60–120 ms) when the snapped cell changes. The *logical/model* position is always the exact snapped lattice cell; only the *visual* node lerps toward it. This gives the "magnetic glide into the slot" feel without ever leaving the lattice.

### 3c. LEGO lattice specifics

LEGO geometry is **anisotropic**, so use per-axis snap steps:

- **Horizontal (X, Z):** integer **studs**. 1 stud = 8.0 mm = 20 LDU (LDraw units). Snap to whole studs (optionally half-studs for jumper/offset plates).
- **Vertical (Y):** **plate-height** steps, not stud-height. 1 plate = 3.2 mm = 8 LDU; 1 brick = 3 plates = 9.6 mm = 24 LDU. Snap Y to plate increments (8 LDU), so bricks, plates, and tiles all stack legally.

So `stepX = stepZ = 20 LDU` (1 stud), `stepY = 8 LDU` (1 plate). Working in LDU keeps everything integer and avoids float drift.

---

## 4. Customizable axis / gizmo colors

### 4a. How mature tools expose it (precedent: Blender)

Blender lets users recolor the axis gizmo via the **Theme editor**:
`Edit > Preferences > Themes > User Interface > Axis & Gizmo Colors`, with separate swatches for **Axis X / Axis Y / Axis Z**. Changes apply live; themes can be saved as presets and reset to default. This is the model to imitate: a dedicated, named X/Y/Z color trio, with sensible RGB defaults and a one-click reset. (Blender Themes manual; Blender Base Camp guide.)

### 4b. Where to "tuck it away" in a small consumer app

Pattern for a small macOS app:
- Put it behind the standard **Settings… (Cmd-,)** window, under an **"Advanced"** or **"Appearance"** tab, in a collapsed/disclosure section labeled "Gizmo colors" — not on the main canvas. Most users never open it; enthusiasts who care (the user's exact persona) will find it.
- Provide three color wells (`ColorPicker` in SwiftUI) labeled **X / Y / Z**, a **Reset to defaults** button, and persist to `@AppStorage`/`UserDefaults` (or a small `Codable` theme struct). Live-preview the gizmo as colors change.
- Optionally a **colorblind preset** dropdown (see 4d) and a "match these to the build grid" toggle.

### 4c. Sensible RGB defaults

Default to the universal convention so it matches every 3D tool the user knows:
- **X = red** `#E5484D`-ish (a slightly desaturated red reads better on a 3D scene than pure `#FF0000`).
- **Y = green** `#46A758`/`#2EA043`-ish.
- **Z = blue** `#3B82F6`/`#0072B2`-ish.
Pure primaries (`#F00/#0F0/#00F`) are fine and maximally recognizable but can vibrate against a textured LEGO scene; mildly toned versions look more polished while staying unambiguous. Add the **yellow active/hover** color (`#FFD23F`-ish) as a fourth (non-customizable or also customizable) slot.

### 4d. Accessibility / colorblind considerations

Red+green is the **single worst** pairing for the most common CVD (deuteranopia/protanopia ≈ red-green confusion) — and the default gizmo leans exactly on red vs. green. Mitigations (from Tableau, Wong palette, NICHD/IAA guidance):

- Offer a **colorblind-safe preset.** The **Wong palette** is the standard safe set: blue `#0072B2`, orange `#E69F00`, vermillion `#D55E00`, reddish-purple `#CC79A7`, bluish-green `#009E73`. A good CVD-safe axis trio: **X = vermillion/orange `#E69F00`, Y = bluish-green `#009E73`, Z = blue `#0072B2`** (blue always reads as blue under CVD).
- **Don't rely on color alone.** Add redundant cues: tiny axis **labels (X/Y/Z)** at the arrow tips, distinct **tip shapes**, and brightness/position differences. This is the strongest single accessibility win — it makes the gizmo usable even with default RGB.
- Keep **yellow** as the active-highlight (yellow vs. R/G/B stays distinguishable for most CVD types, but pair it with a size/brightness change too).

---

## 5. SceneKit specifics — building a clickable arrow gizmo on macOS

### 5a. Arrow geometry from SCNNodes

Each axis arrow = a parent `SCNNode` containing:
- a **shaft**: `SCNCylinder` (thin radius, length = gizmo length), and
- a **tip**: `SCNCone` (bottomRadius > 0, topRadius = 0) at the shaft end.

Build it along +Y, then rotate the parent to point down +X (red), +Y (green, no rotation), +Z (blue). Add **plane-drag squares** (`SCNPlane`/`SCNBox`) in each axis pair corner and a **center handle** (`SCNSphere` or small box). Give each handle an emissive/constant-lighting material so the colors read as UI, not as lit geometry, and disable depth-write or render on top so the gizmo isn't occluded by the model. Tag each handle with `node.name` (e.g. `"gizmo.axis.x"`, `"gizmo.plane.xz"`, `"gizmo.center"`) so hit-testing can identify it.

### 5b. Picking a handle with hitTest

On `mouseDown`, convert the `NSEvent` location to view coords and call:
`sceneView.hitTest(point, options:)` → `[SCNHitTestResult]`. Each result carries `.node` (and `.worldCoordinates`, `.localCoordinates`, etc.). Read `result.node.name` to know which axis/plane/center was grabbed. Use hit-test options to restrict to the gizmo (e.g. a dedicated category bitmask via `SCNHitTestOption.categoryBitMask`, and `.searchMode`/`.firstFoundOnly`) so you don't pick the brick behind it. (Apple: `hitTest(_:options:)`, `SCNHitTestResult`.)

### 5c. Distinguishing a gizmo-handle drag from a camera-orbit drag

- On `mouseDown`, hit-test **first**. If a gizmo handle is hit → enter **gizmo-drag mode** for the rest of the gesture (record which handle, the start cursor point, the start object position, and the axis depth). **Disable camera control** (`sceneView.allowsCameraControl = false`) while dragging a handle.
- If no handle is hit → let it fall through to **camera orbit** (re-enable `allowsCameraControl`, or run your own orbit camera).
- On `mouseUp`, exit gizmo-drag mode and restore camera control.
This "hit-test gates the gesture" approach is the standard SceneKit pattern (Apple forums; Benjamin Kindle, "Dragging objects in SceneKit and ARKit").

### 5d. NSEvent drag → axis-constrained translation

Two viable approaches:

**(A) Screen-space axis projection (most robust — matches Section 2d):**
1. On drag start, get two world points on the chosen axis (object origin and origin+axisDir).
2. `projectPoint` both → 2D screen line `(a, u)`.
3. Each `mouseDragged`: project the current cursor onto that line (`t = dot(u,p-a)/dot(u,u)`), `unprojectPoint` the result back, intersect with the world axis line → exact world position on the axis. Snap (Section 3) and assign.

**(B) Ray–plane intersection (simple, good enough for single-axis):**
1. On drag start, define a plane containing the axis and most facing the camera (normal = axis × (axis × cameraForward)).
2. Each drag: build a world-space ray from the cursor via `unprojectPoint` (one near point, one far point → ray), intersect with that plane → hit point.
3. Project (hit point − dragStartHit) onto the axis direction → scalar distance; move the object that far along the axis. Snap and assign.

SceneKit gives you the unprojection primitives directly: `renderer.projectPoint(_:)` (3D→2D, with a usable depth/z in the 0..1 range) and `unprojectPoint(_:)` (2D+depth → 3D). For a ray, unproject the cursor at z=0 (near) and z=1 (far) and use the line between them. (Apple: `unprojectPoint`; Benjamin Kindle Medium article describes the `projectPoint` z-capture + `unprojectPoint` delta technique used for object dragging.)

### 5e. Hover highlight in SceneKit

For macOS, track an `NSTrackingArea` and on `mouseMoved` hit-test the gizmo; if a handle is hovered, swap its material color/emission to the **yellow active color** (and optionally scale it up slightly). Restore on exit. During a drag, keep the active axis highlighted yellow. This reproduces the Blender/Unity/Unreal "armed axis turns yellow" affordance.

---

## 6. Recommendations for Brick Bench

Concrete, opinionated, implementable.

### 6a. Gizmo geometry
- Three axis arrows: **`SCNCylinder` shaft + `SCNCone` tip** per axis, built along +Y then oriented to ±X/±Y/±Z. Show only the **positive** half-axes by default (cleaner); optionally show negative on hover.
- Add **three plane-drag squares** (XZ first — that's the build-table plane and the most-used; then XY, YZ) and a **center sphere** for camera-plane free move (mirrors Axiom's center node "constant camera distance" behavior).
- Render handles with **constant/emissive materials**, drawn on top (no depth occlusion), tagged via `node.name` and a dedicated `categoryBitMask` for hit-testing.
- Make the gizmo **screen-space constant size** (scale by distance to camera each frame) so it's always grabbable regardless of zoom.

### 6b. Default RGB colors (match the universe)
- **X = red `#E5484D`, Y = green `#2EA043`, Z = blue `#3B82F6`.** (Toned primaries — recognizable but not vibrating.)
- **Active/hover = yellow `#FFD23F`.**
- Put small **X/Y/Z tip labels** on by default — costs nothing, big accessibility/clarity win, and lets default red/green stay.

### 6c. Hover / active highlight
- `NSTrackingArea` + `mouseMoved` hit-test → hovered handle turns **yellow** and scales ~1.15×.
- During drag, the dragged axis stays yellow; **dim the other two axes** to ~40% opacity so the active axis is unmistakable.

### 6d. Drag → axis-step projection
- Use **approach (A) screen-space axis projection** from Section 2d/5d for single-axis arrows and plane squares; it stays correct at all camera angles (important since LEGO builders orbit constantly).
- Gate the gesture by hit-test (Section 5c): handle hit → `allowsCameraControl = false` + gizmo-drag mode; empty space → orbit. Restore on `mouseUp`.
- Track **deltas** (move by the amount the cursor moved along the axis), not absolute jumps, so the brick never teleports on grab.

### 6e. Snapping to studs + plate levels
- Work internally in **LDU**: `stepX = stepZ = 20 LDU (1 stud)`, `stepY = 8 LDU (1 plate)`. Snap each axis independently: `snapped = round(raw/step)*step`.
- **Default = snapping ON** (LEGO must be legal). Mirror Axiom's modifiers:
  - **Hold Shift = free / no snap** (fine nudging, off-grid placement).
  - **Hold Ctrl/Cmd = coarse snap** (e.g. whole-brick: 24 LDU on Y, or larger stud multiples on XZ) — for fast big moves.
- Offer optional **half-stud (10 LDU)** XZ snapping toggle for jumper/offset builds.

### 6f. Smooth easing on settle
- Keep model position = exact snapped LDU cell. **Lerp the rendered node toward it**: `node.position += (target - node.position) * k` per frame with `k ≈ 0.35` at 60 fps, OR a short ease-out tween (~80–120 ms) fired when the snapped cell changes.
- Optional **subtle scale "pop"** (1.0→1.05→1.0 over ~100 ms) when a brick lands in a new cell, for tactile "click into place" feedback.
- Show a **ghost/hologram preview** at the target cell during drag (Axiom-style), so the destination is visible before release.

### 6g. Tucked-away customizable color setting
- **Location:** `Settings… (Cmd-,)` → **Appearance** tab → disclosure group **"Gizmo colors"** (collapsed by default). Not on the canvas.
- **Controls:** three SwiftUI `ColorPicker` wells labeled **X / Y / Z**, plus an **Active/hover** well; a **preset dropdown** {Classic RGB (default), Colorblind-safe, Custom}; a **Reset to defaults** button; a **"Show X/Y/Z labels"** toggle.
- **Persistence:** a small `Codable` `GizmoTheme { x, y, z, active }` in `UserDefaults`/`@AppStorage`; apply live to handle materials (KVO/Combine on the theme).
- **Defaults:** Classic RGB as in 6b. **Colorblind-safe preset (Wong):** X = vermillion `#D55E00`, Y = bluish-green `#009E73`, Z = blue `#0072B2`, active = orange-yellow `#E69F00`. Keep X/Y/Z labels forced-on in the colorblind preset.
- Live-preview a small gizmo thumbnail in the settings pane as the user edits.

### 6h. Summary of the "feels intuitive and smooth" recipe
RGB arrows for instant axis legibility + center handle for lazy moves + yellow hover/active highlight + dim-the-others on drag + screen-space axis projection so drag tracks the cursor at any angle + continuous glide with magnetic lerp into snapped LDU cells + Shift/Ctrl modifiers for free/coarse + a live ghost preview. That combination is what makes Axiom (and Blender/Unity/Unreal) feel good, and all of it is reproducible in SceneKit.

---

## Sources

- Axiom — Gizmos: https://axiomdocs.moulberry.com/editor/gizmos.html
- Axiom — Move tool: https://axiomdocs.moulberry.com/builder/buildertools/move.html
- Axiom — docs home: https://axiomdocs.moulberry.com/
- Axiom — Selections: https://axiomdocs.moulberry.com/editor/selections.html
- Axiom — site / Modrinth: https://axiom.moulberry.com/ , https://modrinth.com/mod/axiom
- Blender — Viewport Gizmos manual: https://docs.blender.org/manual/en/latest/editors/3dview/display/gizmo.html
- Blender — Snapping manual: https://docs.blender.org/manual/en/latest/editors/3dview/controls/snapping.html
- Blender — Themes manual: https://docs.blender.org/manual/en/latest/editors/preferences/themes.html
- Blender Base Camp — changing color scheme / Axis & Gizmo colors: https://www.blenderbasecamp.com/how-to-change-the-color-scheme-of-the-blender-interface/
- Artisticrender — How to use the gizmo in Blender (arrow vs. plane square): https://artisticrender.com/how-to-use-the-gizmo-in-blender/
- Unity — Transforms manual (RGB axes): https://docs.unity3d.com/550/Documentation/Manual/Transforms.html
- Unity — Grid snapping manual: https://docs.unity3d.com/Manual/GridSnapping.html
- Unity — Move/rotate/scale in increments (hold Ctrl/Cmd): https://docs.unity3d.com/6000.3/Documentation/Manual/SnapIncrements.html
- Unreal Engine — Transforming Actors (color-coded arrows, plane/free handles): https://dev.epicgames.com/documentation/unreal-engine/transforming-actors-in-unreal-engine
- Godot — 3D editor recipes (color-coded arrows): https://kidscancode.org/godot_recipes/4.x/g101/3d/101_3d_01/index.html
- Godot — 3D gizmo plugins docs: https://docs.godotengine.org/en/stable/tutorials/plugins/editor/3d_gizmos.html
- 3ds Max — Using Transform Gizmos (X red / Y green / Z blue): https://knowledge.autodesk.com/support/3ds-max/getting-started/caas/CloudHelp/cloudhelp/2023/ENU/3DSMax-Basics/files/GUID-D97C423B-1AD4-46EA-892B-3A807823892C-htm.html
- ZBrush / Maxon — Gizmo 3D basic operations (red X / green Y / blue Z): https://help.maxon.net/zbr/en-us/Content/html/user-guide/3d-modeling/modeling-basics/gizmo-3d/basic-operations/basic-operations.html
- Edilogues — Translate/Rotate/Scale manipulators in 3D modelling programs: https://ed.ilogues.com/2018/06/27/translate-rotate-and-scale-manipulators-in-3d-modelling-programs
- Our Machinery — "Linear Algebra Shenanigans: Gizmo Repair" (screen-space axis projection math): https://ruby0x1.github.io/machinery_blog_archive/post/linear-algebra-shenanigans-gizmo-repair/index.html
- GameDev.net — translating mouse movement to a gizmo: https://www.gamedev.net/forums/topic/683654-how-to-translate-mouse-movement-to-a-rotation-gizmo/
- Apple — SCNSceneRenderer hitTest(_:options:): https://developer.apple.com/documentation/scenekit/scnscenerenderer/1522929-hittest
- Apple — SCNHitTestResult: https://developer.apple.com/documentation/scenekit/scnhittestresult
- Benjamin Kindle — Dragging objects in SceneKit and ARKit (projectPoint/unprojectPoint, hitTest, delta dragging): https://medium.com/@literalpie/dragging-objects-in-scenekit-and-arkit-3568212a90e5
- objc.io — Scene Kit (hit testing): https://www.objc.io/issues/18-games/scenekit/
- Apple Developer Forums — SwiftUI → SceneKit tap gesture / hit testing: https://developer.apple.com/forums/thread/650627
- Tableau — Don't use red & green together (colorblind viz): https://www.tableau.com/blog/examining-data-viz-rules-dont-use-red-green-together
- David Nichols — Coloring for Colorblindness (Wong palette tool): https://davidmathlogic.com/colorblind/
- NC State IAA — Guide to colorblind-friendly visualizations: https://datacolumn.iaa.ncsu.edu/blog/2022/09/16/a-guide-to-colorblind-friendly-visualizations/
- NICHD — Making scientific figures colorblind accessible (Wong palette hex values): https://science.nichd.nih.gov/confluence/pages/viewpage.action?pageId=147425018
