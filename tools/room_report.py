"""找出"离主路线很远、里面又没东西"的空地——按用途表这就是意义不明的部分。

主路线 = 出生点到出口的最短路。距离 = 每个可走格子到这条路的格数。
"""
import glob
import io
from collections import deque

WALL = {"#", "@"}
MARK_START = "S"
MARK_EXIT = "E"
CONTENT = set("*KECHVIP-|/\\<>^vxAB'") | set("gwdapqmcZLGM")


def load(path):
    rows = io.open(path, encoding="utf-8").read().split("\n")
    w = max(len(r) for r in rows)
    return [r.ljust(w) for r in rows], w, len(rows)


def find(grid, ch):
    for y, row in enumerate(grid):
        x = row.find(ch)
        if x >= 0:
            return x, y
    return None


def bfs(grid, w, h, start):
    dist = {start: 0}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and grid[ny][nx] not in WALL and (nx, ny) not in dist:
                dist[(nx, ny)] = dist[(x, y)] + 1
                q.append((nx, ny))
    return dist


def analyse(path):
    grid, w, h = load(path)
    s = find(grid, MARK_START)
    e = find(grid, MARK_EXIT)
    if s is None or e is None:
        return path, None
    dist = bfs(grid, w, h, e)
    # 沿距离下降的方向从出生点走到出口 = 最短路
    route = set()
    cur = s
    route.add(cur)
    guard = 0
    while cur != e and guard < 5000:
        guard += 1
        x, y = cur
        best = None
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in dist and dist[(nx, ny)] < dist[cur]:
                if best is None or dist[(nx, ny)] < dist[best]:
                    best = (nx, ny)
        if best is None:
            break
        cur = best
        route.add(cur)
    # 每个可走格子到主路线的距离：从路线上的格子往外做多源 BFS
    away = {}
    q = deque()
    for cell in route:
        away[cell] = 0
        q.append(cell)
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and grid[ny][nx] not in WALL and (nx, ny) not in away:
                away[(nx, ny)] = away[(x, y)] + 1
                q.append((nx, ny))
    return path, (grid, w, h, away, route)


def pockets(grid, w, h, away, threshold=2):
    """离路线 ≥threshold 的空地，按连通块分组。"""
    seen = set()
    out = []
    for (x, y), d in away.items():
        if d < threshold or (x, y) in seen:
            continue
        cells = []
        stack = [(x, y)]
        seen.add((x, y))
        while stack:
            cx, cy = stack.pop()
            cells.append((cx, cy))
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = cx + dx, cy + dy
                if (nx, ny) in away and (nx, ny) not in seen and away[(nx, ny)] >= threshold:
                    seen.add((nx, ny))
                    stack.append((nx, ny))
        if len(cells) >= 4:
            out.append(cells)
    return out


for path in sorted(glob.glob("tools/ch*_map.txt")):
    p, data = analyse(path)
    if data is None:
        print(p, "找不到出生点或出口")
        continue
    grid, w, h, away, route = data
    ps = pockets(grid, w, h, away)
    print("=" * 72)
    print("%s  主路线 %d 格，偏离区域 %d 块" % (p, len(route), len(ps)))
    for cells in sorted(ps, key=len, reverse=True)[:10]:
        content = {}
        for (x, y) in cells:
            ch = grid[y][x]
            if ch in CONTENT:
                content[ch] = content.get(ch, 0) + 1
        xs = [c[0] for c in cells]
        ys = [c[1] for c in cells]
        tag = "  ".join("%s×%d" % kv for kv in content.items()) or "空"
        print("   盒(%-4d,%-3d)-(%-4d,%-3d) %3d格  %s" % (min(xs), min(ys), max(xs), max(ys), len(cells), tag))
