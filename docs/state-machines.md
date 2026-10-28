# 状态机

v1 · 2026-10-29。字段名对应 `data/tuning.tres`，见 [关卡与数据格式](level-data-format.md)。

写法：每个状态机就是 `enum State` + `var state` + `_set_state()`（进入、退出动作写在这里）+ `_physics_process` 里的 `match state`，不引入状态机框架。系统之间只通过 `Game` 上的信号通信。

## 1. 游戏流程（Game autoload）

| 当前 | 事件 | 下一个 | 动作 |
|---|---|---|---|
| BOOT | 读完存档 | TITLE | |
| TITLE | 新游戏 / 继续 | LOADING | 新游戏先清档 |
| LOADING | 场景就绪 | PLAYING；终章为 CHASE | `prepare(mode)`，放小星，淡入 |
| PLAYING / CHASE | Esc | PAUSED | `get_tree().paused = true` |
| PAUSED | Esc / 继续 | 回到原状态 | |
| PAUSED | 回标题 | TITLE | |
| PLAYING / CHASE | `player_died` 或按 R | RESPAWN | 淡出 |
| RESPAWN | 淡出完成 | LOADING | 同一章，从检查点开始 |
| PLAYING | 进入已打开的出口 | CLEAR | 写 hints，清空 checkpoint，存档 |
| CLEAR | 演出结束 | LOADING | 下一章；ch4 之后进终章 |
| CHASE | 到达逃离点 | ENDING | 主线结局 |
| CHASE | 噬光者被撞碎 | ENDING | 隐藏结局 |
| ENDING | 演出结束 | TITLE | 记录 endings，存档 |

## 2. 小星（Player）

### 2.1 生命状态

| 状态 | 进入条件 | 行为 | 离开 |
|---|---|---|---|
| SPAWN | 场景加载完 | 0.5 秒淡入，不能动，无敌 | → ACTIVE |
| ACTIVE | | 正常移动、发光、碰撞 | 见其他行 |
| WARP | 进入虫洞 | 约 0.15 秒隐身、无敌，然后从出口出来 | → ACTIVE |
| LOCKED | 噬光者登场、结局演出 | 不接受输入 | → ACTIVE |
| DYING | 亮度归零（熄灭）；阶段 2 撞墙时亮度不够（碎裂）；被噬光者吸干 | 1 秒死亡动画 | 发 `player_died` |

### 2.2 速度阶段

- 当前阶段 = 满足 `速率 ≥ stage_min[i]` 的最高一档。降档要低于 `stage_min[i] − hysteresis`，避免在边界来回跳。
- 一档的"顶" = 下一档的 `stage_min − 1`；阶段 5 的顶是 `max_speed`。
- 封顶：普通章是 `speed_unlocked` 那一档的顶，终章是 `max_speed`。
- WASD 最多把速率推到 `min(封顶, input_max_stage 的顶)`。更快只能靠加速带、虫洞、黑洞，超出部分按 `overspeed_decay` 回落。所以阶段 5 要靠救人点亮的加速带维持。
- 松手按 `coast_decel` 减速。输入方向和速度方向夹角大于 90° 时，加速度乘 `brake_mult`，相当于刹车。
- 档位变化时发 `speed_stage_changed`。进入阶段 2 时预警：红拖尾 + 星体裂纹闪烁 + 警示音。

### 2.3 撞墙

每次 `move_and_collide` 撞到东西：

1. `vn = −velocity · normal`。如果 `vn ÷ 速率 < graze_ratio`，算擦墙：去掉法向分量，贴墙滑走，不再往下判断。
2. 否则按当前阶段和墙的类型查表：

| | 阶段 1 | 阶段 2 | 阶段 3 | 阶段 4 | 阶段 5 |
|---|---|---|---|---|---|
| 黑墙、玻璃、影藤 | 滑行，减速 s1_wall_loss | 扣 s2_damage，弹开并把速度压到 s2_exit_speed，进入无敌；亮度不够 → 碎裂 | 反弹 | 反弹 | 撞碎，减速 smash_speed_loss |
| 裂纹墙 | 同上 | 同上 | 反弹 | 撞碎，减速 break_speed_loss | 撞碎，减速 break_speed_loss |
| 软垫 | 急停，速度归零 | 急停 | 急停 | 急停 | 撞碎，减速 smash_speed_loss |

- 反弹：速度沿法线镜像，乘 `bounce_restitution`，开 `bounce_grace` 保护。保护期内的阶段 2 撞击也按反弹处理。
- 受伤无敌期（`hurt_iframes`）内的阶段 2 撞击按阶段 1 处理。
- 阶段 5 只在终章出现。撞黑墙时用 `TileMapLayer.get_coords_for_body_rid()` 找到格子，擦掉 `smash_radius` 内的格子。
- 噬光者不按墙处理，见第 12 节。

### 2.4 光

- 模式 SCATTER ⇄ FOCUS，默认 SCATTER。左键/空格切到 SCATTER，右键/Shift 切到 FOCUS，触屏点按切换。
- 亮度每秒减 `decay`，聚光时乘 `focus_decay_mult`；归零进入 DYING。
- 每个物理帧，对 `light_receiver` 组里的目标检查距离、角度和视线，照到就调用它的 `receive_light(mode, delta)`：
  - SCATTER：`scatter_radius` 以内。
  - FOCUS：锥形，半角 `focus_half_angle`，距离 = 散射半径 × `focus_range_mult`。中心射线先打到玻璃时，从击中点沿反射方向再算一个锥形，距离用剩下的，只反射一次。聚光时光环只用来显示亮度，不照亮目标。
