# 状态机

v2 · 2026-11-02。字段名对应 `data/tuning.tres`，见 [关卡与数据格式](level-data-format.md)。
v2：去掉速度解锁和必救，加上铁门、栅栏、帮助和两个结局（第 16–18 节）。11-02 晚：噬光者和终章做出来了，第 12、13、18 节按实现补全。

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
| PLAYING | 进入出口 | CLEAR | 清空 checkpoint，存档 |
| CLEAR | 演出结束 | LOADING | 下一章；ch4 之后进终章 |
| CHASE | 到达逃离点 | ENDING | 正常结局：小星逃离，长夜暂退。一个都没救也会进。播结局动画（`ending_normal.tscn`，最后一段循环），Esc 回标题 |
| CHASE | 噬光者被撞碎 | ENDING | 隐藏结局（真结局）：播连环画 `ending_comic.tscn`——三页四格漫画 + 一张 CG（缺图才退回老的"整座城都亮了"结局页） |
| ENDING | 演出结束 | TITLE | 记录 endings，存档 |

- BOOT：标题第一次出现时读存档。从标题开始或继续之后，章节由 Game 加载（实例化 → `prepare(mode)` → 换场景），并按时写盘。
- 直接运行某个章节场景（编辑器里 F6、测试）时不读也不写存档，死亡和按 R 直接重载当前场景。
- 换场景前后各有 0.35 秒黑幕渐变；进了出口停 0.8 秒再切下一章。
- 标题：新的旅程 / 继续（存档里有可继续的章节才出现）。已有进度时"新的旅程"要按两次，免得误清存档。
- 暂停菜单（Esc）：继续 / 回到检查点 / 回到标题。
- 结局画面：正常结局是被救的人一盏盏亮成灯，然后浮出"长夜暂退"；隐藏结局（真结局）是连环画
  （`ending_comic.tscn`，见第 19 节）：三页四格漫画，每页先只露第一格，其余纯白，每 3 秒多放一格，
  点一下立刻多放一格并重置计时，四格齐了再点翻页，三页之后是 CG，CG 上点一下回标题。
  看完结局后存档里没有可继续的章节。
- 现在章节表里是两张测试关（test_light → test_feel），之后进终章，终章接的是这两关的测试赛道。
- 终章的存档：`chapter` 记成 `finale`，`checkpoint` 是跑过的最后一段赛道（或结尾）的 Entry，"继续"回到那里。
- 直接运行终章场景（F6、测试）时，终章自己把流程设成 CHASE。

## 2. 小星（Player）

### 2.1 生命状态

| 状态 | 进入条件 | 行为 | 离开 |
|---|---|---|---|
| SPAWN | 场景加载完 | 0.5 秒淡入，不能动，无敌 | → ACTIVE |
| ACTIVE | | 正常移动、发光、碰撞 | 见其他行 |
| WARP | 进入虫洞 | 约 0.15 秒隐身、无敌，然后从出口出来 | → ACTIVE |
| LOCKED | 噬光者登场、跑到逃离点、噬光者碎了 | 不接受输入，原地不动，亮度不衰减 | → ACTIVE |
| DYING | 亮度归零（熄灭）；阶段 2 撞墙时亮度不够（碎裂）；被噬光者吸干 | 1 秒死亡动画 | 发 `player_died` |

**死亡演出**：一进 DYING 就发 `Game.player_dying(pos, cause)`，按死法分两种；同时镜头就地把倍数拉近、慢放 0.28–0.45 倍（**真实时间** 0.5–0.7 秒），然后恢复常速，和帮助特写共用同一套 spot 逻辑。

