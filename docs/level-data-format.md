# 关卡与数据格式

v1 · 2026-10-29。表里的数值都是初值，原型跑起来后再调。状态和规则见 [状态机](state-machines.md)。

## 0. 已确认的决定

- 截止 2026-11-11，单人开发；首通目标 10–15 分钟（暂定）。
- 光常亮，两种模式切换：左键/空格 = 散射，右键/Shift = 聚光；触屏点按切换。
- 阶段 2 撞墙扣一大块亮度，亮度不够才碎裂。
- 虫洞可以保持速度方向，也可以把方向改成出口朝向。
- 回程赛道藏在各章场景里（关卡区上方或下方），终章把各章赛道首尾相接拼成一条路。

## 1. 文件布局

沿用现有的 `scenes/` + `scripts/` 分法：

```text
data/tuning.tres               全部数值（Tuning 资源）
data/tiles.tres                TileSet：32px，物理层 0 = 黑墙，遮光层 0
scenes/levels/ch0_fall.tscn    序章；ch1_vine / ch2_mirror / ch3_crack / ch4_pair 同理
scenes/levels/finale.tscn      终章
scenes/entities/*.tscn         小星、小人、墙、道具、噬光者
scenes/ui/                     HUD、触屏控件、标题、结局
scripts/autoload/game.gd       流程状态机 + 全局信号
scripts/autoload/save.gd       存档与进度
scripts/data/tuning.gd         Tuning 资源类
scripts/entities/、scripts/levels/
```

章节顺序写在 `game.gd` 的常量里：`CHAPTERS = [["ch0", "res://scenes/levels/ch0_fall.tscn"], ...]`。

## 2. 章节场景

```text
Chapter (Node2D, chapter.gd)     export chapter_id: StringName
├─ Level                         平时玩的关卡区
│  ├─ Walls (TileMapLayer)       黑墙
│  ├─ Entities                   小人、裂纹墙、玻璃、软垫、虫洞、灯泡、小星星…，可再分组
│  ├─ Checkpoints                1–2 个检查点
│  ├─ PlayerStart (Marker2D)
│  └─ Exit
└─ ChaseLane                     回程赛道，放在 Level 外的上方或下方
   ├─ Walls (TileMapLayer)
   ├─ Entities                   加速带、可撞碎的杂物
   ├─ Entry (Marker2D)           进入点，也是终章的检查点
   └─ Exit (Marker2D)            离开点
```

- 场景实例化后、加入场景树前调用 `chapter.prepare(mode)`，删掉用不到的子树：普通模式删 ChaseLane，终章模式删 Level。没进树的节点不参与物理和渲染，平时完全碰不到赛道。
- 普通模式的镜头范围 = `Level/Walls.get_used_rect()`。
- 赛道约定：从右往左跑（回程）。Entry 在最右、Exit 在最左且同高，赛道全部内容的 x 坐标都在两者之间，这样拼起来各段不会重叠。
- 每段赛道的 Entry 后面放一条不关联小人的常亮加速带，保证只救了必救者也能跑完。
- 赛道里的加速带用 NodePath 指向 Level 里的小人。`prepare(FINALE)` 删掉 Level 之前，先把它解析成那个小人的 save_id。

## 3. 实体

五种小人里只有"想结伴"需要专门的逻辑。被困、阴影缠、玻璃拐角都是"怕黑"小人加上摆放：被裂纹墙围住、被影藤围住、放在只有反射光能照到的拐角。