- 视线射线的 mask 是物理层 1–5。目标是影藤时，射线第一下打中的就是它，算照到。

## 3. 小人（Npc）

| 状态 | 行为 | 转移 |
|---|---|---|
| CRYING | 播哭声和声波圈 | 被照到 → WAKING |
| WAKING | 照到时 progress += delta；没照到时 progress −= delta × progress_decay | progress ≤ 0 → CRYING；progress ≥ need_time → RESCUED |
| RESCUED | 变成一个小光源，持久保存 | — |

- 进入 RESCUED 时：发 `npc_rescued`，存档，亮度上限 +`light_per_rescue` 并回满；`grants_speed` 大于 `speed_unlocked` 时提上去。
- 结伴：两人同时被照到时进度才涨，任意一人没照到就回落；满 `pair_time` 时两人一起 RESCUED。`partner` 只需在其中一人身上设置。

## 4. 影藤（ShadowVine）

INTACT →（被聚光照到）BURNING →（累计 ≥ `vine_burn_time`）BURNT。

- BURNING 时没照到就回落，回到 0 变回 INTACT。
- BURNT：移除碰撞和遮光，写进存档 `burnt`，发 `vine_burnt`。
- 散射照到影藤没有效果，只是被挡住。

## 5. 裂纹墙（CrackedWall）

INTACT →（阶段 4 以上撞上）BROKEN：播碎片，移除碰撞和遮光，写进 `broken`，发 `wall_broken(id, hinted)`。

## 6. 检查点（Checkpoint）

INACTIVE →（小星进入）ACTIVE：写存档 `checkpoint`，只记最新的一个。

## 7. 出口（Exit）

LOCKED →（本章 required 小人全部已救）OPEN →（小星进入）发 `chapter_cleared`。LOCKED 时是暗的，能穿过但不触发。

## 8. 虫洞（Wormhole）

小星进入 A（`two_way` 时进 B 也行）→ 小星切到 WARP → 从另一端出来。速率不变；`keep_direction` 为真时方向不变，为假时方向改成出口节点的朝向。出口位置往外推一点，再加 `warp_cooldown`，防止来回触发。

## 9. 加速带（AccelStrip）

ON / OFF。普通章里常 ON；赛道里关联了小人的，那个小人已救才 ON，并在旁边显示那个小人。ON 时小星顺着带的方向进入（夹角小于 90°），沿带方向的速度提到至少 `target_speed`，可以超过 WASD 上限，但不超过封顶。

## 10. 流星（Meteor，P2）

IDLE → WARNING（地上出现红圈，持续 `warn_time`）→ IMPACT（只判定一帧：圈内的小星按阶段 2 撞墙扣亮度）→ COOLDOWN（`interval`）→ WARNING。

## 11. 黑洞（BlackHole，P2）

没有状态。半径内给小星一个指向中心的加速度 `strength ÷ max(距离, 最小距离)`，弹弓效果由物理自然产生。

## 12. 噬光者（Boss）

| 状态 | 行为 | 转移 |
|---|---|---|
| DORMANT | 不出现 | 终章开始 → EMERGE |
| EMERGE | 登场演出，小星 LOCKED 1–2 秒 | → CHASE |
| CHASE | 沿小星的轨迹（每 0.1 秒记一个点）以 `boss_speed` 追；距离超过 `boss_gap_max` 时提速跟上；接触小星时每秒吸走 `boss_drain` 亮度 | 小星到达逃离点 → RETREAT；被撞碎 → SHATTERED |
| RETREAT | 退回黑暗 | 主线结局 |
| SHATTERED | 碎裂演出 | 隐藏结局 |

- 噬光者无视墙，小星撞碎的墙它直接穿过去。
- 只有小星从隐藏虫洞出来后以阶段 5 撞上它，才进入 SHATTERED；其他接触一律算吸光。

## 13. 终章（Finale）

1. INTRO：终章场景自带的一小段区域，噬光者在这里登场。
2. RUN：依次实例化 ch4 → ch0，`prepare(FINALE)` 后把每段赛道的 Entry 对齐上一段的 Exit。
3. OUTRO：接在最后一段后面。满足隐藏条件时，key 小人出现，放下一个 `keep_direction = false`、出口朝向来路的虫洞。小星以阶段 5 进去 → 掉头撞上噬光者 → SHATTERED。没到阶段 5 进去也会掉头，但撞上只会被吸光。不满足条件或没进虫洞，跑到逃离点就是主线结局。

- 检查点 = 每段赛道的 Entry。复活时小星带 `chase_respawn_speed` 的初速，噬光者在身后 `boss_gap_start` 处重新出现。

## 14. 输入来源

KBM ⇄ TOUCH：收到触摸事件切到 TOUCH，显示虚拟摇杆；收到鼠标移动或按键切回 KBM，隐藏摇杆。小星只读统一的 move、aim、mode 三个值，不关心来源。

## 15. 全局信号（Game）

`speed_stage_changed(stage)`、`light_changed(value, max)`、`player_hit(kind)`、`player_died(cause)`、`npc_rescued(id)`、`vine_burnt(id)`、`wall_broken(id, hinted)`、`checkpoint_reached(id)`、`chapter_cleared(chapter_id)`、`warped()`、`boss_state_changed(state)`。

HUD、音效、镜头震动只听这些信号，不直接调玩法代码。
