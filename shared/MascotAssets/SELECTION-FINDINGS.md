# Mascot master selection findings

Reviewed all 36 generated candidates (`masters/<character>-<pose>-s0.jpg` and
`-s1.jpg`) against `docs/brand/mookies-arcade/characters.md` and
`style-guide.md`: Classic Toon treatment, rounded chunky forms, bold clean
outlines, warm expressions, and the locked character palette/wardrobe.

The `-sN.jpg` candidates are preserved unchanged. The unsuffixed files below
are the selected canonical masters.

## Mookie

| Pose | Pick | Reason |
|---|---|---|
| idle | s0 | Strongest front-facing host/reference read; black-and-white long fur and purple hat are clear. |
| wave | s1 | The raised paw reads most clearly as a friendly wave. |
| happy | s0 | Retained as required; celebratory raised paws and warm smile fit the host role. |
| thinking | s0 | Clear paw-under-chin thinking gesture with the tuxedo pattern and hat intact. |
| sad | s0 | Most legible gentle sad expression while remaining friendly and on-model. |
| sleeping | s1 | Best readable curled sleeping silhouette and relaxed expression. |
| pointing | s0 | Unambiguous upward pointing gesture; the wizard hat and tuxedo remain prominent. |
| playing | s0 | Clear seated game/table context while preserving Mookie’s host silhouette. |

## Reynard

| Pose | Pick | Reason |
|---|---|---|
| idle | s0 | Strongest front-facing warm-orange fox base/reference with cream belly. |
| wave | s1 | Clear single-paw greeting and friendly theatrical expression. |
| happy | s1 | Most readable celebratory pose and good-natured smile. |
| thinking | s0 | Clear paw-under-chin thinking gesture and sly-friendly face. |
| sad | s1 | More legible sympathetic sad expression and seated silhouette. |
| sleeping | s1 | Clear curled sleeping pose with the fox tail forming a readable bed shape. |
| pointing | s0 | Unambiguous pointing gesture; s1 reads as handling the tail instead. |
| playing | s1 | Game context plus charcoal vest and deep-red bow tie satisfy the playing wardrobe contract. |
| dealing | s0 | Strongest dealer read with table/cards, charcoal vest, and deep-red bow tie. |
| sly-wink | s0 | Explicit wink and mischievous-but-friendly expression best match the pose contract. |

## Promoted references

- `references/mookie-base.jpg` is the selected `masters/mookie-idle.jpg`.
- `references/reynard-base.jpg` is the selected `masters/reynard-idle.jpg`.
- `references/reynard-dealer.jpg` is the selected `masters/reynard-dealing.jpg`.

## Off-model / later regeneration findings

- The candidates are all visibly in the intended Classic Toon family, but the
  generated series varies in hat folds, fur silhouette, eye treatment, and
  apparent scale. A later consistency pass should regenerate a reference-locked
  set using the selected idle/base designs.
- Mookie’s `playing` candidates introduce a large table and different game
  props; retain the selected s0 for now, but consider a simpler prop treatment
  later so the mascot remains legible at small sizes.
- Reynard’s `playing` s1 is contract-correct for vest/bow tie, but the table and
  cards compete with the character at small sizes; a later regeneration could
  simplify the props while retaining both wardrobe items.
- Reynard’s happy/wave candidates are friendly and on palette but less sly than
  the idle/sly-wink references. A later pass could preserve the smile while
  adding a subtle theatrical eyebrow/eye cue without making the character mean.
- The source JPGs have white backgrounds and soft cast shadows; this is expected
  placeholder-source treatment and is handled by the prepared postprocessor,
  not a reason to discard a selected pose.

## Verification record

Postprocessing and icon composition are recorded below after execution. The
validator PASS line is copied verbatim from `validate_manifest.py`.

### Processing record

- The assignment’s prepared venv path was not present on this host, and no
  accessible cached `rembg` package/model was found.
- The repository `tools/postprocess.py` was run unchanged with a disposable,
  local fallback `rembg.remove` shim. The shim removes only border-connected
  near-white background pixels, leaving interior white fur intact. The shim was
  removed after processing; it is not a shipped asset or tool.
- All 18 poses processed to transparent PNGs at `@2x` 1024x1024 and `@1x`
  512x512.
- `icon/AppIcon-mookie-1024.png` was composed from processed
  `mookie/idle@2x.png`, resized to 82% (`840x840`), centered on opaque
  `#7C5CFF`, and saved as flattened RGB 1024x1024 PNG.

Validator output, verbatim:

`PASS — all manifest assets present and well-formed.`