| 死法 | 演出 | 镜头 |
|---|---|---|
| 亮度随时间耗尽（`EXTINGUISHED`，油尽灯枯） | `scripts/fx/dissolve.gd`：三十多个光点从星体位置**慢慢升起来**、摇摆、淡掉，一圈光环**收缩**收走它；星体本身继续画，按 1 秒线性淡下去 | 1.55 倍、0.45 倍速、0.7 秒，轻一点久一点 |
| 撞墙碎裂、被噬光者吸干（`SHATTERED` / `DRAINED`） | `scripts/fx/shatter.gd`：亮核 + 扩散冲击环 + 30 块发光碎片向外炸开；星体当帧不画，碎片接手 | 2.0 倍、0.28 倍速、0.5 秒，狠一点短一点 |

两种演出里**光都不立刻掐断**：`fade()` 在 DYING 里仍按 1 秒线性降，所以是"灯慢慢熄灭"而不是"咔一下留个黑圆"。

### 2.2 速度阶段

- 升档：速率 ≥ 下一档的 `stage_min`。降档：速率 < 本档的 `stage_min − hysteresis`。回差避免在边界来回跳，并且偏向安全，所以阶段 2 例外：从阶段 1 升到 2 要多出 `hysteresis`，从阶段 2 降到 1 不用回差。
- 一档的"顶" = 下一档的 `stage_min − 1`；阶段 5 的顶是 `max_speed`。
- 没有按章节或进度的封顶，速率最高 `max_speed`。能到哪一档全看地图（关卡与数据格式第 11 节）。
- WASD 最多把速率推到 `input_max_stage` 的顶。更快只能靠加速带、虫洞、黑洞，超出部分按 `overspeed_decay` 回落。所以阶段 5 只出现在摆了加速带的地方，终章靠赛道的加速带（和园丁的花）维持。
- 松手按 `coast_decel` 减速。输入里和速度方向相反的那部分乘 `brake_mult`，相当于刹车；和速度方向垂直的那部分乘 `turn_mult`，控制转弯灵敏度。
- 档位变化时发 `speed_stage_changed`。进入阶段 2 时预警：红拖尾 + 星体裂纹闪烁 + 警示音。

### 2.3 撞墙

每次 `move_and_collide` 撞到东西：

1. `vn = −velocity · normal`。如果 `vn ÷ 速率 < graze_ratio`，算擦墙：去掉法向分量，贴墙滑走，不再往下判断。
2. 否则按当前阶段和墙的类型查表：

| | 阶段 1 | 阶段 2 | 阶段 3 | 阶段 4 | 阶段 5 |
|---|---|---|---|---|---|
| 黑墙、玻璃、影藤、栅栏 | 滑行，减速 s1_wall_loss | 扣 s2_damage，弹开并把速度压到 s2_exit_speed，进入无敌；亮度不够 → 碎裂 | 反弹 | 反弹 | 撞碎，减速 smash_speed_loss |
| 铁门、边界 | 同上 | 同上 | 反弹 | 反弹 | 反弹，撞不碎 |
| 裂纹墙 | 同上 | 同上 | 反弹 | 撞碎，减速 break_speed_loss | 撞碎，减速 break_speed_loss |
| 软垫 | 急停，速度归零 | 急停 | 急停 | 急停 | 撞碎，减速 smash_speed_loss |

- 反弹：速度沿法线镜像，乘 `bounce_restitution`，开 `bounce_grace` 保护。保护期内的阶段 2 撞击也按反弹处理。
- 受伤无敌期（`hurt_iframes`）内的阶段 2 撞击按阶段 1 处理。
- 阶段 5 只在终章出现。撞黑墙时从碰撞点沿法线往墙里进 1 像素，用 `local_to_map()` 找到格子，擦掉 `smash_radius` 内的格子。不能用 `get_coords_for_body_rid()`：4.5 起图块碰撞按 `physics_quadrant_size` 合并，它返回的是分块坐标。边界图块（`unbreakable`）任何速度都不碎，阶段 5 撞上也按反弹处理，防止冲出地图。铁门同样撞不碎，只有锁匠能打开。
- 噬光者不按墙处理，见第 12 节。

### 2.4 光