| 实体 | 关键参数 | 持久化 | 优先级 |
|---|---|---|---|
| Player 小星 | — | — | P0 |
| Npc 小人 | kind（只影响外观和音效）、required（必救）、need_time（0 = 用默认值）、partner（结伴对象）、grants_speed（被救时解锁到第几档，0 = 不解锁）、key（隐藏结局关键人） | 已救 | P0；结伴 P1 |
| CrackedWall 裂纹墙 | size、hinted（隐藏结局要撞碎的墙） | 已碎 | P0 |
| ShadowVine 影藤 | size | 已烧 | P0 |
| Mirror 玻璃 | length，可旋转 | — | P1（ch2 依赖） |
| Pad 软垫 | size，可旋转 | — | P0 |
| Wormhole 虫洞 | 子节点 A、B；two_way；keep_direction | — | P1 |
| AccelStrip 加速带 | target_speed（赛道里一般 920）；npc（空 = 常亮）；朝向 = 节点旋转 | — | P0 |
| Bulb 灯泡 | radius、rate：待在范围内持续回亮度，可反复用 | — | P0 |
| StarShard 小星星 | amount：碰到时一次性回亮度 | 不存，复活后重生 | P0 |
| Checkpoint 检查点 | — | 当前检查点 | P0 |
| Exit 出口 | 本章 required 小人全部救出后打开 | — | P0 |
| Meteor 流星 | interval、warn_time、radius | — | P2 |
| BlackHole 黑洞 | radius、strength | — | P2 |
| Boss 噬光者 | 只在终章出现 | — | P0 |

## 4. 物理层与光线

| 位 | 名称 | 内容 |
|---|---|---|
| 1 | world | 黑墙（TileMapLayer） |
| 2 | cracked | 裂纹墙 |
| 3 | mirror | 玻璃 |
| 4 | pad | 软垫 |
| 5 | vine | 影藤 |
| 6 | player | 小星 |
| 7 | trigger | 小人、道具、检查点、虫洞等 Area2D |
| 8 | boss | 噬光者 |

- 视线射线的 mask 是 1–5，所有墙都挡光。聚光打到玻璃反射一次；散射打到玻璃就停。
- 1–5 层的东西都带 LightOccluder2D（图块用 TileSet 遮光层），画面上的阴影和判定一致。

## 5. 存档

save_id = `<chapter_id>/<从章节根到该节点的路径>`，例如 `ch1/Level/Entities/Npc2`。顺着父节点拼出来，不依赖场景树。节点改名或移动会改变 id，发布后就别动了。

`user://save.json`（Web 上由 Godot 存进浏览器的 IndexedDB）：

```json
{
  "version": 1,
  "chapter": "ch2",
  "checkpoint": "ch2/Level/Checkpoints/CP1",
  "speed_unlocked": 3,
  "rescued": ["ch0/Level/Entities/Npc1"],
  "broken": ["ch3/Level/Entities/Crack2"],
  "burnt": ["ch1/Level/Entities/Vine1"],
  "hints": {"ch3": [2, 2], "ch4": [0, 1]},
  "endings": {"main": false, "hidden": false}
}
```

- `checkpoint` 为空表示 PlayerStart。`hints` 记本章 [已撞碎, 总数]，章节通关时写入。
- 写盘时机：到达检查点、救人、通关、看完结局。
- 亮度上限不存，现算：`light_base + light_per_rescue × 已救人数`，不超过 `light_cap`。
- 4.3 不支持类型化 Dictionary。内存里的集合用 `Dictionary`（id → true）。
- 死亡或按 R：重新加载章节场景。各实体在 `_ready` 里查存档，直接切到最终状态（已救、已碎、已烧），不播特效。小星出现在检查点，亮度回满。小星星随重载重生。
- version 对不上就清档。

## 6. 进度

- `speed_unlocked` 初始为 2。小人被救时，`grants_speed` 比它大就提上去。终章固定为 5。
- 速度解锁放在必救小人身上，并且在下一章用到之前拿到，避免卡关。
- 隐藏结局 = key 小人已救 + 所有 hinted 裂纹墙已碎。阶段 4 在 ch2 结尾才解锁，又没有回头路，所以 hinted 墙只能放在 ch3、ch4。

## 7. 章节初版

| id | 名称 | 教什么 | 小人（必救/全部） | 解锁 |
|---|---|---|---|---|
| ch0 | 序章·坠落 | 移动、散射、阶段 2 撞墙的代价 | 怕黑 1/2 | — |
| ch1 | 影藤·聚光 | 切换聚光、烧影藤、灯泡 | 怕黑 + 阴影缠 2/3 | 最后一个必救者给阶段 3 |
| ch2 | 镜角·反射 | 阶段 3 反弹、玻璃反射、虫洞 | 玻璃拐角 + 怕黑 2/3 | 最后一个必救者给阶段 4 |
| ch3 | 裂纹·被困 | 软垫、加速带、阶段 4 破墙 | 被困 2/3，另有 key 小人 | — |
| ch4 | 结伴·微光 | 双人同时亮、流星、黑洞（P2） | 结伴 2 对/3 对 | — |
| fin | 终章·长夜追逐 | 阶段 5、保住速度、躲墙 | — | 阶段 5 |

