"""程序生成的小精灵图（32 px），替换有问题的那几张美术图。

    .tmp_build/venv/bin/python tools/sprite_art.py

- 影鬼 shade_idle / shade_aim / shade_fire：原来的 shade_aim.png 是一整块不透明的深色方块
  （没去底），影鬼一瞄准就变成一个黑方块。三张统一重画：兜帽状的暗影、紫色描边、
  底部飘散的烟尾；眼睛不画在图里，由 enemy.gd 用自发光画（暗处也看得见那两点红光）。
"""
import numpy as np
from PIL import Image

T = 32
RNG = np.random.default_rng(5)

BODY = np.array([0x17, 0x15, 0x28]) / 255
BODY_HI = np.array([0x2a, 0x24, 0x44]) / 255
RIM = np.array([0x6a, 0x4b, 0x8f]) / 255
RIM_HOT = np.array([0xb0, 0x4a, 0x6a]) / 255


def shade(kind):
    yy, xx = np.mgrid[0:T, 0:T].astype(float) + 0.5
    cx = 16.0
    # 鬼影：圆顶兜帽 + 两侧往下略微张开的长袍 + 波浪状、往下打散的下摆。lean = 身子往哪边歪。
    lean = {"idle": 0.0, "aim": -1.0, "fire": 1.0}[kind]
    dome_cy, dome_r = 11.0, 8.0
    tilt = (dome_cy + 6 - yy) / 16.0 * lean      # 越往上歪得越多
    x = xx - cx - tilt
    dome = (yy <= dome_cy) & (np.hypot(x, yy - dome_cy) < dome_r)
    t = np.clip((yy - dome_cy) / (27.0 - dome_cy), 0, 1)
    half_w = dome_r + 1.5 * t
    hem = 27.0 + 2.2 * np.sin(x * 0.75 + (1.2 if kind == "aim" else 0.0))
    robe = (yy > dome_cy) & (np.abs(x) < half_w) & (yy < hem)
    mask = dome | robe
    # 下摆末端打散：越往下越稀
    frag = RNG.random((T, T)) < np.clip((yy - 25) / 6.0, 0, 1) * 0.55
    mask &= ~frag
    img = np.zeros((T, T, 4))
    img[mask, :3] = BODY
    # 兜帽左上一块体积高光、长袍右侧一道暗褶
    hi = mask & (np.hypot(x + 3, yy - dome_cy + 3) < 3.5)
    img[hi, :3] = BODY_HI
    fold = mask & (np.abs(x - 3.5 - 0.6 * np.sin(yy * 0.5)) < 0.7) & (yy > dome_cy + 4)
    img[fold, :3] = BODY * 0.6
    img[mask, 3] = 1.0
    head_cy = dome_cy
    # 描边：mask 的外侧 1 px
    pad = np.pad(mask, 1)
    neigh = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    edge = neigh & ~mask
    rim = RIM_HOT if kind != "idle" else RIM
    img[edge, :3] = rim
    img[edge, 3] = 0.9
    # 兜帽里的"脸"：一块更深的凹陷，眼睛画在这里（enemy.gd 画）
    face = mask & (np.hypot((x) / 1.4, yy - head_cy - 0.5) < 3.6)
    img[face, :3] = BODY * 0.45
    if kind == "fire":
        # 开火：脸里亮一下
        glow = mask & (np.hypot(x / 1.3, yy - head_cy - 3.5) < 1.6)
        img[glow, :3] = np.array([1.0, 0.45, 0.35])
    return img


def save(img, path):
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA").save(path)
    print(path)


def main():
    for kind in ("idle", "aim", "fire"):
        save(shade(kind), "assets/art/enemies/shade_%s.png" % kind)


if __name__ == "__main__":
    main()
