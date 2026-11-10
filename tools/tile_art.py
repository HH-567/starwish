"""程序生成墙和地面的图块图集（32 px 一格），给 tools/build_test_levels.gd 用。

    .tmp_build/venv/bin/python tools/tile_art.py

每张图集 16 列 × 4 行：
- 列 = 四邻掩码 mask（1 上、2 右、4 下、8 左）。
  墙：mask 位 = 这一边挨着空地 → 这一边画一道墙沿高光（构建器同时把这一边的遮光体往里缩，光能照亮墙沿）。
  地面：mask 位 = 这一边挨着墙 → 这一边画一道接触阴影（墙脚的暗边）。
- 行 = 变体，构建器按格子坐标哈希挑一行，避免一整片完全重复。

两套风格：suburb（郊区：粗石块墙 + 不规则石板地）和 city（城市：砖墙 + 方砖人行道）。
颜色整体偏中性、偏暗：关卡里会再乘暗处环境光和每章的色调，被小星照到时才露出本色。
"""
import numpy as np
from PIL import Image

T = 32
COLS = 16
ROWS = 4
RNG = np.random.default_rng(11)

UP, RIGHT, DOWN, LEFT = 1, 2, 4, 8


def noise(h, w, scale=1.0):
    return RNG.normal(0.0, scale, (h, w))


def smooth_noise(h, w, cell=8):
    """低频噪声：粗网格随机值双线性放大，做石面的明暗起伏。"""
    gh, gw = h // cell + 2, w // cell + 2
    g = RNG.uniform(-1, 1, (gh, gw))
    ys = np.linspace(0, gh - 2, h, endpoint=False)
    xs = np.linspace(0, gw - 2, w, endpoint=False)
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def to_img(rgb):
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")


def quantize(rgb, levels=24):
    """压成有限的色阶，像素画的"台阶感"，不糊成照片。"""
    return np.round(rgb * levels) / levels


# ---------------------------------------------------------------- 墙

