"""把美术源图变成游戏能用的 PNG：抠背景、裁边、缩到目标尺寸。

用法：
    python tools/art_import.py 源图.png 名字 --mode black --size 32
    python tools/art_import.py 源图.png characters/npc_watchman --mode green --size 24
    （名字带目录就存到 assets/art/<目录>/名字.png，不带就是 assets/art/名字.png）

两种背景：
    black  发光类：纯黑底，亮度当透明度。星、光晕、弹幕、传送门、Boss、特效。
    green  实心类：纯绿底（#00FF00），抠绿并去掉绿色溢色。小人、墙、门、机关。
"""
import argparse
import os

from PIL import Image

ART_ROOT = os.path.join("assets", "art")
MAX_PAD = 2


def key_black(img: Image.Image) -> Image.Image:
    """黑底 → 亮度当 alpha。"""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            a = max(r, g, b)
            if a < 8:
                px[x, y] = (0, 0, 0, 0)
            else:
                # 去掉黑底带出来的灰边：按最亮通道归一
                scale = 255.0 / a
                px[x, y] = (min(int(r * scale), 255), min(int(g * scale), 255), min(int(b * scale), 255), a)
    return img


def key_green(img: Image.Image) -> Image.Image:
    """纯绿底 → 抠掉绿色并压掉绿边。"""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            other = max(r, b)
            greenness = g - other
            if greenness <= 12:
                alpha = 255
            elif greenness >= 90:
                alpha = 0
            else:
                alpha = int(255 * (1.0 - (greenness - 12) / 78.0))
            if alpha == 0:
                px[x, y] = (0, 0, 0, 0)
                continue
            # 去溢色：绿通道压到不超过其它通道
            px[x, y] = (r, min(g, other), b, alpha)
    return img


def key_magenta(img: Image.Image) -> Image.Image:
    """纯品红底（#FF00FF）→ 抠掉并去品红溢色。比绿底更适合暖色/蓝色系的图。"""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            # 品红度：红蓝都高、绿最低
            magentaness = min(r, b) - g
            if magentaness <= 12:
                alpha = 255
            elif magentaness >= 80:
                alpha = 0
            else:
                alpha = int(255 * (1.0 - (magentaness - 12) / 68.0))
            if alpha == 0:
                px[x, y] = (0, 0, 0, 0)
                continue
            px[x, y] = (min(r, max(g, 0) + 24), g, min(b, max(g, 0) + 24), alpha)
    return img


def trim(img: Image.Image, pad: int = MAX_PAD) -> Image.Image:
    box = img.getbbox()
    if box is None:
        return img
    x0, y0, x1, y1 = box
    x0, y0 = max(x0 - pad, 0), max(y0 - pad, 0)
    x1, y1 = min(x1 + pad, img.width), min(y1 + pad, img.height)
    return img.crop((x0, y0, x1, y1))


def fit(img: Image.Image, size: int, pixel: bool) -> Image.Image:
    """等比缩到最长边 = size，再放到 size×size 的正中间（游戏里按中心对齐）。"""
    w, h = img.size
    scale = size / float(max(w, h))
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    resample = Image.NEAREST if pixel else Image.LANCZOS
    img = img.resize((nw, nh), resample)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - nw) // 2, (size - nh) // 2), img)
    return canvas


def add_rim(img: Image.Image, color: tuple, width: int = 1) -> Image.Image:
    """给剪影描一圈暖色边：暗背景上也能看见人形（这是 docs 里要求的 1px 暖金描边）。
    做法是把 alpha 往外扩 width 像素当描边，再把原图盖回去。"""
    from PIL import ImageFilter

    alpha = img.split()[3]
    grown = alpha.filter(ImageFilter.MaxFilter(width * 2 + 1))
    rim = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rim.putalpha(grown)
    rim.paste(Image.new("RGBA", img.size, (color[0], color[1], color[2], 255)), (0, 0), grown)
    rim.alpha_composite(img)
    return rim


def main() -> None:
    ap = argparse.ArgumentParser(description="美术图后处理：抠背景、裁边、缩尺寸")
    ap.add_argument("source")
    ap.add_argument("name", help="目标名，可带子目录，如 characters/npc_watchman")
    ap.add_argument("--mode", choices=["black", "green", "magenta"], required=True)
    ap.add_argument("--size", type=int, default=0, help="最长边缩到多少 px；0 = 不缩")
    ap.add_argument("--pixel", action="store_true", help="用最近邻缩放（像素风）")
    ap.add_argument("--rim", default="", help="给剪影描一圈边，色值如 ffB454")
    ap.add_argument("--no-trim", action="store_true")
    ap.add_argument("--out", default=ART_ROOT)
    args = ap.parse_args()

    img = Image.open(args.source)
    if args.mode == "black":
        img = key_black(img)
    elif args.mode == "green":
        img = key_green(img)
    else:
        img = key_magenta(img)
    if not args.no_trim:
        img = trim(img)
    if args.size > 0:
        img = fit(img, args.size, args.pixel)
    if args.rim:
        hexv = args.rim.lstrip("#")
        color = (int(hexv[0:2], 16), int(hexv[2:4], 16), int(hexv[4:6], 16))
        img = add_rim(img, color)

    path = os.path.join(args.out, args.name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("%s  →  %s  (%dx%d, mode=%s)" % (args.source, path, img.width, img.height, args.mode))


if __name__ == "__main__":
    main()