- 模式 SCATTER ⇄ FOCUS，默认 SCATTER。左键/空格切到 SCATTER，右键/Shift 切到 FOCUS，触屏点按切换。键鼠时瞄准方向跟着鼠标。
- 亮度每秒减 `decay`，聚光时乘 `focus_decay_mult`；归零进入 DYING。
- 每个物理帧，对 `light_receiver` 组里的目标检查距离、角度和视线，照到就调用它的 `receive_light(mode, delta)`：
  - SCATTER：`scatter_radius` 以内。
  - FOCUS：锥形，半角 `focus_half_angle`，距离 = 散射半径 × `focus_range_mult`。中心射线先打到玻璃时，从击中点沿反射方向再算一个锥形，距离用剩下的，只反射一次。聚光时光环只用来显示亮度，不照亮目标。
- 视线射线的 mask 是物理层 1–5。目标是影藤时，射线第一下打中的就是它，算照到。
- 接口：`light_receiver` 组里的节点提供 `light_target(from)`（拿哪个点判断距离、角度和视线；小人是自己的位置，影藤是离小星最近的那个点）和 `receive_light(mode, delta)`。判定写在小星的子节点 StarLight 里。
- 小人和影藤记下最后一次被照到的物理帧，"这一帧或上一帧被照到"就算照到。小星的光在它们之后才算，不留这一帧余量就永远慢一帧。
- 画面：散射是带阴影的圆形点光，聚光是带阴影的锥形光，打到玻璃再加一束反射光。光环 = 半径为散射半径的细圆圈，亮度低于上限的 `low_light_ratio` 时闪红。开了 `dark` 的关卡加 CanvasModulate（颜色 `ambient`）和一层地面，没被照到的地方变暗；自己发光的东西（小星、哭声圈、进度圈、加速带、小星星、检查点、出口、虫洞、特殊墙的纹路）用 unshaded 材质，不受暗处影响。

## 3. 小人（Npc）

| 状态 | 行为 | 转移 |
|---|---|---|
| CRYING | 播哭声和声波圈 | 被照到 → WAKING |
| WAKING | 照到时 progress += delta；没照到时 progress −= delta × progress_decay。进度画成一颗慢慢长大的光种 | progress ≤ 0 → CRYING；progress ≥ need_time → RESCUED |
| RESCUED | 梦想浮现：身后浮现一幅发光的画面（守夜人身后亮起整条街灯……），之后一直留着当光源。持久保存 | — |

- 进入 RESCUED 时：发 `npc_rescued`，存档（记下职业），亮度上限 +`light_per_rescue` 并回满，职业的帮助生效（第 18 节）。
- 结伴：两人同时被照到时进度才涨，任意一人没照到就回落；满 `pair_time` 时两人一起 RESCUED。`partner` 只需在其中一人身上设置，由这个人算进度，另一人只显示进度。
- 小人是 Node2D，没有物理体。身体被照到才看得见；哭声的声波圈隔着墙也看得见，用来找人。
- 藏着的人（`secret`）：向导被救之前不出声、不显示声波圈，但照到了照样能救。
- 照不到的人（`mail`）：`receive_light` 不算数。章节加载时把自己的 save_id 记进存档的 `mail`；邮差被救时，`mail` 里的人一起被救，不管在哪一章。自己那章已经过去的，就在存档里记成已救。

## 4. 影藤（ShadowVine）

INTACT →（被聚光照到）BURNING →（累计 ≥ `vine_burn_time`）BURNT。

- BURNING 时没照到就按 `progress_decay` 倍回落，回到 0 变回 INTACT。
- BURNT：移除碰撞和遮光，写进存档 `burnt`，发 `vine_burnt`。
- 散射照到影藤没有效果，只是被挡住。

## 5. 裂纹墙（CrackedWall）

INTACT →（阶段 4 以上撞上）BROKEN：播碎片，移除碰撞和遮光，写进 `broken`，发 `wall_broken(id)`。

