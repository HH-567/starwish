#!/usr/bin/env python3
"""从白底四格漫画里量出四个画面的多边形，输出可以贴进 ending_comic.gd 的 GDScript。

做法：按"三通道都很亮 = 白"分出画面；从每一格中间往外长（只在画面像素里长，白缝挡住），
长满这一格以后取凸包，去掉几乎共线的点。坐标是 0..1 的比例，按阅读顺序排
（上排左、上排右、下排左、下排右）。顺便量一下相邻两格之间的白缝有多宽，
用来确认涂白时多边形往外放大几像素是安全的。

换图以后重跑：
    python tools/comic_panels.py            # 打印 const PANELS
    python tools/comic_panels.py --preview  # 顺便把"只露前 k 格"的样子画到 .tmp_build/
然后把打印出来的 PANELS 整段替换掉 scripts/ui/ending_comic.gd 里同名的那段。
"""
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = "assets/art/cg"
PAGES = ["1.png", "2.png", "3.png"]
WHITE_LEVEL = 238          # 三通道都超过它算白（页面留白、格间空缝）
MIN_AREA = 60000           # 小块噪声不要


def _hull(points):
    pts = sorted(set(points))

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def _simplify(poly, eps):
    poly = list(poly)
    changed = True
    while changed and len(poly) > 4:
        changed = False
        for i in range(len(poly)):
            a, b, c = poly[i - 1], poly[i], poly[(i + 1) % len(poly)]
            ax, ay = b[0] - a[0], b[1] - a[1]
            bx, by = c[0] - a[0], c[1] - a[1]
            area = abs(ax * by - ay * bx)
            base = (ax * ax + ay * ay) ** 0.5
            if base > 1e-9 and area / base < eps:
                del poly[i]
                changed = True
                break
    return poly


def _grow(region, opaque, steps=400):
    """从 region 出发，往相邻的画面像素里长，白缝会把它挡住。"""
    for _ in range(steps):
        nxt = region.copy()
        nxt[1:, :] |= region[:-1, :]
        nxt[:-1, :] |= region[1:, :]
        nxt[:, 1:] |= region[:, :-1]
        nxt[:, :-1] |= region[:, 1:]
        nxt &= opaque
        if np.array_equal(nxt, region):
            break
        region = nxt
    return region


def measure(path):
    """返回四块画面的多边形（0..1 比例，阅读顺序）、原图和相邻格间的最小白缝。"""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    a = np.asarray(im).astype(int)
    opaque = a.min(axis=2) < WHITE_LEVEL

    # 先在 1/8 分辨率上把四块分开（快），再回到原分辨率用"只在画面像素里长大"补到精确边界。
    step = 8
    small = np.asarray(im.resize((w // step, h // step), Image.NEAREST)).astype(int)
    sw_opaque = small.min(axis=2) < WHITE_LEVEL
    sh, sw = sw_opaque.shape
    seen = np.zeros_like(sw_opaque, dtype=bool)
    coarse = []
    for y in range(sh):
        for x in range(sw):
            if not sw_opaque[y, x] or seen[y, x]:
                continue
            stack = [(y, x)]
            seen[y, x] = True
            mask = np.zeros_like(sw_opaque)
            n = 0
            while stack:
                cy, cx = stack.pop()
                mask[cy, cx] = True
                n += 1
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < sh and 0 <= nx < sw and sw_opaque[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if n * step * step >= MIN_AREA:
                coarse.append(mask)

    regions = []
    for mask in coarse:
        coarse_full = np.asarray(
            Image.fromarray(mask.astype(np.uint8) * 255).resize((w, h), Image.NEAREST)) > 127
        seed = coarse_full & opaque
        if seed.sum() < MIN_AREA:
            continue
        region = _grow(seed, opaque, steps=80)
        if region.sum() < MIN_AREA:
            continue
        ys, xs = np.nonzero(region)
        hull = _simplify(_hull(list(zip(xs.tolist(), ys.tolist()))), 2.0)
        cx = float(xs.mean()) / w
        cy = float(ys.mean()) / h
        regions.append((cy >= 0.5, cx, [(x / w, y / h) for x, y in hull], region))

    regions.sort(key=lambda t: (t[0], t[1]))
    # 相邻格之间最窄的白缝：把一格的像素往外膨胀，几像素以后碰到另一格
    gap = 99
    for i in range(len(regions)):
        for j in range(i + 1, len(regions)):
            a_reg = regions[i][3]
            b_reg = regions[j][3]
            g = 0
            cur = a_reg.copy()
            while g < 40:
                cur = cur.copy()
                cur[1:, :] |= cur[:-1, :]
                cur[:-1, :] |= cur[1:, :]
                cur[:, 1:] |= cur[:, :-1]
                cur[:, :-1] |= cur[:, 1:]
                g += 1
                if (cur & b_reg).any():
                    break
            gap = min(gap, g)
    return im, [r[2] for r in regions], gap


def gdscript(pages):
    lines = ["const PANELS := ["]
    for polys in pages:
        lines.append("\t[")
        for poly in polys:
            pts = ", ".join("Vector2(%.4f, %.4f)" % (x, y) for x, y in poly)
            lines.append("\t\t[%s]," % pts)
        lines.append("\t],")
    lines.append("]")
    return "\n".join(lines)


def preview(pages, images):
    for i, (im, polys) in enumerate(zip(images, pages)):
        w, h = im.size
        for k in (1, 2, 3):
            out = im.copy()
            d = ImageDraw.Draw(out)
            for poly in polys[k:]:
                pts = [(x * w, y * h) for x, y in poly]
                cx = sum(p[0] for p in pts) / len(pts)
                cy = sum(p[1] for p in pts) / len(pts)
                d.polygon([(cx + (x - cx) * 1.012, cy + (y - cy) * 1.012) for x, y in pts],
                          fill=(255, 255, 255))
            out.resize((680, 383), Image.LANCZOS).save(
                ".tmp_build/shots/comic_%d_show%d.png" % (i + 1, k))
        print("preview: .tmp_build/shots/comic_%d_show*.png" % (i + 1), file=sys.stderr)


def main():
    images, pages = [], []
    for name in PAGES:
        im, polys, gap = measure("%s/%s" % (ROOT, name))
        images.append(im)
        pages.append(polys)
        print("# %s: %d 格 %s，格间最窄白缝 %d px（原图）" % (name, len(polys), [len(p) for p in polys], gap),
              file=sys.stderr)
    if "--preview" in sys.argv:
        preview(pages, images)
    print(gdscript(pages))


if __name__ == "__main__":
    main()
