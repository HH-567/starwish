extends Node
## 进度：当前章节和检查点、已救的人和他们的职业、等邮差的人、已碎、已烧、看过的结局
## （docs/level-data-format.md 第 5 节）。内存里这一份是准的；Game 在到达检查点、救人、通关、
## 看完结局时调 write() 写进 user://save.json（Web 上落在浏览器的 IndexedDB）。

const VERSION := 2

## 存档文件。测试换成别的文件，免得动到玩家的存档。
var path := "user://save.json"
## 当前章节的 chapter_id，空 = 还没开始或已经看完结局。
var chapter := ""
## 当前检查点的 save_id，空 = PlayerStart。
var checkpoint := ""
## save_id → 职业。
var rescued: Dictionary[String, StringName] = {}
## 照不到、等邮差的人：save_id → 职业。在自己那章加载时登记。
var mail: Dictionary[String, StringName] = {}
var broken: Dictionary[String, bool] = {}
var burnt: Dictionary[String, bool] = {}
## 看过的结局：main、hidden。新游戏也不清。
var endings: Dictionary[String, bool] = {}

## 清掉这一局的进度，看过的结局留着。
func clear() -> void:
	chapter = ""
	checkpoint = ""
	rescued.clear()
	mail.clear()
	broken.clear()
	burnt.clear()

func exists() -> bool:
	return FileAccess.file_exists(path)

func write() -> void:
	var data := {
		"version": VERSION,
		"chapter": chapter,
		"checkpoint": checkpoint,
		"rescued": rescued,
		"mail": mail,
		"broken": broken.keys(),
		"burnt": burnt.keys(),
		"endings": endings,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("存档写不进去：%s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))

## 读存档。没有文件、读不懂或版本对不上，就当作没有存档（结局记录也一起丢掉）。
func read() -> void:
	clear()
	endings.clear()
	if not exists():
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var data: Variant = json.data
	if not data is Dictionary or data.get("version") != VERSION:
		return
	chapter = data.get("chapter", "")
	checkpoint = data.get("checkpoint", "")
	for id in data.get("rescued", {}):
		rescued[id] = StringName(data["rescued"][id])
	for id in data.get("mail", {}):
		mail[id] = StringName(data["mail"][id])
	for id in data.get("broken", []):
		broken[id] = true
	for id in data.get("burnt", []):
		burnt[id] = true
	for key in data.get("endings", {}):
		endings[key] = data["endings"][key] == true

## 这个职业有没有人被救。帮助都按职业查。
func has_role(role: StringName) -> bool:
	return rescued.values().has(role)

## node 所在的章节根（chapter 组里带 chapter_id 的节点），不在章节里时返回 null。
func chapter_of(node: Node) -> Node:
	var n := node
	while n != null and not n.is_in_group(&"chapter"):
		n = n.get_parent()
	return n

## save_id = <chapter_id>/<从章节根到该节点的路径>。章节根是 chapter 组里带 chapter_id 的节点。
## 只顺着父节点拼名字，节点不在场景树里也能用。
func id_of(node: Node) -> String:
	var names := PackedStringArray()
	var n := node
	while n != null and not n.is_in_group(&"chapter"):
		names.insert(0, n.name)
		n = n.get_parent()
	if n == null:
		return "/".join(names)
	return "%s/%s" % [n.get("chapter_id"), "/".join(names)]