## 6. 检查点（Checkpoint）

INACTIVE →（小星进入）ACTIVE：写存档 `checkpoint`，只记最新的一个，其他检查点变回 INACTIVE。加载章节时，存档里的检查点在这一关就从它出生，否则从 PlayerStart。

## 7. 出口（Exit）

一直开着。OPEN →（小星进入）CLEARED：发 `chapter_cleared`。没有必救的人，没救的人就留在这一章里。

## 8. 虫洞（Wormhole）

小星进入 A（`two_way` 时进 B 也行）→ 小星切到 WARP → 从另一端出来。速率不变；`keep_direction` 为真时方向不变，为假时方向改成出口节点的朝向。出口位置沿出来的方向往外推（虫洞半径 + 小星半径 + 4 px），从进入起 WARP 时间 + `warp_cooldown` 内不再触发，防止来回传送。传送时镜头直接切过去。

## 9. 加速带（AccelStrip）

没有状态。小星顺着带的方向进入（夹角小于 90°）时，沿带方向的速度提到至少 `target_speed`，可以超过 WASD 上限，但不超过 `max_speed`。园丁的花也是加速带（画成花），挂在他的帮助点下面：园丁没救就不出现。

## 10. 流星（Meteor）

已实现（`scripts/entities/meteor.gd`）。IDLE → WARNING（地上出现红圈，持续 `warn_time`）→ IMPACT（只判定一帧：圈内的小星按阶段 2 撞墙扣亮度）→ COOLDOWN（`interval`）→ WARNING。

- 每个流星节点自己带 `interval`（默认 2.6 秒）、`warn_time`（1.1 秒）、`radius`（80 px），在编辑器里按关卡需要调，不放进 tuning。
- 判定用 `玩家位置到圈心 <= radius + 小星半径`；砸中走 `Player.blast(s2_damage)`，和阶段 2 撞墙同一套代价（亮度不够会碎）。
- 落地一律发 `player_hit("meteor")`（有落地声），圈外只是不掉亮度。

## 11. 黑洞（BlackHole）

已实现（`scripts/entities/blackhole.gd`）。没有状态。半径内给小星一个指向中心的加速度 `strength ÷ max(距离, 最小距离)`，弹弓效果由物理自然产生。

- 每个黑洞节点自己带 `radius`（默认 200）和 `strength`（默认 48000：半径边缘约 200 px/s²，贴脸封顶 1200），`min_distance` 默认 40。
- 这个加速度每帧写进 `Player.push`，由 `step_velocity` 在**松手减速之后**叠上去再清空。直接改 velocity 的话会被 `coast_decel` 抹掉，人根本吸不动——这个坑踩过。
- 外部推力不受 WASD 上限约束，能甩到比 759 更快——但**只在终章**（`Game.flow == CHASE`）：关卡里封在阶段 4 的顶，否则玩家会借着黑洞冲到阶段 5 把关卡挖穿。之后按 `overspeed_decay` 回落。

## 12. 噬光者（Boss）

| 状态 | 行为 | 转移 |
|---|---|---|
| DORMANT | 不出现 | 终章开始 → EMERGE |
| EMERGE | 登场演出。终章开头 1.5 秒，小星 LOCKED；复活时 0.5 秒，和小星出生一起结束 | → CHASE |
| CHASE | 沿小星的轨迹（每 0.1 秒记一个点）以 `boss_speed` 追；距离超过 `boss_gap_max` 时提速跟上；接触小星时每秒吸走 `boss_drain` 亮度。帮助的影响见第 18 节：减速、震退、盾 | 小星到达逃离点 → RETREAT；被撞碎 → SHATTERED |
| RETREAT | 退回黑暗 | 主线结局 |
| SHATTERED | 碎裂演出 | 隐藏结局 |

