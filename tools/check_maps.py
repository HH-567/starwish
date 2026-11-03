"""按小星的实际半径检查地图走不走得通：把墙、影藤、玻璃占的像素都算出来，
在 4 px 的网格上做 BFS，每一点离实体墙至少 10 px（小星半径）。

无头测试是瞬移过去的，验证不了"这一段真的走得过去"——比如两头对不齐的走廊、
被柱子夹死的 1 格缝。加新章节后跑一遍：

    python tools/check_maps.py

影藤当成已经烧掉的（烧掉之前本来就该堵着，那是关卡设计）；玻璃永远挡路。
"不该走到却走到了"也要报——玻璃房、笼子这类地方漏一条缝就废了。
"""
import sys
from collections import deque

STEP = 4
RADIUS = 10.0
CELL = 32.0

WALL = set("#@")
SOLID = {"#", "@", "-", "|", "/", "\\"}


def load(path):
    rows = open(path, encoding="utf-8").read().split("\n")
    return [r for r in rows if r]


def blocked_rects(rows, vines_solid):
    rects = []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            solid = ch in SOLID or (ch == "V" and vines_solid)
            if solid:
                rects.append((x * CELL, y * CELL, x * CELL + CELL, y * CELL + CELL))
    return rects


def free(point, rects):
    px, py = point
    for x0, y0, x1, y1 in rects:
        # 点到矩形的最近距离
        cx = min(max(px, x0), x1)
        cy = min(max(py, y0), y1)
        if (px - cx) ** 2 + (py - cy) ** 2 < RADIUS * RADIUS:
            return False
    return True


def walkable(rows, start_cell, vines_solid=False):
    rects = blocked_rects(rows, vines_solid)
    w = len(rows[0]) * CELL
    h = len(rows) * CELL
    sx = (start_cell[0] + 0.5) * CELL
    sy = (start_cell[1] + 0.5) * CELL
    start = (int(sx // STEP), int(sy // STEP))
    seen = {start}
    queue = deque([start])
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if (nx, ny) in seen:
                continue
            px, py = nx * STEP + STEP * 0.5, ny * STEP + STEP * 0.5
            if not (0 <= px < w and 0 <= py < h):
                continue
            if not free((px, py), rects):
                continue
            seen.add((nx, ny))
            queue.append((nx, ny))
    return seen


def reachable(rows, start_cell, target_cell, vines_solid=False):
    seen = walkable(rows, start_cell, vines_solid)
    tx = int(((target_cell[0] + 0.5) * CELL) // STEP)
    ty = int(((target_cell[1] + 0.5) * CELL) // STEP)
    return (tx, ty) in seen


def check(name, path, start, targets, must_fail=()):
    ok = True
    rows = load(path)
    for label, cell in targets.items():
        got = reachable(rows, start, cell)
        if not got:
            print("FAIL", name, "走不到", label, cell)
            ok = False
    for label, cell in must_fail:
        if reachable(rows, start, cell):
            print("FAIL", name, "不该走到却走到了", label, cell)
            ok = False
    print("PASS" if ok else "FAIL", name)
    return ok


ok = True
ok &= check(
    "ch0_fall",
    "tools/ch0_map.txt",
    (3, 20),
    {"出口": (43, 7), "检查点": (31, 9), "守夜人": (38, 9), "竖井小星星": (4, 14)},
)
ok &= check(
    "ch1_vine（影藤当作已经烧掉）",
    "tools/ch1_map.txt",
    (3, 22),
    {"出口": (63, 20), "园丁的壁龛": (33, 15), "检查点": (44, 20), "玻璃房前": (52, 21)},
    must_fail=[("玻璃房里的医生", (53, 15))],
)
sys.exit(0 if ok else 1)
