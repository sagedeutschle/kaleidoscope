#!/usr/bin/env python3
"""Generate framed App Store screenshots from simulator captures."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


CANVAS = (1320, 2868)
BRAND = "KALEIDESCOPE"


@dataclass(frozen=True)
class Shot:
    output: str
    source: str
    title: str
    subtitle: str
    accent: str


SHOTS = [
    Shot(
        "01_home.png",
        "shot_home.png",
        "20+ classics, one lens",
        "Puzzles, cards, board games, daily play, and live-data tools in one calm app.",
        "#f2c76f",
    ),
    Shot(
        "02_wordgame.png",
        "shot_wordle.png",
        "Daily Wordgame",
        "Approved-word guesses, a clean side letter shelf, and a fresh challenge every day.",
        "#93d36f",
    ),
    Shot(
        "03_chess.png",
        "shot_chess2d.png",
        "Chess with study-table polish",
        "Play the built-in engine, tune difficulty, and switch board styles.",
        "#b8d884",
    ),
    Shot(
        "04_seabattle.png",
        "shot_seabattle.png",
        "Sea Battle, ready to share",
        "Deploy your fleet, play solo, pass-and-play, or challenge a friend online.",
        "#4fb7ff",
    ),
    Shot(
        "05_2048.png",
        "shot_2048.png",
        "2048 that feels alive",
        "Swipe, shuffle, and chase your best score with smooth touch-first controls.",
        "#d39a52",
    ),
    Shot(
        "06_solitaire.png",
        "shot_solitaire.png",
        "Solitaire and Spider",
        "Classic cards on rich tables, plus more quick games for every mood.",
        "#4eb66b",
    ),
    Shot(
        "07_sudoku.png",
        "shot_sudoku.png",
        "Daily puzzle staples",
        "Sudoku, Minesweeper, Nonogram, Snake, Rubik's Cube, and more.",
        "#e18e8e",
    ),
]


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


TITLE_FONT = font("/System/Library/Fonts/Supplemental/Georgia Bold.ttf", 64)
TITLE_FONT_SMALL = font("/System/Library/Fonts/Supplemental/Georgia Bold.ttf", 56)
BODY_FONT = font("/System/Library/Fonts/HelveticaNeue.ttc", 28)
TAG_FONT = font("/System/Library/Fonts/HelveticaNeue.ttc", 20)
FOOTER_FONT = font("/System/Library/Fonts/HelveticaNeue.ttc", 18)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius, fill=255)
    return mask


def text_width(draw: ImageDraw.ImageDraw, text: str, font_obj: ImageFont.FreeTypeFont) -> int:
    left, _, right, _ = draw.textbbox((0, 0), text, font=font_obj)
    return right - left


def wrapped_lines(
    draw: ImageDraw.ImageDraw,
    text: str,
    font_obj: ImageFont.FreeTypeFont,
    max_width: int,
) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current: list[str] = []
    for word in words:
        trial = " ".join([*current, word])
        if current and text_width(draw, trial, font_obj) > max_width:
            lines.append(" ".join(current))
            current = [word]
        else:
            current.append(word)
    if current:
        lines.append(" ".join(current))
    return lines


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def add_vertical_gradient(image: Image.Image) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    pixels = overlay.load()
    width, height = image.size
    for y in range(height):
        top_alpha = max(0, int(170 * (1 - y / 980)))
        bottom_alpha = max(0, int(130 * ((y - 1920) / 948)))
        alpha = max(top_alpha, bottom_alpha)
        for x in range(width):
            pixels[x, y] = (4, 6, 12, min(210, alpha))
    return Image.alpha_composite(image, overlay)


def draw_text_block(draw: ImageDraw.ImageDraw, shot: Shot) -> None:
    margin = 96
    tag_padding_x = 20
    tag_padding_y = 9
    tag_box = draw.textbbox((0, 0), BRAND, font=TAG_FONT)
    tag_w = tag_box[2] - tag_box[0] + tag_padding_x * 2
    tag_h = tag_box[3] - tag_box[1] + tag_padding_y * 2
    tag_rect = (margin, 112, margin + tag_w, 112 + tag_h)
    draw.rounded_rectangle(tag_rect, radius=tag_h // 2, fill=(255, 255, 255, 18), outline=shot.accent, width=2)
    draw.text((margin + tag_padding_x, 112 + tag_padding_y - 2), BRAND, font=TAG_FONT, fill=shot.accent)

    max_width = CANVAS[0] - margin * 2
    title_font = TITLE_FONT
    title_lines = wrapped_lines(draw, shot.title, title_font, max_width)
    if len(title_lines) > 2:
        title_font = TITLE_FONT_SMALL
        title_lines = wrapped_lines(draw, shot.title, title_font, max_width)

    y = 202
    for line in title_lines:
        draw.text((margin, y), line, font=title_font, fill="#f8f0dd")
        y += 76 if title_font == TITLE_FONT else 66

    y += 8
    for line in wrapped_lines(draw, shot.subtitle, BODY_FONT, max_width):
        draw.text((margin, y), line, font=BODY_FONT, fill="#ded3be")
        y += 36


def draw_footer(draw: ImageDraw.ImageDraw) -> None:
    footer = "Free to play | No account required | Built for iPhone"
    width = text_width(draw, footer, FOOTER_FONT)
    draw.text(((CANVAS[0] - width) / 2, CANVAS[1] - 116), footer, font=FOOTER_FONT, fill="#d7cab4")


def render_shot(source_dir: Path, output_dir: Path, shot: Shot) -> None:
    raw = Image.open(source_dir / shot.source).convert("RGBA")
    canvas = cover(raw, CANVAS).filter(ImageFilter.GaussianBlur(38))
    canvas = Image.blend(canvas, Image.new("RGBA", CANVAS, "#05070f"), 0.68)
    canvas = add_vertical_gradient(canvas)

    draw = ImageDraw.Draw(canvas)
    draw_text_block(draw, shot)

    phone_w = 950
    phone_h = round(phone_w * raw.height / raw.width)
    phone = raw.resize((phone_w, phone_h), Image.LANCZOS)
    x = (CANVAS[0] - phone_w) // 2
    y = 550
    mask = rounded_mask(phone.size, 34)

    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    for inset, alpha in [(0, 58), (14, 36), (30, 18)]:
        shadow_draw.rounded_rectangle(
            (x - 22 - inset, y - 22 - inset, x + phone_w + 22 + inset, y + phone_h + 22 + inset),
            radius=54 + inset,
            fill=(0, 0, 0, alpha),
        )
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.paste(phone, (x, y), mask)

    frame_draw = ImageDraw.Draw(canvas)
    frame_draw.rounded_rectangle(
        (x - 4, y - 4, x + phone_w + 4, y + phone_h + 4),
        radius=40,
        outline=(255, 255, 255, 52),
        width=3,
    )
    frame_draw.rounded_rectangle(
        (x - 16, y - 16, x + phone_w + 16, y + phone_h + 16),
        radius=54,
        outline=shot.accent,
        width=2,
    )
    draw_footer(frame_draw)

    output_dir.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output_dir / shot.output, optimize=True, compress_level=9)


def main() -> None:
    ios_dir = Path(__file__).resolve().parents[1]
    source_dir = ios_dir / "docs" / "appstore-screenshots-v14"
    output_dir = source_dir / "final"
    for shot in SHOTS:
        render_shot(source_dir, output_dir, shot)
        print(output_dir / shot.output)


if __name__ == "__main__":
    main()
