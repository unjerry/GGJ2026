extends Control

## testt.tscn 的测试脚本
## 加载 JSON 数据并动态创建任务行

@export_file("*.json") var tasks_json_path: String = "res://data/tasks.json"

# 引用 row 场景
var row_scene: PackedScene = preload("res://system/tess/row/row.tscn")

# 容器引用
@onready var rows_container: VBoxContainer = $Control/Panel/VBoxContainer

# 存储已创建的行
var task_rows: Array = []

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

## 从 JSON 加载任务数据
func load_tasks_from_json() -> Array:
	if not FileAccess.file_exists(tasks_json_path):
		push_error("JSON文件不存在: " + tasks_json_path)
		return []

	var file = FileAccess.open(tasks_json_path, FileAccess.READ)
	if file == null:
		push_error("无法打开文件: " + tasks_json_path)
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
