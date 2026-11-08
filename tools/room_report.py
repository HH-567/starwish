"""找"房间"（而不是走廊）：某个可走格子的 3×3 邻域几乎全空，就算"宽"。
把宽格子连成片 = 房间，再数里面有什么。"""
import glob
import io

WALL = {"#", "@"}
CONTENT = set("*KECHVIP-|/\\<>^vxAB'") | set("gwdapqmcZLGM")


def load(path):
    rows = io.open(path, encoding="utf-8").read().split("\n")
    w = max(len(r) for r in rows)
    return [r.ljust(w) for r in rows], w, len(rows)


def wide(grid, w, h):
    out = set()
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if grid[y][x] in WALL:
                continue
            open_count = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if grid[y + dy][x + dx] not in WALL:
                        open_count += 1
            if open_count >= 8:
                out.add((x, y))
    return out


for path in sorted(glob.glob("tools/ch*_map.txt")):
    grid, w, h = load(path)
    ws = wide(grid, w, h)
    seen = set()
    rooms = []
    for cell in ws:
        if cell in seen:
            continue
        cells = []
        stack = [cell]
        seen.add(cell)
        while stack:
            cx, cy = stack.pop()
            cells.append((cx, cy))
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb = (cx + dx, cy + dy)
                if nb in ws and nb not in seen:
                    seen.add(nb)
                    stack.append(nb)
        rooms.append(cells)
    print("=" * 72)
    print(path, "房间", len(rooms), "个")
    for cells in sorted(rooms, key=len, reverse=True):
        content = {}
        for (x, y) in cells:
            ch = grid[y][x]
            if ch in CONTENT:
                content[ch] = content.get(ch, 0) + 1
        xs = [c[0] for c in cells]
        ys = [c[1] for c in cells]
        tag = " ".join("%s×%d" % kv for kv in content.items()) or "空"
        print("  盒(%-4d,%-3d)-(%-4d,%-3d) %3d 宽格  %s" % (
            min(xs), min(ys), max(xs), max(ys), len(cells), tag))
