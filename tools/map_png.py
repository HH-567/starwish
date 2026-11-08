"""把 ASCII 地图画成 PNG，方便一眼看布局（每格 4 像素）。"""
import io
import sys

from PIL import Image, ImageDraw

COLORS = {
    "#": (46, 38, 28),
    "@": (22, 18, 14),
    ".": (16, 20, 34),
    "S": (255, 220, 120),
    "E": (255, 190, 90),
    "K": (210, 150, 90),
    "*": (255, 240, 180),
    "P": (60, 180, 160),
    "C": (150, 110, 60),
    "V": (120, 70, 160),
    "H": (140, 150, 190),
    "I": (120, 110, 90),
    "-": (150, 220, 255),
    "|": (150, 220, 255),
    "/": (150, 220, 255),
    "\\": (150, 220, 255),
    ">": (255, 200, 120),
    "<": (255, 200, 120),
    "^": (255, 200, 120),
    "v": (255, 200, 120),
    "x": (200, 60, 70),
    "A": (200, 140, 255),
    "B": (200, 140, 255),
    "'": (120, 140, 200),
}
NPC_COLOR = (230, 230, 255)

CELL = 4


def render(path: str, out: str) -> None:
    rows = io.open(path, encoding="utf-8").read().split("\n")
    w = max(len(r) for r in rows)
    h = len(rows)
    img = Image.new("RGB", (w * CELL, h * CELL), (8, 8, 12))
    d = ImageDraw.Draw(img)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == " ":
                continue
            color = COLORS.get(ch)
            if color is None:
                color = NPC_COLOR if ch.isalpha() else (90, 90, 120)
            d.rectangle([x * CELL, y * CELL, x * CELL + CELL - 1, y * CELL + CELL - 1], fill=color)
    img.save(out)
    print(out, img.size)


if __name__ == "__main__":
    for name in ("ch0", "ch1", "ch2", "ch3", "ch4"):
        render("tools/%s_map.txt" % name, ".tmp_build/map_%s.png" % name)
