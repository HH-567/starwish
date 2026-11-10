# Linux / WSL 下的 HANDOFF 第 3 节五条命令。用法：在工程根目录 `source tools/dev.sh`，然后：
#   gd_import          重新导入（改了脚本/资源/class_name/PNG/WAV 之后）
#   gd_build           地图 → 关卡场景（改了 tools/*_map.txt 之后必须跑）
#   gd_test test_ch0   跑一个测试
#   gd_all             跑全部测试，日志在 .tmp_build/logs/
#   gd_export          导出 Web 到 build/index.html
#   gd_shots ch1       截图巡游：.tmp_build/shots/ch1/ 里每个"有东西"的地方一组帧（要 xvfb-run）
# Linux 上 user:// 在 XDG_DATA_HOME 下：指到 .tmp_build 里，测试就不会读写真实存档（等价于 Windows 的 APPDATA）。
# 导出模板仍用全局的（~/.local/share/godot/export_templates），软链接过去。
# 可以用环境变量 G 指定 Godot 可执行文件，默认 ~/.local/bin/godot。

export G="${G:-$HOME/.local/bin/godot}"
export XDG_DATA_HOME="$PWD/.tmp_build/xdg/data"
export XDG_CONFIG_HOME="$PWD/.tmp_build/xdg/config"
mkdir -p "$XDG_DATA_HOME/godot" "$XDG_CONFIG_HOME" .tmp_build/logs .tmp_build/shots
[ -e "$XDG_DATA_HOME/godot/export_templates" ] || ln -s "$HOME/.local/share/godot/export_templates" "$XDG_DATA_HOME/godot/export_templates"

gd_import() { "$G" --headless --path . --import; }
gd_build() { "$G" --headless --path . 'res://tools/build_test_levels.tscn'; }
gd_test() { timeout "${T:-300}" "$G" --headless --path . --fixed-fps 60 "res://tests/$1.tscn"; }
gd_all() {
	local fail=0 t rc r
	for f in tests/*.tscn; do
		t=$(basename "$f" .tscn)
		gd_test "$t" > ".tmp_build/logs/$t.log" 2>&1
		rc=$?
		r=$(grep -a 'RESULT' ".tmp_build/logs/$t.log" | tail -1)
		printf '%-22s rc=%-3s %s\n' "$t" "$rc" "$r"
		[ $rc -ne 0 ] && fail=$((fail + 1))
	done
	echo "FAILED: $fail"
}
gd_export() { mkdir -p build; "$G" --headless --path . --export-release 'Web' 'build/index.html'; }
gd_shots() {
	local d=".tmp_build/shots/$1"
	mkdir -p "$d"
	xvfb-run -a -s "-screen 0 1280x720x24" "$G" --path . --rendering-driver opengl3 \
		--write-movie "$d/f.png" --fixed-fps 30 "${2:-res://tools/shots_tour.tscn}" -- "$1" | grep -a '^SHOT'
}
