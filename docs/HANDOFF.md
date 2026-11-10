# 交接文档 · 星愿：撞碎长夜

> 给接手的人（Claude）：这份文档把「怎么跑起来、代码怎么组织、哪些坑不能再踩、还剩什么没做」一次说清。
> 先看第 1、2、3 节把环境跑通，再看第 8 节（踩坑清单）——那里的每一条都是实际踩出来的。

---

## 1. 一句话现状

Godot 4.7.2 做的 2D 像素风叙事跑酷/潜行游戏，五个章节 + 终章 boss 追逐 + 双结局。
**26 项 headless 测试全绿**，Web 包可导出，美术/音频/关卡都已落地。

---

## 2. 环境与路径

| 项 | 值 |
|---|---|
| 引擎 | `C:\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe` |
| 项目根 | `C:\Users\21397\Desktop\环境检查\starwish` |
| 导出目标 | Web（`build/index.html`，已在 `export_presets.cfg` 配好） |

**每次 headless 运行前都要把 APPDATA 指到项目内**，否则会读到真实的用户存档、干扰测试：

```powershell
$env:APPDATA = 'C:\Users\21397\Desktop\环境检查\starwish\.tmp_build\appdata'
```

---

## 3. 五条命令（记住这五条就够）

```powershell
$G = 'C:\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$env:APPDATA = 'C:\Users\21397\Desktop\环境检查\starwish\.tmp_build\appdata'

# 1) 改了脚本 / 资源 / class_name 之后：重新导入
& $G --headless --path . --import

# 2) 改了 tools/*_map.txt 之后：重建关卡场景（必须！）
& $G --headless --path . 'res://tools/build_test_levels.tscn'

# 3) 跑单个测试
& $G --headless --path . --fixed-fps 60 'res://tests/test_ch0.tscn'

# 4) 跑全部测试（PowerShell 批量）
$tests = (Get-ChildItem tests -Filter '*.tscn').BaseName
foreach ($t in $tests) { & $G --headless --path . --fixed-fps 60 "res://tests/$t.tscn" }

# 5) 导出 Web
& $G --headless --path . --export-release 'Web' 'build/index.html'
```

判读：测试输出 `RESULT PASS，失败 0 项` 且退出码 0 才算过。

### Linux / WSL（2026-11-10 起工程在 `~/gamejam/starwish2`）

```bash
source tools/dev.sh        # 设好 G 和 XDG_DATA_HOME（Linux 上的存档隔离，等价于 APPDATA）
gd_import; gd_build; gd_test test_ch0; gd_all; gd_export
gd_shots ch1               # 截图巡游（xvfb-run），帧在 .tmp_build/shots/ch1/
```

Python 工具要 PIL/numpy：系统 python 没有 pip，用 `~/.local/bin/python3.11 -m venv .tmp_build/venv`
再 `.tmp_build/venv/bin/pip install pillow numpy`。

---

## 4. 目录结构

```
starwish/
├─ project.godot            自动加载：Save / Game / Audio / Controls
├─ export_presets.cfg       Web 导出配置
├─ scenes/
│  ├─ levels/               ★ 生成物，不要手改（ch0..ch4、chase_lane、finale、test_*）
│  ├─ entities/             实体场景（npc / enemy / boss / mirror / bars / iron_door …）
│  └─ ui/                   title / hud / pause_menu / settings / credits / ending
├─ scripts/
│  ├─ autoload/             save.gd  game.gd  audio.gd  controls.gd
│  ├─ data/                 tuning.gd  layers.gd  chapters 表
│  ├─ entities/             玩家、星星光、NPC、敌人、boss、镜子、栅栏、铁门…
│  ├─ levels/               chapter.gd（章节基类）、finale.gd
│  ├─ fx/                   shatter / dissolve / debris / hit_burst / help_fx / boss_fx / lighting
│  └─ ui/                   title / hud / pause_menu / settings / credits / gear_icon / icon_button
├─ tools/                   ★ 关卡源文件 + 构建器 + 探针 + 截图工具
│  ├─ *_map.txt / *_lane.txt   ASCII 地图（唯一的关卡真源）
│  ├─ build_test_levels.gd     地图 → 场景 的构建器
│  ├─ probe_*.gd               诊断探针（迷宫/镜子/医生/F6/标题状态）
│  └─ shots_*.gd               截图小场景
├─ tests/                   23 个 headless 测试
├─ assets/art/              位图美术（按 22 个类别分目录，见 docs/art-spec.md）
├─ audio/                   10 个音效 wav + bgm/ 9 首（本地合成的占位曲）
├─ fonts/                   CJK 字体
└─ docs/                    ★ 设计/美术/音频/踩坑文档，见第 9 节索引
```

