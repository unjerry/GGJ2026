extends Control
class_name TessManager

## 任务列表管理器
## 负责加载JSON数据并动态创建TaskRow实例

@export_file("*.json") var tasks_json_path: String = "res://data/tasks.json"
@export var row_scene: PackedScene  ## 在编辑器中关联row.tscn

# 存储任务行容器的引用（需要在场景中添加VBoxContainer）
@onready var rows_container: VBoxContainer = $ScrollContainer/VBoxContainer

# 存储已创建的行实例
var task_rows: Array[TaskRow] = []

func _ready() -> void:
	load_and_display_tasks()

## 加载JSON文件并创建任务行
func load_and_display_tasks() -> void:
	var tasks_data = load_tasks_from_json()
	if tasks_data.is_empty():
		print("没有任务数据可显示")
		return

	create_task_rows(tasks_data)

## 从JSON文件加载任务数据
## @return: 任务数据数组
func load_tasks_from_json() -> Array:
	# 检查文件是否存在
	if not FileAccess.file_exists(tasks_json_path):
		push_error("JSON文件不存在: " + tasks_json_path)
		return []

	# 打开并读取文件
	var file = FileAccess.open(tasks_json_path, FileAccess.READ)
	if file == null:
		push_error("无法打开文件: " + tasks_json_path + " 错误码: " + str(FileAccess.get_open_error()))
		return []

	var json_string = file.get_as_text()
	file.close()

	# 解析JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("JSON解析失败: " + json.get_error_message() + " 在行 " + str(json.get_error_line()))
		return []

	var data = json.get_data()

	# 验证数据结构
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JSON根节点必须是字典")
		return []

	if not data.has("tasks"):
		push_error("JSON中缺少'tasks'字段")
		return []

	if typeof(data["tasks"]) != TYPE_ARRAY:
		push_error("'tasks'字段必须是数组")
		return []

	print("成功加载 ", data["tasks"].size(), " 条任务数据")
	return data["tasks"]

## 创建任务行实例
## @param tasks_data: 任务数据数组
func create_task_rows(tasks_data: Array) -> void:
	# 清除现有行
	clear_task_rows()

	# 检查row_scene是否已设置
	if row_scene == null:
		push_error("row_scene未设置，请在编辑器中关联row.tscn")
		return

	# 为每个任务创建一行
	for task_data in tasks_data:
		if typeof(task_data) != TYPE_DICTIONARY:
			push_warning("跳过非字典类型的任务数据")
			continue

		# 实例化row场景
		var row_instance: TaskRow = row_scene.instantiate()

		# 设置数据
		row_instance.set_task_data(task_data)

		# 添加到容器
		rows_container.add_child(row_instance)

		# 保存引用
		task_rows.append(row_instance)

	print("创建了 ", task_rows.size(), " 个任务行")

## 清除所有任务行
func clear_task_rows() -> void:
	for row in task_rows:
		if is_instance_valid(row):
			row.queue_free()
	task_rows.clear()

## 重新加载任务数据（用于刷新）
func reload_tasks() -> void:
	load_and_display_tasks()

## 根据ID更新特定任务的状态
## @param task_id: 任务ID
## @param new_status: 新状态
func update_task_status(task_id: String, new_status: String) -> void:
	for row in task_rows:
		if row.get_task_id() == task_id:
			row.update_field("status", new_status)
			print("更新任务 ", task_id, " 状态为: ", new_status)
			return
	push_warning("未找到ID为 " + task_id + " 的任务")