def wall_base(style, variant):
    """一格墙顶（俯视看到的墙的上表面）。返回 32×32×3。"""
    rng_n = noise(T, T, 1.0)
    if style == "city":
        base = np.array([0.30, 0.20, 0.17])
        mortar = np.array([0.13, 0.10, 0.10])
        img = np.tile(base, (T, T, 1)).astype(float)
        # 砖：8 px 高、16 px 宽，隔行错半块。每块砖自己的明暗不同。
        for row in range(T // 8):
            off = 8 if (row + variant) % 2 else 0
            for col in range(-1, T // 16 + 1):
                x0 = col * 16 + off
                shade = RNG.uniform(-0.05, 0.05) + (0.03 if RNG.random() < 0.15 else 0.0)
                tint = np.array([shade * 1.2, shade, shade * 0.8])
                ys, ye = row * 8, row * 8 + 8
                xs, xe = max(x0, 0), min(x0 + 16, T)
                if xs < xe:
                    img[ys:ye, xs:xe] += tint
                    # 砖的上沿亮一点、下沿暗一点：有一点体积
                    img[ys, xs:xe] += 0.035
                    img[ye - 1, xs:xe] -= 0.03
            img[row * 8 + 7, :] = mortar
            for col in range(-1, T // 16 + 1):
                x = col * 16 + off - 1
                if 0 <= x < T:
                    img[row * 8:row * 8 + 8, x] = mortar
        img += rng_n[..., None] * 0.012
        # 偶尔一块砖缺角/发黑（旧城）
        if variant == 3:
            img[9:15, 18:26] *= 0.75
    else:
        # 郊区：大小不一的粗石块，石缝不规则，带一点青苔绿。
        base = np.array([0.22, 0.24, 0.27])
        img = np.tile(base, (T, T, 1)).astype(float)
        img += smooth_noise(T, T, 6)[..., None] * 0.035
        img += rng_n[..., None] * 0.012
        # 石缝：两条横缝 + 每段一条竖缝，位置按变体变
        seams_y = [(9 + variant * 3) % 14 + 3, (23 + variant * 2) % 10 + 19]
        crack = np.array([0.09, 0.10, 0.12])
        for i, y in enumerate(seams_y):
            img[y, :] = crack
            img[min(y + 1, T - 1), :] *= 0.85
        bands = [0] + seams_y + [T]
        for i in range(len(bands) - 1):
            x = int(RNG.integers(6, 26))
            img[bands[i]:bands[i + 1], x] = crack
        # 每块石头上沿一点高光
        for y in seams_y:
            if y + 2 < T:
                img[y + 2, :] += 0.025
        # 青苔
        moss = smooth_noise(T, T, 5) > 0.55
        img[moss] = img[moss] * 0.75 + np.array([0.12, 0.2, 0.12]) * 0.25
    return img


## 墙顶整体压暗到这个比例：墙必须明显比地面暗，暗处只靠"地面亮、墙黑"看出路在哪；
## 墙沿的高光不压，暗处也隐约勾出墙的轮廓。
WALL_DIM = 0.5


def wall_tile(style, variant, mask, unbreakable):
    img = wall_base(style, variant) * WALL_DIM
    if unbreakable:
        img *= 0.82
    lip = np.array([0.48, 0.44, 0.40]) if style == "city" else np.array([0.42, 0.46, 0.50])
    edge = np.array([0.05, 0.05, 0.07])
    # 墙沿：挨着空地的那一边，外侧 1 px 暗线（墙和地面的分界）+ 里面 2 px 亮沿（墙顶的边被照亮）
    # + 再往里一段渐暗。光照到时这一条最先亮，暗处也隐约看得出墙的轮廓。
    W = 5
    ramp = np.linspace(1.0, 0.0, W)[:, None]
    for bit, sl in ((UP, (slice(0, W), slice(None))),
                    (DOWN, (slice(T - W, T), slice(None))),
                    (LEFT, (slice(None), slice(0, W))),
                    (RIGHT, (slice(None), slice(T - W, T)))):
        if not mask & bit:
            continue
        region = img[sl]
        if bit in (UP, DOWN):
            r = ramp if bit == UP else ramp[::-1]
            region[:] = region * (1 - 0.55 * r[..., None]) + lip * 0.55 * r[..., None]
        else:
            r = ramp.T if bit == LEFT else ramp.T[:, ::-1]
            region[:] = region * (1 - 0.55 * r[..., None]) + lip * 0.55 * r[..., None]
    if mask & UP:
        img[0, :] = edge
    if mask & DOWN:
        img[T - 1, :] = edge
    if mask & LEFT:
        img[:, 0] = edge
    if mask & RIGHT:
        img[:, T - 1] = edge
    return quantize(img, 32)


# ---------------------------------------------------------------- 地面

def floor_base(style, variant):
    n = noise(T, T, 1.0)
    if style == "city":
        # 方砖人行道：16 px 一块，细灰缝，每块砖明暗略不同。
        base = np.array([0.34, 0.32, 0.30])
        img = np.tile(base, (T, T, 1)).astype(float)
        for by in range(2):
            for bx in range(2):
                img[by * 16:(by + 1) * 16, bx * 16:(bx + 1) * 16] += RNG.uniform(-0.025, 0.025)
        grout = base * 0.72
        img[15, :] = grout
        img[31, :] = grout
        img[:, 15] = grout
        img[:, 31] = grout
        img[0, :] += 0.02
        img[16, :] += 0.02
        img += n[..., None] * 0.012
        if variant == 2:
            # 一块砖上有道细裂纹
            for i in range(9):
                img[3 + i, 20 + (i // 2)] *= 0.8
        if variant == 3:
            # 井盖般的一个小圆点
            yy, xx = np.mgrid[0:T, 0:T]
            d = np.hypot(yy - 24, xx - 8)
            img[(d > 3) & (d < 4.2)] *= 0.8
    else:
        # 郊区：不规则石板 + 泥土缝，石板之间偶尔有草。
        base = np.array([0.31, 0.32, 0.31])
        img = np.tile(base, (T, T, 1)).astype(float)
        img += smooth_noise(T, T, 8)[..., None] * 0.04
        img += n[..., None] * 0.013
        # Voronoi 石板：几个种子点，按最近种子分块，块边界画成泥缝
        pts = RNG.uniform(0, T, (5, 2))
        yy, xx = np.mgrid[0:T, 0:T].astype(float)
        # 环绕距离，左右/上下拼起来不露缝
        d = []
        for p in pts:
            dy = np.abs(yy - p[0]); dy = np.minimum(dy, T - dy)
            dx = np.abs(xx - p[1]); dx = np.minimum(dx, T - dx)
            d.append(np.hypot(dy, dx))
        d = np.sort(np.stack(d), axis=0)
        border = (d[1] - d[0]) < 1.1
        # 泥缝只比石板暗一点：太黑的话一整片地面像碎玻璃，抢了墙的轮廓。
        img[border] = img[border] * 0.72 + np.array([0.20, 0.18, 0.14]) * 0.28
        own = np.argmin(np.stack([np.hypot(np.minimum(np.abs(yy - p[0]), T - np.abs(yy - p[0])),
                                           np.minimum(np.abs(xx - p[1]), T - np.abs(xx - p[1]))) for p in pts]), axis=0)
        for k in range(len(pts)):
            img[(own == k) & ~border] += RNG.uniform(-0.03, 0.03)
        if variant in (1, 3):
            grass = border & (smooth_noise(T, T, 6) > 0.45)
            img[grass] = img[grass] * 0.5 + np.array([0.18, 0.26, 0.16]) * 0.5
    return img


def floor_tile(style, variant, mask):
    img = floor_base(style, variant)
    # 墙脚的接触阴影：挨着墙的那一边 6 px 渐暗，墙看起来"立"在地上。
    W = 7
    shade = np.ones((T, T))
    ramp = np.linspace(0.55, 1.0, W)
    if mask & UP:
        shade[:W, :] = np.minimum(shade[:W, :], ramp[:, None])
    if mask & DOWN:
        shade[T - W:, :] = np.minimum(shade[T - W:, :], ramp[::-1][:, None])
    if mask & LEFT:
        shade[:, :W] = np.minimum(shade[:, :W], ramp[None, :])
    if mask & RIGHT:
        shade[:, T - W:] = np.minimum(shade[:, T - W:], ramp[::-1][None, :])
    return quantize(img * shade[..., None], 32)


# ---------------------------------------------------------------- 输出

def atlas(fn):
    out = np.zeros((ROWS * T, COLS * T, 3))
    for v in range(ROWS):
        for m in range(COLS):
            out[v * T:(v + 1) * T, m * T:(m + 1) * T] = fn(v, m)
    return out


def main():
    for style in ("suburb", "city"):
        # 同一行（同一变体）的 16 个掩码共用一张底图，只是墙沿/阴影不同：
        # 相邻格子掩码不同但变体相同时花纹仍然一致，不会一格一个样。
        for kind in ("wall", "edge", "floor"):
            rows = []
            for v in range(ROWS):
                state = RNG.bit_generator.state
                row = []
                for m in range(COLS):
                    RNG.bit_generator.state = state
                    if kind == "floor":
                        row.append(floor_tile(style, v, m))
                    else:
                        row.append(wall_tile(style, v, m, kind == "edge"))
                rows.append(np.concatenate(row, axis=1))
            img = np.concatenate(rows, axis=0)
            name = {"wall": "walls", "edge": "walls_unbreakable", "floor": "floors"}[kind]
            path = "assets/art/level/%s_%s.png" % (name, style)
            to_img(img).save(path)
            print(path, img.shape[1], "x", img.shape[0])


if __name__ == "__main__":
    main()
