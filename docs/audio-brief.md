# 音乐 / 音效外包需求（给 AI 音频工具）

> 现状：10 个音效是我自己用代码合成的（44.1kHz 立体声），够用但不惊艳；
> **背景音乐完全没有**。这份文档是拿去给 AI 音频工具下单用的。

---

## 一、工具怎么选

| 用途 | 推荐 | 适合什么 | 注意 |
|---|---|---|---|
| **音效（SFX）** | **ElevenLabs Sound Effects** | 文字描述 → 1–3 秒的短音，撞击/碎裂/机械最准 | 免费额度少；付费档才有商用授权 |
| 音效 | **Stable Audio 2.x** | 能出 1–45 秒，音乐/音效都行，循环段落可用 | 需要明确"one-shot, no music" |
| 音效（自托管） | **AudioGen / AudioCraft** | 本地跑、免费、可批量 | 要 GPU；质量不如上面两个 |
| **背景音乐** | **Suno（Instrumental 模式）** | 2–4 分钟完整曲子，风格最像"人做的" | **免费档不能商用**，要买付费档 |
| 背景音乐 | **Udio** | 同上，编曲更细腻 | 同样注意商用授权 |
| 背景音乐（可商用） | **Soundraw / Beatoven.ai** | 直接给商用授权，能指定段落长度、循环导出 | 风格偏"配乐库"，没那么有个性 |
| 背景音乐（循环） | **Mubert** | 天生为循环/实时生成设计 | 适合做环境底噪 |

**我的建议**：
- **BGM 用 Suno 或 Soundraw**（先试 Suno，出不来再退 Soundraw 保商用）；
- **SFX 用 ElevenLabs Sound Effects**（补现在缺的 8 个）。

> 版本和授权条款可能变，下单前确认一下当前的商用许可。

---

## 二、背景音乐需求（9 段）

统一要求写在前头：

```text
instrumental（不要人声、不要和声人声）
无缝循环：首尾对齐到小节，循环点不要有鼓点收尾
时长：90 秒左右（标题/结局可以短一点）
响度：-16 LUFS，峰值不超过 -1 dBFS
不要重混响、不要大低频（游戏里音效要留空间）
```

| # | 用途 | 情绪 | 配器 | BPM | 时长 |
|---|---|---|---|---|---|
| 1 | **标题** | 安静、有点期待 | 钢琴单音 + 远处钟声 + 极轻的合成垫 | 60 | 60–90s 循环 |
| 2 | **ch0 星落**（郊区，最暗） | 孤独、克制 | 钢琴 + 低音提琴拨弦 + 风声 | 64 | 90s 循环 |
| 3 | **ch1 影藤**（郊区边缘） | 微微不安 | 钢琴 + 木琴 + 低音脉冲 | 70 | 90s 循环 |
| 4 | **ch2 镜面**（城郊） | 清澈、有点悬 | 玻璃质感音色 + 钢琴 + 稀疏电子点 | 76 | 90s 循环 |
| 5 | **ch3 裂纹**（城市） | 推进、有压力 | 低音 ostinato + 钢琴 + 轻微失真 | 84 | 90s 循环 |
| 6 | **ch4 双生**（城市中心） | 明亮、繁华底下是空 | 电钢琴 + 弦乐垫 + 城市环境声 | 88 | 90s 循环 |
| 7 | **终章追逐** | 紧张、不能停 | 低音脉冲 + 心跳鼓 + 高频颤音 | 120 | 60s 循环 |
| 8 | **结局·普通** | 释然、温暖 | 钢琴 + 弦乐渐强 + 钟 | 60 | 40s，不循环 |
| 9 | **结局·隐藏** | 悲壮、光芒 | 弦乐 + 铜管 + 合唱"啊"（可以是合成垫） | 72 | 40s，不循环 |

**风格基准**（写给 AI 的锚点）：

```text
warm minimal piano, music-box textures, soft analog pads,
distant city ambience, no drums except chase track,
similar to the mood of Journey / Gris / Inside soundtracks
```

---

## 三、音效需求

### 已经有的 10 个（想换更好的就换，规格照下表）

| 名字 | 场景 | 时长 | 质感 |
|---|---|---|---|
| `hit` | 撞墙 | 0.2–0.3s | 木头闷响，不要金属 |
| `break` | 裂纹墙碎 | 0.5–0.6s | 石头脆裂 + 碎屑 |
| `burn` | 影藤燃烧 | 0.6–0.8s | 热气 + 噼啪 |
| `warp` | 虫洞传送 | 0.4–0.5s | 上升的玻璃音 |
| `help` | 赛道帮助点 | 0.4–0.5s | 轻拨弦 |
| `rescue` | 小人得救 | 1.0–1.2s | 暖铃，有余韵 |
| `clear` | 过关 | 1.2–1.4s | 三音上行 |
| `death` | 阵亡 | **1.4s（必须）** | 冲击 + 消散的气声，尾巴要糊到 1.4 秒 |
| `boss` | 噬光者登场 | 1.5–1.8s | 低频威压，不要尖叫 |
| `ending` | 结局 | 2.4s | 暖色和弦铺开 |

> `death` 的 1.4 秒是硬要求：和消散动画同长，现在是 1.0 秒，动画还没播完声音就没了。