共 18 人，必救 11 人；每章 1.5–2.5 分钟。

## 8. 数值表（data/tuning.tres）

| 组 | 字段 | 初值 | 说明 |
|---|---|---|---|
| 移动 | accel | 420 | px/s²，WASD 加速度 |
| | coast_decel | 90 | 松手时的减速 |
| | brake_mult | 3.5 | 输入和速度反向时，加速度乘这个数 |
| | graze_ratio | 0.35 | 法向速度 ÷ 速率低于它算擦墙 |
| 速度 | stage_min | [0, 220, 380, 560, 760] | 阶段 1–5 的下限，px/s |
| | hysteresis | 20 | 降档回差 |
| | max_speed | 980 | 阶段 5 封顶 |
| | input_max_stage | 4 | WASD 最多推到这一档的顶 |
| | overspeed_decay | 50 | 超过 WASD 上限后每秒回落 |
| | trail_colors | 白、红、橙、蓝、紫 | |
| 碰撞 | s1_wall_loss | 0.15 | 阶段 1 撞墙的减速比例 |
| | s2_damage | 20 | 阶段 2 撞墙扣的亮度 |
| | s2_exit_speed | 150 | 阶段 2 撞墙后速度压到这里（阶段 1） |
| | hurt_iframes | 0.6 | 受伤后无敌秒数 |
| | bounce_restitution | 0.85 | 反弹后保留的速度比例 |
| | bounce_grace | 0.5 | 反弹后保护秒数 |
| | break_speed_loss | 0.10 | 撞碎裂纹墙的减速比例 |
| | smash_speed_loss | 0.12 | 阶段 5 撞碎其他墙的减速比例 |
| | smash_radius | 1 | 阶段 5 撞黑墙时擦掉的格子半径 |
| 光 | light_base / light_per_rescue / light_cap | 60 / 5 / 140 | |
| | decay / focus_decay_mult | 1.0 / 1.5 | 每秒衰减；聚光时乘倍率 |
| | scatter_radius_min / max | 90 / 220 | 按 当前亮度 ÷ light_cap 插值 |
| | focus_range_mult / focus_half_angle | 2.2 / 16° | 聚光距离 = 散射半径 × 倍率 |
| | shard_amount / bulb_rate | 15 / 12 | 小星星一次回多少；灯泡每秒回多少 |
| | low_light_ratio | 0.25 | 亮度低于上限的这个比例开始心跳 |
| 小人 | wake_time / pair_time / vine_burn_time | 2.0 / 1.5 / 1.5 | 秒 |
| | progress_decay | 2.0 | 没照到时进度回落的倍率 |
| 虫洞 | warp_cooldown | 0.3 | 秒 |
| 追逐 | boss_speed | 790 | 比 WASD 能到的最快（759）快，比赛道加速带（约 920）慢：只有靠加速带才能拉开 |
| | boss_gap_start / boss_gap_max | 500 / 900 | 沿轨迹的距离；超过 max 时噬光者提速跟上 |
| | boss_drain | 80 | 接触时每秒吸走的亮度 |
| | chase_respawn_speed | 600 | 追逐中复活时的初速（阶段 4） |

## 9. 输入映射

| 动作 | 键鼠 | 触屏 |
|---|---|---|
| move_up / down / left / right | WASD、方向键 | 左虚拟摇杆 |
| light_scatter | 左键、空格 | 切换按钮（点按在两种模式间切换） |
| light_focus | 右键、Shift | 同上 |
| 瞄准 | 鼠标位置 | 右摇杆；没推时朝移动方向 |
| reset | R | 暂停菜单里 |
| pause | Esc | 角落按钮 |

调试版（`OS.is_debug_build()`）另加 F1–F6 直接跳章。
