"""关卡体检：每章画一张带主路线的俯视图，并打印几项数字，方便改地图前后对比。

    .tmp_build/venv/bin/python tools/level_report.py            # 全部五章
    .tmp_build/venv/bin/python tools/level_report.py ch1        # 只看一章

图输出到 .tmp_build/report_<章>.png（每格 6 px）：
  黑 = 墙，深蓝 = 空地，黄线 = 出生点到出口的最短路（裂纹墙、影藤当作能过），
  白点 = 小人，红 = 影鬼，金 = 小星星，青 = 软垫，紫 = 影藤，褐 = 裂纹墙，浅蓝 = 镜子/玻璃。
数字：
  路线长度（格）、路线上的直道（能加速到阶段 3 的连续直线 ≥ 9 格的段数）、
  每个小人离路线多远、路线两侧 6 格内的小星星数（补给密度）、离路线最远的空地。
"""
import sys
from collections import deque

from PIL import Image, ImageDraw

CELL = 6
WALL = set("#@T")
# 当成能走的实体（要么能撞开，要么只是摆设）
SOFT = set("CVK'*E")
BLOCK = set("-|/\\HIP")
NPC = set("nwgdaGmLMpqcZD")
COLORS = {
    "#": (14, 14, 18), "@": (6, 6, 8), "T": (40, 30, 20),
    ".": (28, 34, 58), "*": (255, 210, 90), "'": (110, 130, 190), "K": (230, 160, 90),
    "E": (255, 240, 160), "S": (255, 255, 255), "x": (230, 60, 60), "P": (60, 180, 160),
    "V": (150, 80, 200), "C": (150, 110, 60), "H": (150, 160, 200), "I": (120, 100, 80),
    "-": (150, 220, 255), "|": (150, 220, 255), "/": (150, 220, 255), "\\": (150, 220, 255),
    "+": (255, 90, 60), "=": (180, 120, 255), "A": (200, 140, 255), "B": (200, 140, 255),
}


def load(name):
    rows = open("tools/%s_map.txt" % name, encoding="utf-8").read().strip("\n").split("\n")
    w = max(len(r) for r in rows)
    return [r.ljust(w, "#") for r in rows]


def find(rows, chars):
    return [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c in chars]


def passable(c):
    return c not in WALL and c not in BLOCK


def bfs(rows, start, worm=None):
    h, w = len(rows), len(rows[0])
    dist = {start: 0}
    prev = {}
    q = deque([start])
    while q:
        c = q.popleft()
        nbs = [(c[0] + 1, c[1]), (c[0] - 1, c[1]), (c[0], c[1] + 1), (c[0], c[1] - 1)]
        if worm and c in worm:
            nbs.append(worm[c])
        for n in nbs:
            if 0 <= n[0] < w and 0 <= n[1] < h and n not in dist and passable(rows[n[1]][n[0]]):
                dist[n] = dist[c] + 1
                prev[n] = c
                q.append(n)
    return dist, prev


def path_to(prev, start, goal):
    p = [goal]
    while p[-1] != start:
        p.append(prev[p[-1]])
    return p[::-1]


def straights(path, min_len=9):
    """路线上方向不变的连续段，长度 ≥ min_len 格的个数和最长的一段。"""
    runs, cur, best = 0, 1, 1
    for i in range(2, len(path)):
        d1 = (path[i - 1][0] - path[i - 2][0], path[i - 1][1] - path[i - 2][1])
        d2 = (path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1])
        if d1 == d2:
            cur += 1
        else:
            if cur >= min_len:
                runs += 1
            best = max(best, cur)
            cur = 1
    if cur >= min_len:
        runs += 1
    return runs, max(best, cur)


def report(name):
    rows = load(name)
    start = find(rows, "S")[0]
    exits = find(rows, "E")
    worm = None
    ab = find(rows, "A") + find(rows, "B")
    if len(ab) == 2:
        worm = {ab[0]: ab[1], ab[1]: ab[0]}
    dist, prev = bfs(rows, start, worm)
    reach = [e for e in exits if e in dist]
    print("== %s  %d×%d" % (name, len(rows[0]), len(rows)))
    if not reach:
        print("  出口走不到！")
        return
    goal = min(reach, key=lambda e: dist[e])
    path = path_to(prev, start, goal)
    on_path = set(path)
    # 每个格子离路线多远（多源 BFS）
    h, w = len(rows), len(rows[0])
    far = {c: 0 for c in path}
    q = deque(path)
    while q:
        c = q.popleft()
        for n in ((c[0] + 1, c[1]), (c[0] - 1, c[1]), (c[0], c[1] + 1), (c[0], c[1] - 1)):
            if 0 <= n[0] < w and 0 <= n[1] < h and n not in far and passable(rows[n[1]][n[0]]):
                far[n] = far[c] + 1
                q.append(n)
    runs, best = straights(path)
    print("  路线 %d 格（%.0f px），能冲到阶段 3 的直道（≥9 格）%d 段，最长直线 %d 格" % (len(path), len(path) * 32, runs, best))
    for (x, y) in find(rows, NPC):
        print("  小人 %s @(%d,%d) 离路线 %s 格" % (rows[y][x], x, y, far.get((x, y), "走不到")))
    shards = find(rows, "*")
    near = [s for s in shards if far.get(s, 99) <= 6]
    print("  小星星 %d 颗，路线 6 格内 %d 颗（每 %.0f 格路线一颗）" % (len(shards), len(near), len(path) / max(len(near), 1)))
    enemies = find(rows, "x")
    print("  影鬼 %d 只，离路线：%s" % (len(enemies), [far.get(e, "×") for e in enemies]))
    worst = max(far.items(), key=lambda kv: kv[1])
    print("  离路线最远的空地 @%s：%d 格" % (worst[0], worst[1]))
    unreachable = [c for c in find(rows, ".*'") if c not in dist]
    if unreachable:
        print("  走不到的空地 %d 格（不算栅栏/玻璃后面要靠光的地方）" % len(unreachable))
    img = Image.new("RGB", (w * CELL, h * CELL), (0, 0, 0))
    d = ImageDraw.Draw(img)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            col = COLORS.get(c, (240, 240, 255) if c in NPC else (28, 34, 58))
            d.rectangle([x * CELL, y * CELL, x * CELL + CELL - 1, y * CELL + CELL - 1], fill=col)
    pts = [(x * CELL + CELL // 2, y * CELL + CELL // 2) for x, y in path]
    d.line(pts, fill=(255, 220, 60), width=2)
    img.save(".tmp_build/report_%s.png" % name)


if __name__ == "__main__":
    for n in sys.argv[1:] or ["ch0", "ch1", "ch2", "ch3", "ch4"]:
        report(n)