---

## 5. 关卡生成流程（铁律）

关卡**不是手摆的**，是从 ASCII 文本生成的：

```
tools/ch1_map.txt  ──┐
tools/ch1_lane.txt ──┴─►  tools/build_test_levels.tscn  ──►  scenes/levels/ch1_vine.tscn
```

**铁律**：

1. 只改 `tools/*_map.txt`，**永远不要**手改 `scenes/levels/*.tscn`（会被下次构建覆盖）；
2. 改完地图**必须先跑构建**，再跑测试，否则测的是旧场景（这个坑踩过好几次，会误判成代码坏了）；
3. 加/删 `class_name`、改资源路径后先 `--import`。

### 地图字符表（常用）

（完整图例以 `tools/build_test_levels.gd` 文件头为准，2026-11-10 按它校对过）

| 字符 | 含义 | 字符 | 含义 |
|---|---|---|---|
| `#` | 墙 | `.` | 空地 |
| `@` | 边界墙（阶段 5 也撞不碎） | `S` | 出生点 |
| `E` | 出口 | `K` | 检查点（多个时从左到右叫 Checkpoint、Checkpoint2…） |
| `*` | 补给星屑 | `'` | 面包屑 |
| `w g d/D a G M m L p q c Z` | 各职业 NPC | `n` | 无名 NPC |
| `-` `\|` `/` `\` | **镜子**（横、竖、两种斜） | `H` | 栅栏（挡人透光） |
| `I` | 铁门（锁匠） | `T` | 矿工隧道（赛道里） |
| `C` | 裂纹墙 | `P` | 软垫 |
| `V` | 影藤 | `x` | 影鬼 |
| `+` | 流星 | `=` | 黑洞 |
| `>` `<` `^` `v` | 加速带（四个方向） | `A` `B` | 虫洞两端 |

> ⚠️ 最容易弄错：`-` 是**镜子**不是栅栏。要「挡人不挡光」用 `H`。

---

## 6. 测试清单（26 项）

| 测试 | 覆盖 |
|---|---|
| `test_save` | 存档读写、版本迁移 |
| `test_collisions` | 碰撞、反弹、撞碎 |
| `test_light` | 光照、救人、铁门、栅栏 |
| `test_light_level` | 完整关卡光照流程（12 个职业全救） |
| `test_level_smoke` | 所有关卡能加载、有出口 |
| `test_boss` | boss 状态机、击退、减速 |
| `test_chase` | 追逐段 |
| `test_ch0`～`test_ch4` | 各章通关脚本 |
| `test_hazards` | 陷阱 |
| `test_enemy` | 影鬼行为、击杀 |
| `test_death_fx` | 死亡动画时长 |
| `test_full` | 12 职业不重不漏、全流程 |
| `test_audio` | 音效触发、音量 |
| `test_settings` | 音量、三档难度开关、设置面板 |
| `test_touch` | 触屏按钮布局 |
| `test_flow` | 标题→游戏→暂停→结局的流程 |
| `test_finale` | 终章追逐、加速带、双结局（迷宫在此测试里被抹平） |
| `test_ending_normal` | 普通结局动画的时间线、循环段、Esc 回标题 |
| `test_ending_comic` | 真结局连环画：3 秒一格、点击立刻一格并重置、四格后翻页、三页后 CG、CG 点击回标题 |
| `test_title_sway` | 标题页鼠标视差：偏哪边往反方向挪、移出窗口回中、没人动鼠标时不晃 |
| `test_lanes` | 赛道段拼接 |
| `test_stage` | 速度阶段阈值 |

---

## 7. 已完成的系统

### 7.1 光照与黑夜
- 全场 `CanvasModulate` 压暗，玩家自带光；`scripts/fx/lighting.gd` 统一封装 `unshaded()` / 点光 / 锥光。
- 两种模式：**散射**（半径 90–220px，随亮度变）与**聚光**（锥形、16° 半角、射程 ×2.2）。
- 聚光撞到 `Mirror` 会**反射一次**（`star_light._shine`），反射光同样能救人。
- 本体常亮一盏 46px 小灯，聚光时主角不会陷进黑暗。

### 7.2 救人（12 职业，一个不重不漏）
- 站进光里等 `wake_time`；乐手/听众需要配对。
- 救人**不再提升亮度上限**（上限固定 60），靠补给与操作维持。
- 职业帮助：守夜人给盾、园丁开花、医生回光、画家开门、向导传声、矿工挖隧道、锁匠开门、邮差送信、乐手击退 boss、听众、钟表匠减速 boss、科学家开虫洞。

### 7.3 终章 boss 追逐
- 六折 S 迷宫（`tools/finale_outro.txt`）：
  - 没救锁匠 → 7 个拐弯；
  - 救了锁匠 → 顶部直线捷径 3 个拐弯（铁门走近自己开）。
- 加速带由 NPC 在中途部署；回程铺灯演出。
- 双结局：撞碎噬光者 = 隐藏结局（真结局）；被追上 = 普通结局。
- 真结局（2026-11-10）：撞碎后播 `scenes/ui/ending_comic.tscn`——三页四格漫画 + 一张 CG。
  纯黑底。每页一开始只露第一格，其余纯黑；每 3 秒自动多露一格，点一下立刻多露一格并重置计时；
  四格齐了再点翻页；三页之后是 CG。CG 有约 8 秒运镜：推近到左下人群 → 中 → 中上灯泡（推到 3 倍）→ 中 →
  拉远到正常大小；关键帧之间是单调三次 Hermite（速度连续），平移和推拉时间错开，所以没有一帧是停住的
  （运镜途中点一下跳到结尾，结束以后再点回标题；Esc 随时回）。素材在 `assets/art/cg/`，
  游戏里用 `tools/comic_panels.py` 生成的 `N_black.png` 黑底版（换图后重跑它，并把 `PANELS` 换掉）；
  缺图退回老的结局页。测试 `tests/test_ending_comic`。
- 普通结局（2026-11-10）：跑到逃离点后播 `scenes/ui/ending_normal.tscn` 动画——城市全景、小星沿贝塞尔曲线飞到左上角锁死、
  噬光者从底部长出来把城市的灯一栋栋吸走、再缩回去消失，小星越飞越远、无光的城市缩到远景（第一遍共 10 秒）；之后只循环最后 1.6 秒（远处的无光城市 + 小星伪飞行）。
  Esc 或右下角的房子图标回标题。半分辨率 SubViewport + Nearest 放大；时间线写在 `ending_normal.gd` 文件头，
  测试 `tests/test_ending_normal`。城市剪影没有素材，是程序画的占位（`ending_world.gd` 里的 TODO）

### 7.4 打击感
- 白热冲击环 + 放射火花（`hit_burst.gd`，0.3s）
- 敌人命中定格 0.06s 闪白，再炸开
- 连击：0.9s 内连杀，环变大、碎片变多、音高升高
- 撞墙/撞碎墙/死亡/boss 分级震动（`follow_camera.SHAKE_BY_HIT`）
- 2026-11-10 加：**定帧**（`HITSTOP_BY_HIT`：受伤 0.07s、碎裂纹墙 0.06s…，反弹不定帧，两次至少隔 0.25s）、
  镜头朝撞击方向**顿一下**（`KICK_BY_HIT`）、星体沿墙面法线**压扁**再弹回 / 高速时沿运动方向拉长、
  弹墙时墙面溅出这一档颜色的**火花**、切换光模式时一圈闪光。都只是画面，不改碰撞结果

### 7.5 难度（局外可调）
| 档位 | 变化 |
|---|---|
| 微光级 | 现在这样 |
| 长夜级 | 补给只留敌人 300px 内的；救人不再回光 |
| 永夜级 | 光衰减 ×1.7；关卡加载时每只影鬼旁多一只 |

### 7.6 UI（几乎全图形，不写字）
- 标题：小星绕椭圆轨道飞（先上后下转弯）+ 左郊区右城市背景；
  **打通真结局后**城市才亮起、噬光者消失（`Save.endings["hidden"]`）。
- 标题随鼠标晃（`title.gd`）：鼠标偏到哪边，画面就往反方向挪，近的层挪得多
  （星空 8px / 天际线 17px / 地面 25px / 路灯小人星屑 36px / 飞行的小星 21px），
  用阻尼弹簧收（会先冲过头再荡回来），快速划过时还会多带一下（冲量，约 20% 过冲）。
  移出窗口或回中心就回中；
  **没人动鼠标（键盘、触屏、headless 截图）时完全静止**，别让画面自己漂。
- 菜单：`▶ ↻ ✦⚙ ⌂ ✧ ▤ ✕` 全 `_draw` 画的图标（`icon_button.gd`）。
- 设置：喇叭/音符 + 10 格音量条 + ★◐⚫ 三档难度（`settings.gd`）。
- 制作名单：全游戏唯一写字的界面，可滚动、右上角 ✕。

---

## 8. 踩坑清单（重要，别重复踩）

1. **改完地图不重建** → 测试跑的是旧场景，会误判"代码坏了"。永远先跑 `build_test_levels`。
2. **`-` 是镜子不是栅栏**。栅栏是 `H`。ch1 医生房曾因此反射回原地。
3. **镜子反射方向**：`/` 把"向上"反射成"向右"；`\` 反射成"向左"。**用探针确认，别猜**。
4. **暂停时 UI 不响应**：任何"暂停里还要能点"的界面（暂停菜单、设置、名单）必须
   `process_mode = Node.PROCESS_MODE_ALWAYS`，否则整块被冻住，表现为"关不掉"。
5. **`get_process_delta_time()` 可能是 0**：不要用它做"等待超时"，会死循环。用帧数循环。
6. **改了 `class_name` 或新增脚本**：先 `--import`，否则报"找不到类型"。
7. **PNG 重新生成后不 `--import`** → 贴图变洋红。
8. **`edit` 工具**：`old_string` 以换行结尾时，可能把后面的 `func` 行并进注释，改完务必回读。
9. **PowerShell 里别写多行 Python `-c`**：中文/引号会被吞。用 `write` 工具写 `.tmp_build/*.py` 再执行。
10. **测试里传送玩家**要落在空地上，否则卡进墙里导致测试挂起（曾卡住 5 分钟）。
11. **标题/面板必须作为场景根**（Control）才有正确尺寸；用 Node2D 包一层会得到 0 尺寸、截图全黑。
12. **`Audio` 在测试里默认 `locked`**：要断言音量先 `Audio.locked = false`。
13. **改 `Engine.time_scale` 的那一帧**，`delta` 还是按旧倍率算的：用 `delta / time_scale` 当真实时间会算出半秒，
    定帧当帧就结束了。定帧按物理帧数计时（`1 / physics_ticks_per_second`）。
14. **子节点画在父节点 `_draw` 上面**：想把东西（影鬼的眼睛）画在贴图上面，贴图设 `show_behind_parent = true`。
15. **`data/tiles.tres` 每次构建都重新生成**（图集来自 `tools/tile_art.py`）：别在编辑器里改它。
16. **自己发光的东西开了阴影/带遮光体时会落在自己的影子里**：软垫、墙都把遮光体往里缩了一圈，边才照得亮。
17. **从 Windows 拷过来的文件带 `xxx:Zone.Identifier`**：已经 gitignore；`.git` 里的会让 `git log --all` 报错，删掉即可。

---

## 9. 文档索引（`docs/`）

| 文档 | 内容 |
|---|---|
| `state-machines.md` | ★ 所有状态机（玩家/敌人/boss/章节流程） |
| `level-data-format.md` | 地图字符表与关卡数据格式 |
| `art-spec.md` | 22 类美术资源规格与尺寸 |
| `doubao-brief*.md` | 给豆包的出图提示词（历史） |
| `audio-brief.md` / `bgm-status.md` | 音效/BGM 清单与替换方式 |
| `boss-maze-status.md` | 终章迷宫的演进与探针结论 |
| `level-design-mirror-room.md` | ch1 镜子房的解法与踩坑 |
| `level-design-bounce.md` | 反弹谜题设计 |
| `rooms-pass-1.md` | 逐房间用途检查 |
| `delivery.md` | 交付清单 |

---

## 10. 调试与工具

### 游戏内快捷键（仅调试版）
| 键 | 作用 |
|---|---|
| `R` | 回到检查点 |
| `Esc` | 暂停 |
| `F2` | 光衰减开关 |
| `F3` | 隐藏/显示调试面板 |
| `F4` | 重读 tuning |
| `F5` | 清空本章进度 |
| **`F6`** | **一键进真结局 boss 战**（12 人全救 + 直接进追逐段） |

### 探针（headless，输出到 stdout）
```powershell
& $G --headless --path . res://tools/probe_maze.tscn          # 迷宫可解性（拐弯数）
& $G --headless --path . res://tools/probe_mirror.tscn        # 镜子反射：reflecting/dir/range
& $G --headless --path . res://tools/probe_f6.tscn            # F6 的救援表
& $G --headless --path . res://tools/probe_doctor.tscn        # ch1 医生可见性
& $G --headless --path . res://tools/probe_bounce.tscn        # 反弹谜题
& $G --headless --path . res://tools/probe_title_states.tscn  # 标题页两种状态
```

### 截图（渲染 + 录帧 + PIL 裁剪）
```powershell
& $G --path . --rendering-driver opengl3 --write-movie .tmp_build/shots/f.png --fixed-fps 30 res://tools/shots_ch0.tscn
# 然后从 .tmp_build/shots/*.png 里挑帧
```

2026-11-10 新增：
- `tools/shots_tour.tscn -- <章>`：自动把小星放到这一章每个小人/镜子/影鬼/机关/出口旁边各录一组帧（不用手写坐标），
  镜头范围去掉了，小星永远在画面正中
- `tools/shots_feel.tscn`：用几种速度朝墙发射，录撞墙那几帧，看压扁/火花/顿挫
- `tools/shots_title_sway.tscn`：标题页鼠标视差——把鼠标放到中间/右边/左上各录一帧，
  从帧里量得出每层错开多少（星空 8 / 天际线 17 / 地面 25 / 路灯小人 36）
- `tools/shots_ending_comic.tscn`：真结局连环画的几个状态（第一页第一格 / 第二格 / 四格齐 / 第二页 / CG）
- `tools/comic_panels.py`：从四格漫画量出四格的多边形（打印成 `ending_comic.gd` 里的 `PANELS`），
  并把四格以外的部分刷黑生成 `N_black.png`（换图后重跑）
- `tools/level_report.py`：每章主路线俯视图 + 路线长度、直道、小人离路线多远、补给密度（`.tmp_build/report_<章>.png`）
- `tools/check_maps.py`：按小星半径查通行（ch1 那一遍现在把栅栏当实体）

---

## 11. 美术与音频

### 美术
- 管线：豆包出图 → 抠图/去底 → 放到 `assets/art/<类别>/` → `--import`。
- 程序生成的部分（改脚本重跑，再 `--import`）：
  - `tools/tile_art.py`：墙 / 边界墙 / 地面图集，郊区（ch0–ch2）和城市（ch3、ch4）两套，16 个四邻掩码 × 4 个变体。
    墙沿高光 + 遮光体内缩（`scripts/levels/wall_tiles.gd`）让光照亮墙沿；地面挨墙的边有接触阴影
  - `tools/sprite_art.py`：影鬼三张（原 `shade_aim.png` 没去底，是个黑方块）
  - 出口、黑洞、流星落地、软垫是 `_draw` 程序画的
- 代码里都是 `if ResourceLoader.exists(ART)`，**没有贴图就退化成几何绘制**，所以删图不会崩，只会变丑。
- 真结局连环画在 `assets/art/cg/`：`1.png`/`2.png`/`3.png` 是白底四格漫画（2047×1152），`CG.png` 是最后的 CG（1881×1254）。
  游戏里读的是 `1_black.png` 这类黑底版（脚本生成，不进手工流程）；换图后重跑 `tools/comic_panels.py`，
  把 `PANELS` 整段换掉，再 `--import`。
- 风格：暗色剪影 + 暖光，人物只要轮廓能看出职业。

### 音频
- `audio/*.wav`：原来 10 个 + `tools/sfx_synth.py` 合成的 22 个（清单见 `docs/audio-brief.md`）。
  `Audio.play`（普通）、`Audio.play_at`（带位置，1100 px 外不播）、`Audio.hold`（循环音，每帧续命，不续就淡出）。
  合成音效**只看过波形和频谱、没有人耳听过**，第一次跑游戏请先听一遍。
- `audio/bgm/*.wav`：9 首**本地合成的占位曲**（title / ch0..ch4 / chase / ending_normal / ending_hidden）。
- 替换方式：把 Suno 生成的曲子按同名覆盖（`.ogg` 优先于 `.wav`），**代码不用改**。
  `Audio.play_bgm` 会依次找 `.ogg` → `.wav`。

---

## 12. 已知问题 / 待办（按优先级）

1. **触屏/手柄未实机验证**：`Controls` 与 `tests/test_touch` 覆盖了布局，但没有真机手感验证。
2. **BGM 是占位曲**：需要真人用 Suno 生成后替换（清单见 `docs/bgm-status.md`）。
3. **难度切换要重进本章**才生效（有意为之，避免中途重排关卡）。
4. **长夜级"补给只在敌人身后"是近似实现**（300px 内算"身后"），因为敌人是固定炮台、没有明确朝向。
5. **`test_finale` 里迷宫被抹平**（`Game.debug_flat_maze`）：真实迷宫由 `probe_maze` 验。
   如果要让自动机跑真迷宫，需要先写一个更聪明的导航器（试过三轮都失败，见 `boss-maze-status.md`）。
6. **标题页视觉状态没有自动截图**：用 Node2D 包场景会得到 0 尺寸，需要把标题作为场景根才能截。
7. **`assets/art/items/star_bloom.png` 未使用**（有方块伪影，已弃用）。`items/exit.png`、`hazards/blackhole.png` 也不再用（改程序画）。
8. **散射光开阴影后 Web 上的帧率没实测**（2026-11-10）：本地只有软件渲染。卡的话先看 `star_light.gd` 的散射光阴影和出口的灯。

---

## 13. 接手验收清单

照着走一遍，确认环境没坏：

- [ ] `--import` 无报错
- [ ] `build_test_levels` 无报错（会重建 7 个关卡场景）
- [ ] 23 个测试全绿
- [ ] 导出 Web 成功，浏览器打开能进标题
- [ ] 标题页：小星绕圈飞、下面四个图标、右下角暗色名单图标
- [ ] 按 `F6` 直接进真结局 boss 战，12 人全救
- [ ] 设置面板（HUD 右上角齿轮）能调音量、能关
- [ ] ch1 医生房：走不进去，只能用聚光往上的镜子反射照亮医生

---

## 14. 约定（请保持）

- 画面上**不写字**（名单除外）；用图形表达。
- 没有必救的人；出口永远开着；没有屏内文字提示。
- 关卡数据只改 `tools/*.txt`，场景是生成物。
- 改动后跑全量测试；测试不过不要提交。
- 提交信息写清"改了什么 + 为什么"，中文即可。
