"""按小星的实际半径检查地图走不走得通：把墙、影藤、玻璃、铁门、栅栏占的像素都算出来，
在 4 px 的网格上做 BFS，每一点离实体墙至少 10 px（小星半径）。

无头测试是瞬移过去的，验证不了"这一段真的走得过去"——比如两头对不齐的走廊、
被柱子夹死的 1 格缝。加新章节后跑一遍：

    python tools/check_maps.py

每张图可以有多"遍"检查：铁门关着时哪些地方进不去、打开之后全通，都可以分开写。
影藤默认当作已经烧掉（烧之前本来就该堵着，那是关卡设计）；要检查"烧之前进不去"，
在 extra 里加上 V。
"""
import sys
from collections import deque

STEP = 4
RADIUS = 10.0
CELL = 32.0
## 永远挡路的东西：墙、边界、玻璃（含斜玻璃）。
SOLID = set("#@-|/\\")


def load(path):
    rows = open(path, encoding="utf-8").read().split("\n")
    return [r for r in rows if r]


def blocked_rects(rows, extra):
    solid = SOLID | set(extra)
    rects = []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in solid:
                rects.append((x * CELL, y * CELL, x * CELL + CELL, y * CELL + CELL))
    return rects


def free(point, rects):
    px, py = point
    for x0, y0, x1, y1 in rects:
        cx = min(max(px, x0), x1)
        cy = min(max(py, y0), y1)
        if (px - cx) ** 2 + (py - cy) ** 2 < RADIUS * RADIUS:
            return False
    return True


def walkable(rows, start_cell, extra=""):
    rects = blocked_rects(rows, extra)
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


def sample(cell):
    return (int(((cell[0] + 0.5) * CELL) // STEP), int(((cell[1] + 0.5) * CELL) // STEP))


## 每张地图查什么。passes 里每一遍有自己的 extra（额外当作实体的字符）和期望。
## wormholes：虫洞两端，一端能走到就算两端连通。
MAPS = [
    {
        "name": "ch0_fall",
        "path": "tools/ch0_map.txt",
        "start": (3, 20),
        "passes": [
            {
                "reach": {"出口": (43, 7), "检查点": (31, 9), "守夜人": (38, 9), "竖井小星星": (4, 14)},
            },
        ],
    },
    {
        "name": "ch1_vine（影藤当作已经烧掉）",
        "path": "tools/ch1_map.txt",
        "start": (3, 22),
        "passes": [
            {
                "reach": {"出口": (63, 20), "园丁的壁龛": (33, 15), "检查点": (44, 20), "玻璃房前": (52, 21)},
                "miss": {"玻璃房里的医生": (53, 15)},
            },
        ],
    },
    {
        "name": "ch2_mirror（虫洞当作连通）",
        "path": "tools/ch2_map.txt",
        "start": (3, 22),
        "wormholes": [((31, 20), (38, 20))],
        "passes": [
            {
                "reach": {"出口": (55, 20), "画家房": (35, 17), "向导": (22, 17), "检查点": (44, 21)},
                "miss": {"画家的竖井": (40, 19)},
            },
        ],
    },
    {
        "name": "ch3_crack",
        "path": "tools/ch3_map.txt",
        "start": (3, 24),
        "passes": [
            {
                "label": "铁门关着、裂纹墙还在",
                "extra": "ICH",
                "reach": {"大厅": (30, 20)},
                "miss": {"邮差": (5, 16), "矿工": (47, 20), "锁匠": (55, 19), "检查点": (45, 21), "出口": (67, 19)},
            },
            {
                "label": "铁门打开、裂纹墙撞碎之后",
                "extra": "H",
                "reach": {"邮差": (5, 16), "矿工": (47, 20), "检查点": (45, 21), "出口": (67, 19), "笼子外面": (51, 19)},
                "miss": {"笼子里的锁匠": (55, 19)},
            },
        ],
    },
    {
        "name": "ch4_pair",
        "path": "tools/ch4_map.txt",
        "start": (3, 22),
        "passes": [
            {
                "label": "铁门关着",
                "extra": "IH",
                "reach": {"出口": (63, 23), "钟表匠": (50, 20), "乐手": (26, 18), "检查点": (42, 20)},
                "miss": {"科学家那间": (63, 20), "笼子里的科学家": (63, 16)},
            },
            {
                "label": "锁匠救过、铁门不在",
                "extra": "H",
                "reach": {"科学家那间": (63, 20), "出口": (63, 23)},
                "miss": {"笼子里的科学家": (63, 16)},
            },
        ],
    },
]


def check(spec, one_pass):
    rows = load(spec["path"])
    extra = one_pass.get("extra", "")
    seen = walkable(rows, spec["start"], extra)
    for a, b in spec.get("wormholes", []):
        if sample(a) in seen or sample(b) in seen:
            seen |= walkable(rows, b, extra) | walkable(rows, a, extra)
    name = spec["name"] + ("：" + one_pass["label"] if one_pass.get("label") else "")
    ok = True
    for label, cell in one_pass.get("reach", {}).items():
        if sample(cell) not in seen:
            print("FAIL", name, "走不到", label, cell)
            ok = False
    for label, cell in one_pass.get("miss", {}).items():
        if sample(cell) in seen:
            print("FAIL", name, "不该走进去却走得进去", label, cell)
            ok = False
    print("PASS" if ok else "FAIL", name)
    return ok


## 回程赛道：从最右边的 Entry 一路往左跑到最左边的 Exit。终章把它们首尾接起来，
## 任何一段跑不过去整条终章就废了。矿工的隧道（T）当成墙和不当成墙各查一遍。
LANES = ["tools/ch0_lane.txt", "tools/ch1_lane.txt", "tools/ch2_lane.txt", "tools/ch3_lane.txt", "tools/ch4_lane.txt", "tools/finale_outro.txt"]


def check_lane(path, extra, label):
    rows = load(path)
    start = (len(rows[0]) - 1, 8)
    # 终章结尾最左边是逃离点（E 占 1–2 列），所以目标取第 1 列
    end = (1, 8)
    seen = walkable(rows, start, extra)
    ok = sample(end) in seen
    if not ok:
        print("FAIL", path, label, "从 Entry 跑不到 Exit")
    print("PASS" if ok else "FAIL", path, label)
    return ok


ok = True
for lane_path in LANES:
    name = lane_path.split("/")[-1]
    # 隧道关着（没救矿工）：得从墙下面绕
    ok = check_lane(lane_path, "T", name + "：隧道关着") and ok
    # 隧道开着
    ok = check_lane(lane_path, "", name + "：隧道开着") and ok
for map_spec in MAPS:
    for one_pass in map_spec["passes"]:
        ok = check(map_spec, one_pass) and ok
sys.exit(0 if ok else 1)
