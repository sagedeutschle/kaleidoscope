#!/usr/bin/env python3
"""Generate master mascot art via pollinations. Best-of-2 seeds per pose for human pick."""
import urllib.parse, subprocess, sys
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "masters"; OUT.mkdir(exist_ok=True)
STYLE = ("classic Saturday morning cartoon style, bold thick outlines, exaggerated "
         "expressive face, rounded chunky shapes, vibrant flat colors, mascot, full body, "
         "centered, plain white background")
MOOKIE = "a fluffy long-haired tuxedo cat (black and white fur) wearing a purple wizard hat"
REYNARD = "a cute but sly red fox with warm orange fur and a fluffy tail"

POSE_DESC = {
  "idle": "standing calmly, gentle friendly smile",
  "wave": "waving hello with one paw, welcoming",
  "happy": "cheering, arms up, big joyful celebration",
  "thinking": "one paw on chin, curious thoughtful look",
  "sad": "slightly sad disappointed 'oops' expression, ears down",
  "sleeping": "curled up asleep, eyes closed, tiny zzz",
  "pointing": "pointing to the side with one paw, presenting",
  "playing": "sitting at a small table playing a card/board game, focused and happy",
  "dealing": "dealing playing cards across a table, showman flourish",   # reynard
  "sly-wink": "winking slyly with a mischievous knowing grin",           # reynard
}

CHARS = {"mookie": (MOOKIE, POSE_DESC.keys() - {"dealing","sly-wink"}),
         "reynard": (REYNARD, POSE_DESC.keys())}

def gen(name, prompt, seed, out):
    url = (f"https://image.pollinations.ai/prompt/{urllib.parse.quote(prompt, safe='')}"
           f"?width=1024&height=1024&nologo=true&model=flux&seed={seed}")
    print("gen", out.name, flush=True)
    subprocess.run(["curl","-sS","-o",str(out),"--max-time","110",url], check=False)

for char,(base,poses) in CHARS.items():
    outfit = ", wearing a charcoal vest and deep red bow tie" if char=="reynard" else ""
    for pose in sorted(poses):
        prompt = f"{base}{outfit if pose in ('dealing','playing') else ''}, {POSE_DESC[pose]}, {STYLE}"
        for i, seed in enumerate((11, 23)):  # best-of-2
            gen(f"{char}-{pose}", prompt, seed, OUT / f"{char}-{pose}-s{i}.jpg")
print("done")
