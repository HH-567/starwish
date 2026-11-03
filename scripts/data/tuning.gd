class_name Tuning
extends Resource
## 全部手感数值，字段含义见 docs/level-data-format.md 第 8 节。
## 在编辑器里改 data/tuning.tres；游戏每帧现读，改完重新运行即可。

@export_group("移动")
## WASD 加速度，px/s²。
@export var accel := 420.0
## 松手时的减速，px/s²。
@export var coast_decel := 90.0
## 输入里和速度方向相反的那部分乘这个数（刹车）。
@export var brake_mult := 3.5
## 输入里和速度方向垂直的那部分乘这个数（转弯灵敏度）。
@export var turn_mult := 1.0
## 法向速度 ÷ 速率低于它算擦墙。
@export var graze_ratio := 0.35

@export_group("速度")
## 阶段 1–5 的速率下限，px/s。
@export var stage_min := PackedFloat32Array([0.0, 220.0, 380.0, 560.0, 760.0])
## 换档回差，偏向安全：阶段 2 晚进早出。
@export var hysteresis := 20.0
## 阶段 5 封顶。
@export var max_speed := 980.0
## WASD 最多推到这一档的顶，更快只能靠加速带。
@export_range(1, 5) var input_max_stage := 4
## 超过 WASD 上限后每秒回落多少。
@export var overspeed_decay := 50.0
## 阶段 1–5 的拖尾颜色。
@export var trail_colors := PackedColorArray([Color("ffffff"), Color("ff4b4b"), Color("ff9e3d"), Color("4da3ff"), Color("b366ff")])

@export_group("碰撞")
## 阶段 1 撞墙的减速比例。
@export var s1_wall_loss := 0.15
## 阶段 2 撞墙扣的亮度。
@export var s2_damage := 20.0
## 阶段 2 撞墙后速度压到这里（阶段 1）。
@export var s2_exit_speed := 150.0
## 受伤后无敌秒数。
@export var hurt_iframes := 0.6
## 反弹后保留的速度比例。
@export var bounce_restitution := 0.85
## 反弹后保护秒数，期间的阶段 2 撞击也按反弹处理。
@export var bounce_grace := 0.5
## 撞碎裂纹墙的减速比例。
@export var break_speed_loss := 0.1
## 阶段 5 撞碎其他墙的减速比例。
@export var smash_speed_loss := 0.12
## 阶段 5 撞黑墙时擦掉的格子半径。
@export var smash_radius := 1

@export_group("光")
@export var light_base := 60.0
@export var light_per_rescue := 5.0
@export var light_cap := 140.0
## 每秒衰减。
@export var decay := 1.0
## 聚光时衰减乘这个数。
@export var focus_decay_mult := 1.5
## 散射半径，按 当前亮度 ÷ light_cap 在两者之间插值。光环大小就是这个半径。
@export var scatter_radius_min := 90.0
@export var scatter_radius_max := 220.0
## 聚光距离 = 散射半径 × 这个数。
@export var focus_range_mult := 2.2
## 聚光锥形的半角，度。
@export var focus_half_angle := 16.0
## 小星星一次回多少亮度。
@export var shard_amount := 15.0
## 亮度低于上限的这个比例时，光环闪红（之后加心跳声）。
@export var low_light_ratio := 0.25
## 暗处的颜色：开了 dark 的关卡里，没被照到的地方乘这个颜色。越暗越难看清路。
@export var ambient := Color(0.2, 0.22, 0.32)

@export_group("小人")
## 怕黑小人要被照多久，秒。
@export var wake_time := 2.0
## 结伴的两人要同时被照多久。
@export var pair_time := 1.5
## 影藤要被聚光照多久才烧断。
@export var vine_burn_time := 1.5
## 没照到时进度回落的倍率。
@export var progress_decay := 2.0

@export_group("虫洞")
## 传送后多久内不再触发，秒。
@export var warp_cooldown := 0.3

@export_group("追逐")
## 噬光者沿轨迹追的速度：比 WASD 能到的最快（759）快，比赛道加速带（920）慢，只有靠加速带才能拉开。
@export var boss_speed := 790.0
## 出现时在小星身后多远（沿轨迹）。
@export var boss_gap_start := 500.0
## 沿轨迹落后超过这么远时提速跟上。
@export var boss_gap_max := 900.0
## 跟不上时提到多快。
@export var boss_catch_speed := 1100.0
## 碰到小星时每秒吸走的亮度。
@export var boss_drain := 80.0
## 终章里复活时小星的初速（阶段 4），朝左。
@export var chase_respawn_speed := 600.0

@export_group("帮助")
## 钟表匠：噬光者减速几秒、速度乘多少。
@export var help_slow_time := 2.0
@export var help_slow_mult := 0.5
## 乐手：噬光者沿轨迹往后退多少 px。守夜人的盾挡住一次接触时，噬光者退一半。
@export var help_knockback := 400.0
## 科学家：从他的虫洞出来后一路冲回去多久。这段时间不听方向键，速度不变，以阶段 5 撞上噬光者就能撞碎它。
@export var charge_time := 1.5

## 某一档的顶：下一档的下限减 1；阶段 5 的顶是 max_speed。
func stage_top(stage: int) -> float:
	if stage >= 5:
		return max_speed
	return stage_min[stage] - 1.0

func stage_color(stage: int) -> Color:
	return trail_colors[clampi(stage, 1, 5) - 1]

## 亮度为 light 时的散射半径。
func scatter_radius(light: float) -> float:
	return lerpf(scatter_radius_min, scatter_radius_max, clampf(light / light_cap, 0.0, 1.0))

func focus_range(light: float) -> float:
	return scatter_radius(light) * focus_range_mult
