# 交付与自检清单

一个人接手的项目，先看这一页。工具链、跑法、当前状态都在这里；规则细节看
[关卡与数据格式](level-data-format.md) 和 [状态机](state-machines.md)。

## 引擎

工程按 **Godot 4.7** 写（`project.godot` 里 `config/features` 是 4.7）。本机放了两套：

- `C:\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe` —— **用这个**。console 版才拿得到 stdout。
- `Desktop\环境检查\tools\godot\Godot_v4.3-stable_*` —— 4.3，打不开这个工程（类型化 Dictionary 之类的 4.4+ 语法）。别拿它排查。

加新的 `class_name` 之后要先跑一次 `--headless --import` 刷新 `.godot/global_script_class_cache.cfg`，
否则引用它的脚本会报 "Could not find type"。导入了新的 wav 也一样；如果那个 autoload 自己在解析期
引用了还没导入的文件，先临时关掉自加载导入一次。

## 每轮改动后的闭环

```powershell
$G = 'C:\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'

# 1. 改过地图/场景：重新生成（改 tools/*.txt，不要手改 .tscn）
& $G --headless --path . res://tools/build_test_levels.tscn

# 2. 改过地图：像素级连通性（含五段回程赛道能不能从头跑到尾）
python tools/check_maps.py

# 3. 无头测试，退出码 0 才算过
& $G --headless --path . --fixed-fps 60 res://tests/test_ch0.tscn
# ……test_ch1 / ch2 / ch3 / ch4 / full / audio / touch / hazards / flow / finale
#   还有 test_save / test_light / test_light_level / test_collisions / test_boss / test_level_smoke
```

测试清单（16 个场景，脚本都在 `tests/` 里，头两行写明这条测试查什么）：

| 测试 | 查什么 |
|---|---|
| test_ch0–test_ch4 | 每一章的机制、救人、检查点、出口，以及这一章赛道的接线 |
| test_hazards | 流星砸中/圈外不砸、黑洞吸引且越近越强 |
| test_full | 章节表正好 12 人、职业不重不漏、全救出后终章的科学家和掉头虫洞出现 |
| test_flow | 标题 → 各章 → 终章 → 正常结局的整条流程（按章节表跑，加章节不用改） |
| test_finale | 终章的多段拼接、帮助、复活、两个结局的机制 |
| test_audio / test_touch | 音效接线与冷却；触屏摇杆、光按钮、切回键鼠 |
| test_save / test_light / test_light_level / test_collisions / test_boss | 存档格式、光、测试关通关、撞击表、噬光者 |
| test_level_smoke | 两张测试关的冒烟（按右 2 秒，看有没有报错） |

## 导出 Web

```powershell
& $G --headless --path . --export-release 'Web' 'build/index.html'
```

产物在 `build/`（不进版本库）。**导出成功不等于能玩**：要在浏览器里真的打开一次。
本机沙箱里浏览器起不来（Edge 报 `mojo platform_channel: 拒绝访问`），当前只做到
"用 Godot 挂载导出的 index.pck 跑一遍标题场景、无脚本错误"这一步。换一台能开浏览器的机器补：

```powershell
python -m http.server 8099 --directory build --bind 127.0.0.1
# 然后 http://127.0.0.1:8099/index.html ，开控制台看 console/errors
```

音频要等第一次点击/按键（浏览器策略），触屏设备上会自动出摇杆。

## 现在的状态（2026-11-03）

- 正式章节 ch0–ch4 全部完成并接进 `CHAPTERS`，测试关只留在 `tests/` 里当样本。
- 五段回程赛道 + 终章首尾相接，`test_full` 验证 12 人齐时科学家出现。
- 音频十个音效、触屏控件、P2 的流星和黑洞都做了。
- 还没做的：美术资源（`docs/art-requests.md` 里全是可以一直用占位的），以及浏览器里的那次实测。