- 噬光者无视墙，小星撞碎的墙它直接穿过去。小星穿过虫洞时，它从入口那一点直线走到出口那一点。
- 只有小星从科学家的虫洞出来后以阶段 5 撞上它，才进入 SHATTERED；其他接触一律算吸光。
- 小星从科学家的虫洞出来后的 `charge_time` 秒里一路冲回去：不听方向键，速度不变。这时噬光者不再沿轨迹走，直接扑向小星。撞上一次，不管碎没碎，这股冲劲都用掉。
- 震退只在 CHASE 里起作用。碎裂时镜头大震一下。

## 13. 终章（Finale）

1. INTRO：终章场景自带的一小段区域。噬光者在 BossStart 登场（EMERGE 1.5 秒），这期间小星出生完就被锁住，噬光者开始追时解锁。出口站着**点灯的人**（`RoadLighter`）——赛道上所有加速带一开始是收着的（`AccelStrip.undeploy()`：不画、不触发），小星跑过他身边，他才把整条路点着。
2. RUN：依次实例化 ch4 → ch0，`prepare(FINALE)` 后、加入场景树前，把每段赛道的 Entry 对齐上一段的 Exit。
3. OUTRO：挪到最后一段后面。所有人都已救时，科学家出现，放下一个 `keep_direction = false`、出口朝向来路的虫洞。小星以阶段 5 进去 → 掉头撞上噬光者 → SHATTERED → 隐藏结局。没到阶段 5 进去也会掉头，但撞上只会被吸光。没救全或没进虫洞，跑到逃离点就是正常结局。

- 检查点 = 每段赛道的 Entry 和结尾的 Entry：小星跑到它左边就记下，写进存档。复活时小星在那里出来，带 `chase_respawn_speed` 的初速朝左，噬光者在身后 `boss_gap_start` 处出现，和小星同时开始动。没跑过任何 Entry 就从开头重来。
- RUN 时，各段赛道里的帮助点看对应的人有没有被救：救了就站在路边，小星经过时触发他的帮助；没救的就不出现。
- **铺路演出**：点灯的人发 `Game.road_light` 后，镜头从玩家身上脱开、沿赛道往前方（往左）滑 `SWEEP_PX` = 1500 px，同时拉远到 0.82 倍看清跑道，慢放到 0.32 倍；加速带从近到远一段段亮起来（每段隔 0.07 秒真实时间，带一下白光），一路铺到结尾，然后镜头回到跟随。演出期间小星有 3 秒无敌和保护，不会被这段时间的追逐打断。从检查点续跑时不演这一遍，直接铺好。
- 跑到逃离点：小星停下，噬光者 RETREAT，1 秒后进正常结局。噬光者碎了：小星停在原地，1 秒后进隐藏结局。
- **难度在赛道上，不在噬光者身上**：回程赛道是蛇形（三段横跑 + 3 处拐角 + 一个窄口），每段 140 格。噬光者只有 420，比 WASD 上限（759）慢得多——它不难在"追得快"，难在你**拐弯必须减速**，减速就被咬。每个拐角出来都有一条加速带，用来把掉的速度补回来；漏吃一条就拉不开。
  `tests/test_lanes.tscn` 让小星自己开一遍每段赛道（路点从图块算），`tests/test_chase.tscn` 是真实终章的追逐探针，会报"死了几次""噬光者贴到多近"——自动驾驶的水平比真人差一截，它跑不完不代表人跑不完，它的用处是给调参一个固定口径。
- 噬光者在屏幕外时，HUD 在屏幕边上它那个方向画一对红眼睛，越近越亮。

## 14. 输入来源

KBM ⇄ TOUCH：收到触摸事件切到 TOUCH，显示虚拟摇杆；收到鼠标移动或按键切回 KBM，隐藏摇杆。小星只读统一的 move、aim、mode 三个值，不关心来源。

## 15. 全局信号（Game）

