"""看一眼新一批图的批量体检：尺寸、颜色数（像素感）、半透明比例（有没有抗锯齿）、内容占比，
顺便拼一张联系表。目录可以是任意位置。

    python tools/art_batch_check.py "D:\\art\\batch" --sheet .tmp_build/sheet.png
"""
import argparse
import glob
import os

from PIL import Image, ImageDraw, ImageFont

CELL = 190
PAD = 8
COLS = 7


def metrics(path):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    colors = set()
    semi = opaque = 0
    step = max(1, min(w, h) // 128)
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b, a = px[x, y]
            if a > 0:
                colors.add((r, g, b))
            if 0 < a < 250:
                semi += 1
            if a > 250:
                opaque += 1
    total = max(len(range(0, w, step)) * len(range(0, h, step)), 1)
    box = img.getbbox()
    fill = 0.0
    if box:
        fill = 100.0 * ((box[2] - box[0]) * (box[3] - box[1])) / float(w * h)
    return {
        "size": (w, h), "colors": len(colors), "semi": 100.0 * semi / total,
        "opaque": 100.0 * opaque / total, "fill": fill, "img": img,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--sheet", default="")
    ap.add_argument("--max", type=int, default=0, help="只看前 N 张")
    args = ap.parse_args()

    files = sorted(glob.glob(os.path.join(args.folder, "**", "*.png"), recursive=True))
    files = [f for f in files if not os.path.basename(f).startswith("_")]
    if args.max:
        files = files[: args.max]
    if not files:
        raise SystemExit("这个目录里没有 png：%s" % args.folder)

    print("%-34s %-10s %-7s %-8s %-8s %s" % ("文件", "尺寸", "颜色数", "半透明%", "不透明%", "内容占比"))
    sheets = []
    for path in files:
        m = metrics(path)
        rel = os.path.relpath(path, args.folder).replace("\\", "/")
        flag = ""
        if m["colors"] > 64:
            flag += " ← 颜色多，不像像素"
        if m["semi"] > 15:
            flag += " ← 柔边多"
        print("%-34s %-10s %-7d %-8.1f %-8.1f %.1f%%%s" % (
            rel, "%dx%d" % m["size"], m["colors"], m["semi"], m["opaque"], m["fill"], flag))
        sheets.append((rel, m["img"]))

    if args.sheet:
        rows = (len(sheets) + COLS - 1) // COLS
        sheet = Image.new("RGB", (COLS * (CELL + PAD) + PAD, rows * (CELL + 34) + PAD), (24, 21, 18))
        draw = ImageDraw.Draw(sheet)
        try:
            font = ImageFont.truetype("segoeui.ttf", 12)
        except OSError:
            font = ImageFont.load_default()
        for i, (rel, img) in enumerate(sheets):
            thumb = img.copy()
            thumb.thumbnail((CELL - 14, CELL - 14), Image.NEAREST)
            cx = PAD + (i % COLS) * (CELL + PAD)
            cy = PAD + (i // COLS) * (CELL + 34)
            for yy in range(0, CELL, 14):
                for xx in range(0, CELL, 14):
                    c = (44, 40, 34) if ((xx // 14) + (yy // 14)) % 2 == 0 else (30, 27, 23)
                    draw.rectangle([cx + xx, cy + yy, cx + xx + 13, cy + yy + 13], fill=c)
            sheet.paste(thumb, (cx + (CELL - thumb.width) // 2, cy + (CELL - thumb.height) // 2), thumb)
            draw.text((cx + 2, cy + CELL + 2), rel, fill=(240, 230, 210), font=font)
        os.makedirs(os.path.dirname(os.path.abspath(args.sheet)), exist_ok=True)
        sheet.save(args.sheet)
        print("\n联系表 →", args.sheet)


if __name__ == "__main__":
    main()