### 2026-11-10 补齐：程序合成的 22 个（`tools/sfx_synth.py`）

原来缺的 8 个和更多事件都补上了，全部由 `tools/sfx_synth.py` 用 numpy 合成（暖、轻、八音盒/玻璃质感，
没有金属尖响），想换真人做的就**同名覆盖** `audio/<名字>.wav` 再 `--import`，代码不用改。

| 名字 | 什么时候响 | 怎么播 |
|---|---|---|
| `bounce` | 阶段 3/4 弹墙 | 阶段 4 音高 ×1.12 |
| `smash` | 阶段 5 撞碎黑墙 | |
| `stop` | 撞软垫急停 | |
| `shard` | 捡小星星 | 1.4 秒内连着捡，按五声音阶一颗比一颗高 |
| `warn` / `gear` | 掉进阶段 2 的预警 / 升到 3、4、5 | |
| `focus` / `scatter` | 切聚光 / 切散射 | |
| `aim` / `shot` | 影鬼瞄准（按瞄准时间变调，开枪那一刻最高）/ 开枪 | 带位置 |
| `meteor_warn` / `meteor` | 流星预警（按预警时长变调）/ 落地 | 带位置 |
| `checkpoint` | 点亮检查点 | |
| `door` | 铁门打开 | 带位置 |
| `accel` | 加速带真的把你推快了 | |
| `ui` | 菜单按钮、设置面板 | |
| `heart` | 亮度低于 25%，越暗跳得越快 | |
| `cry` | 没救的人每 3 秒左右哭一声（藏着的人不哭） | 带位置，黑暗里循声找人 |
| `shield` | 守夜人的盾挡住噬光者 | |
| `wind`（循环） | 速度越快越响越尖 | `Audio.hold` |
| `wake`（循环） | 正在照醒小人，音高跟进度走 | 带位置 |
| `crackle`（循环） | 影藤正在烧 | 带位置 |

"带位置"= `Audio.play_at(id, pos)`：离镜头 1100 px 以外不播，近处按距离衰减、分左右声道。

### 原来列的"还缺的 8 个"（已由上表覆盖，留作给外包的规格参考）

| 名字 | 场景 | 时长 | 质感 |
|---|---|---|---|
| `accel` | 踩到加速带 | 0.3s | 短促的"呼"一声，方向感向上 |
| `shot` | 影鬼开枪 | 0.25s | 短、闷、有点电子味（不是枪声） |
| `meteor_warn` | 流星预警 | 0.8s | 低频嗡鸣 + 越来越急 |
| `meteor_hit` | 流星落地 | 0.6s | 闷响 + 碎石 |
| `checkpoint` | 检查点点亮 | 0.6s | 火柴擦着 + 轻微的回声 |
| `door` | 铁门升起 | 0.9s | 金属摩擦 + 落地 |
| `ui_click` | 按钮 | 0.12s | 极短的木头"嗒" |
| `deploy` | 加速带一路铺开 | 1.2s | 连续的点亮声，从近到远 |
| `shatter` | 撞碎影鬼 | 0.6s | 清脆的起音 + 一簇玻璃碎屑 + 往下散掉的虚空吸气（连击越高音越高） |

---

## 四、交付规格

```text
格式：BGM 用 ogg（vorbis，q5）或 wav；SFX 用 wav
采样：44100Hz / 16bit（立体声优先，单声道也行）
BGM 响度：-16 LUFS；SFX：峰值 -3 dBFS，不要做母带压限
命名：BGM → audio/bgm/<编号>_<名字>.ogg（如 02_ch0.ogg）
      SFX → 沿用 audio/<名字>.wav
循环：BGM 请在文件名里标 loop，并告诉我"循环点在第几秒"
交付：连同你用的提示词一起发我，方便下次补做同风格的
```

---

## 五、可以直接粘的提示词

### BGM 模板

```text
Instrumental only, no vocals. <情绪>。Warm minimal piano, music-box textures,
soft analog pad, distant ambience. <BPM> BPM. Seamless loop, ends cleanly on a bar,
no fade-out, no cymbal swell at the loop point. Around 90 seconds.
Similar mood to Journey / Gris / Inside soundtracks. Cinematic but intimate.
```

把 `<情绪>` 换成下表：

| 段 | 填什么 |
|---|---|
| 1 标题 | quiet, hopeful, waiting in the dark |
| 2 ch0 | lonely and restrained, a small light in a big night |
| 3 ch1 | quietly uneasy, something moving in the vines |
| 4 ch2 | clear and suspended, glass reflections |
| 5 ch3 | pushing forward, cracks spreading underfoot |
| 6 ch4 | bright on the surface, hollow underneath |
| 7 追逐 | urgent, relentless, do not look back |
| 8 结局普通 | relieved and warm, the night is over |
| 9 结局隐藏 | bittersweet and triumphant, a light that costs everything |

### SFX 模板

```text
One-shot sound effect, <质感>，<时长>，no music, no reverb tail longer than 200ms,
mono, 44.1kHz.
```

例：`One-shot sound effect, a wooden thud from a soft impact, 0.25 seconds, no music, no long reverb, mono, 44.1kHz.`