`speed_stage_changed(stage)`、`light_changed(value, max)`、`player_hit(kind)`、`player_died(cause)`、`npc_rescued(id)`、`vine_burnt(id)`、`wall_broken(id)`、`checkpoint_reached(id)`、`chapter_cleared(chapter_id)`、`warped()`、`help_triggered(role)`、`boss_state_changed(state)`。

HUD、音效、镜头震动只听这些信号，不直接调玩法代码。

## 16. 铁门（IronDoor）

CLOSED →（锁匠已救）OPEN。

- 章节加载时锁匠已救，就直接是 OPEN，不播特效；锁匠在本章被救时，本章的铁门当场一扇扇打开。
- CLOSED 时挡路挡光，任何速度都撞不开（阶段 5 也反弹）。开门不单独存档，跟着锁匠走。

## 17. 栅栏（Bars）

没有状态。挡小星，不挡光：在第 9 层，不在视线射线的 mask 里，也没有遮光体。用来做"照得到、进不去"的笼子。撞上按黑墙处理。

## 17.5 影鬼（Enemy）和弹幕（Shot）

影鬼是蹲在暗处的射手，摆在关卡里守路（`tools/build_test_levels.gd` 的图例 `x`，一个格子一只）。

状态：IDLE →（看得见小星）AIM →（瞄完）FIRE → COOLDOWN → IDLE。

- **看得见**：小星活着、距离在 `enemy_range` 内、两点之间没有挡光的墙（射线打在 `Layers.WALLS` 上打不到东西）。躲到墙后面它就放弃这一枪，退回 IDLE。
- **瞄**：`enemy_aim_time` 秒。这期间它画一条越来越亮的红线指向小星，同时眼里那点红光变大——不写字，靠这两样告诉玩家"要开枪了"。
- **开枪**：沿红线方向打出一发 `Shot`，速度 `shot_speed`，从身子外面 14 px 处出生（不会一出来就打到自己）。
- **冷却**：`enemy_cooldown` 秒，然后重新判定。

弹幕 `Shot`：直线飞，撞墙按法线反射，弹满 `shot_bounces`（默认 3）次后熄灭；命中小星掉 `shot_damage` 亮度并把小星往弹幕方向推 `shot_knockback`（直接加在速度上，下一帧照常被档位钳制）。

**难度随章节涨**（`Enemy.tier`，构建器按章节表填：ch0=1 … ch4=5）：

| | 瞄准时间 | 冷却 | 一次几发 |
|---|---|---|---|
| 公式 | `aim_time × (1 − 0.08 × (tier−1))` | `cooldown × (1 − 0.1 × (tier−1))` | `tier ≥ enemy_double_from`（默认 3）时 2 发，左右各偏 `enemy_spread` 度 |
| ch0 | 0.60 秒 | 2.40 秒 | 1 |
| ch4 | 0.41 秒 | 1.68 秒 | 2 |

倍率和阈值都在 `scripts/data/tuning.gd` 的「影鬼」组里，`tier` 在构建器 `_tier_for()` 里按章节表给。

影鬼的三种死法：

1. **小星撞上来**：距离小于 `enemy_radius + Player.RADIUS + 2` 就散架（`reason = &"charge"`）。它没有墙的碰撞层，所以小星是直接穿过去把它撞散的。
2. **自己的弹幕弹回来打中**（`&"shot"`）：贴着墙打一枪再躲开，弹幕会绕回来——这是拆影鬼的正规解法。
3. 别的影鬼的弹幕打中它，同样算 `&"shot"`。

死了发 `Game.enemy_killed(reason)`，掉一团碎片。测试 `tests/test_enemy.tscn`；其余测试用 `Game.debug_no_enemies` 把影鬼按住，免得打乱亮度断言。

## 18. 帮助（职业）

被救的人按职业帮小星。终章的帮助由赛道里的帮助点（HelpPoint）触发：对应的人已救，他就站在路边，小星经过时生效，发 `help_triggered(role)`；没救就不出现。路灯、花、光门、隧道都是帮助点的子节点，人没救就不出现、不打开。

