# Mascot assets (Mookie's Arcade)

Placeholder art generated via `tools/generate_mascots.py` (pollinations) →
`tools/postprocess.py` (transparent, normalized). Keys live in `manifest.json`
and are mirrored by `MascotAsset.swift`.

## Swapping in final (e.g. commissioned) art later
Replace the PNGs under `mookie/` and `reynard/` (and `icon/`) keeping the SAME filenames
(`<pose>@1x.png` 512², `<pose>@2x.png` 1024², transparent). Run `validate_manifest.py`.
No code changes needed — consumers reference manifest keys, never filenames.

## Regenerating a single pose
Edit the seed list in `tools/generate_mascots.py`, re-run for that pose, pick the winner,
re-run `tools/postprocess.py`.

## Validate
`python3 validate_manifest.py`  → must print PASS.
