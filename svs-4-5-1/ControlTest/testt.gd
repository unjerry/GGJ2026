extends Control

## testt.tscn 的测试脚本
## 加载 JSON 数据并动态创建任务行

# 内置配置文件路径（打包在游戏内）
const BUILTIN_JSON_PATH: String = "res://data/tasks.json"

# 外部配置文件相对路径（相对于 exe）
const EXTERNAL_JSON_RELATIVE_PATH: String = "data/tasks.json"

# 引用 row 场景
var row_scene: PackedScene = preload("res://system/tess/row/row.tscn")

# 容器引用
@onready var rows_container: VBoxContainer = $Control/VBoxContainer/Panel/ScrollContainer/VBoxContainer

# 存储已创建的行
var task_rows: Array = []

# 实际使用的 JSON 路径
var active_json_path: String = ""

func _ready() -> void:
	# 清除现有的示例行（HBoxContainer, HBoxContainer2, HBoxContainer3）
	clear_example_rows()

	# 加载并显示任务数据
	load_and_display_tasks()

## 清除示例行
func clear_example_rows() -> void:
	# 保留第一个 HBoxContainer（表头），删除其他的
	var children = rows_container.get_children()
	for i in range(children.size()):
		if i > 0:  # 跳过第一个（表头）
			children[i].queue_free()

## 加载并显示任务
func load_and_display_tasks() -> void:
	var tasks_data = load_tasks_from_json()
	if tasks_data.is_empty():
		print("没有任务数据可显示")
		return

	create_task_rows(tasks_data)

## 获取外部配置文件的完整路径（exe 同目录）
func get_external_json_path() -> String:
	var exe_path = OS.get_executable_path()
	var exe_dir = exe_path.get_base_dir()
	return exe_dir.path_join(EXTERNAL_JSON_RELATIVE_PATH)

## 确保外部配置文件存在（首次运行时复制）
func ensure_external_config_exists() -> void:
	var external_path = get_external_json_path()

	# 如果外部文件已存在，不需要复制
	if FileAccess.file_exists(external_path):
		return

	# 创建 data 目录
	var external_dir = external_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(external_dir):
		var err = DirAccess.make_dir_recursive_absolute(external_dir)
		if err != OK:
			push_error("无法创建目录: " + external_dir)
			return

	# 从内置文件复制到外部
	if FileAccess.file_exists(BUILTIN_JSON_PATH):
		var source_file = FileAccess.open(BUILTIN_JSON_PATH, FileAccess.READ)
		if source_file:
			var content = source_file.get_as_text()
			source_file.close()

			var dest_file = FileAccess.open(external_path, FileAccess.WRITE)
			if dest_file:
				dest_file.store_string(content)
				dest_file.close()
				print("📄 首次运行：已复制配置文件到 ", external_path)
			else:
				push_error("无法写入外部配置文件: " + external_path)

## 从 JSON 加载任务数据
func load_tasks_from_json() -> Array:
	var external_path = get_external_json_path()

	# 优先使用外部配置文件（exe 同目录）
	if FileAccess.file_exists(external_path):
		active_json_path = external_path
		print("📂 从外部配置加载: ", external_path)
	else:
		# 外部文件不存在，尝试从内置加载
		active_json_path = BUILTIN_JSON_PATH
		print("📦 从内置配置加载: ", BUILTIN_JSON_PATH)

		# 首次运行，复制配置文件到外部
		ensure_external_config_exists()

	# 检查文件是否存在
	if not FileAccess.file_exists(active_json_path):
		push_error("JSON文件不存在: " + active_json_path)
		return []

	var file = FileAccess.open(active_json_path, FileAccess.READ)
	if file == null:
		push_error("无法打开文件: " + active_json_path)
		return []

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("JSON解析失败: " + json.get_error_message())
		return []

	var data = json.get_data()

	if typeof(data) != TYPE_DICTIONARY or not data.has("tasks"):
		push_error("JSON格式错误")
		return []

	print("✅ 成功加载 ", data["tasks"].size(), " 条任务数据")
	return data["tasks"]

## 创建任务行
func create_task_rows(tasks_data: Array) -> void:
	for task_data in tasks_data:
		if typeof(task_data) != TYPE_DICTIONARY:
			continue

		# 实例化 row 场景
		var row_instance = row_scene.instantiate()

		# 设置数据
		row_instance.set_task_data(task_data)

		# 添加到容器
		rows_container.add_child(row_instance)

		# 保存引用
		task_rows.append(row_instance)

	print("✅ 创建了 ", task_rows.size(), " 个任务行")