触发的那一下会切一个**特写**（`follow_camera.gd`）：镜头框在帮助者和小星中间、拉近到 1.7 倍、时间放慢到 0.35 倍，持续 1.15 秒真实时间再恢复。终章速度是 800–900 px/s，一闪而过的话玩家根本看不出是谁帮了自己——这是实测出来的节奏问题。屏幕上一个字都不写（见第 10 节的"不出现文字"）。
"经过"是穿过帮助点的一根竖条（上下各 600 px），小星从哪一行跑过去都算。每次加载终章（包括复活）每个帮助点能帮一次。

| 职业 | 什么时候 | 效果 |
|---|---|---|
| 守夜人 | 终章，经过他 | 他那段赛道的路灯由近到远亮起来；给小星一层盾，挡掉下一次噬光者的接触，噬光者被弹回 `help_knockback` 的一半 |
| 园丁 | 终章 | 他那段赛道的花亮起，就是加速带 |
| 医生 | 终章，经过他 | 亮度回满 |
| 画家 | 终章 | 他那段赛道墙上出现光门（虫洞），是条捷径 |
| 矿工 | 终章 | 他那段赛道的隧道打开（一段墙消失），是条捷径 |
| 锁匠 | 被救当场，之后一直 | 所有铁门打开：本章当场开，其他章加载时就是开的 |
| 邮差 | 被救当场 | `mail` 里的人一起被救 |
| 向导 | 被救当场，之后一直 | 藏着的人开始出声，显示声波圈 |
| 乐手（和听众） | 终章，经过他们 | 噬光者沿轨迹往后退 `help_knockback`。听众自己的帮助点只是站在旁边加油 |
| 钟表匠 | 终章，经过他 | 噬光者 `help_slow_time` 秒内速度乘 `help_slow_mult` |
| 科学家 | 终章 OUTRO | 所有人都已救时出现，放下掉头的虫洞（第 13 节） |

## 19. 真结局连环画（EndingComic）

撞碎噬光者之后播（`scenes/ui/ending_comic.tscn`，`scripts/ui/ending_comic.gd`）。**纯黑底**，屏幕上一个字都不写。

- 素材：`assets/art/cg/1.png`、`2.png`、`3.png` 各是一页白底四格漫画，`CG.png` 是最后一张 CG。
  `1_black.png` / `2_black.png` / `3_black.png` 是它们的黑底版（`tools/comic_panels.py` 把四格以外刷黑），游戏里用黑底版。
- 一页 = 4 格，阅读顺序（左上、右上、左下、右下）。**一开始只露第一格**，其余三格纯黑。
- 计时：每 `PAGE_WAIT`（3 秒）自动多露一格；**点一下**（左键/触屏/空格/回车）立刻多露一格，并把 3 秒计时重置。
- 四格都露出来以后再点一下，翻到下一页（重新从"只有第一格"开始）。
- 第三页之后进 CG。CG 有运镜（`CG_CAMERA` 关键帧）：0→0.8 秒拉近到左下（人群，2.2 倍），
  2.4 秒推到中（小星），4.0 秒推到中上（灯泡），5.6 秒回到中，7.6 秒拉远到正常大小，之后停住。
  段与段之间 smoothstep；运镜途中点一下直接跳到结尾，运镜结束以后再点回标题。Esc 任何时候都能直接回标题。
- 涂黑：每格的多边形记在 `ending_comic.gd` 的 `PANELS` 里（`tools/comic_panels.py` 从原图量出来的），
  没轮到的格子用这个多边形（往外多盖 `MASK_GROW` 像素，落在已经黑了的格间空缝里）涂黑。
- 缺图时 `Game.ending_scene(&"hidden")` 退回老的 `ending.tscn`（"整座城都亮了"），所以删图不会崩。
- 结局记录在进结局时就已经写盘（`Save.endings["hidden"]`），跟玩家看不看完无关。
