extends HBoxContainer
class_name TaskRow

## 任务行UI组件，用于显示单条任务数据
## 从父容器接收数据字典并更新所有Label

# 信号：任务被接受时发出
signal task_accepted(task_id: String)

# 缓存所有Label/Button节点引用
@onready var label_id: Label = $Label2
@onready var label_name: Label = $Label3
@onready var label_faction: Label = $Label
@onready var label_type: Label = $Label4
@onready var label_difficulty: Label = $Label5
@onready var label_reward: Label = $Label6
@onready var label_duration: Label = $Label7
@onready var button_status: Button = $Label8  # 状态按钮

# 存储当前任务数据
var task_data: Dictionary = {}

# 倒计时时间（秒），用于显示"执行中 XX:XX"
var remaining_time: float = 0.0
var is_task_running: bool = false

func _ready() -> void:
	# 连接按钮点击事件
	if button_status:
		button_status.pressed.connect(_on_status_button_pressed)

	# 如果有初始数据，则显示
	if not task_data.is_empty():
		_update_labels()

func _process(delta: float) -> void:
	# 如果任务正在执行，更新倒计时显示
	if is_task_running and remaining_time > 0:
		remaining_time -= delta
		if remaining_time < 0:
			remaining_time = 0
		_update_status_button()

## 设置任务数据并更新UI
## @param data: 包含任务信息的字典
func set_task_data(data: Dictionary) -> void:
	task_data = data

	# 解析倒计时时间（如果有）- 支持新旧格式
	if data.has("remaining_seconds"):
		remaining_time = float(data.get("remaining_seconds", 0))
	elif data.has("remaining_time"):
		remaining_time = float(data.get("remaining_time", 0))
	elif data.get("status", "") == "进行中":
		# 如果状态是进行中但没有剩余时间，从duration解析
		remaining_time = _parse_duration_to_seconds(data.get("duration", ""))

	if is_node_ready():
		_update_labels()

## 内部方法：更新所有Label文本
func _update_labels() -> void:
	label_id.text = task_data.get("id", "")
	label_name.text = task_data.get("name", "")
	label_faction.text = task_data.get("faction", "")
	label_type.text = task_data.get("type", "")
	label_difficulty.text = task_data.get("difficulty", "")

	# 处理奖励显示 - 支持新旧格式
	var rewards = task_data.get("rewards", {})
	if rewards is Dictionary and not rewards.is_empty():
		# 新格式：字典形式的多资源奖励
		var reward_text = ""
		for res_name in rewards:
			if reward_text != "":
				reward_text += " "
			reward_text += str(rewards[res_name])
		label_reward.text = reward_text
	else:
		# 旧格式：字符串
		label_reward.text = task_data.get("reward", "")

	label_duration.text = task_data.get("duration", "")

	# 更新状态按钮
	_update_status_button()

## 更新状态按钮的显示
func _update_status_button() -> void:
	var status = task_data.get("status", "")

	match status:
		"可接取":
			button_status.text = "接受"
			button_status.disabled = false
			is_task_running = false

		"进行中":
			# 显示倒计时
			var time_str = _format_time(remaining_time)
			button_status.text = "执行中 " + time_str
			button_status.disabled = true
			is_task_running = true

		"已完成", "锁定", _:
			# 其他状态显示原状态名，按钮禁用
			button_status.text = status
			button_status.disabled = true
			is_task_running = false

## 按钮点击事件处理
func _on_status_button_pressed() -> void:
	var status = task_data.get("status", "")

	if status == "可接取":
		# 接受任务，改为进行中
		task_data["status"] = "进行中"

		# 设置倒计时时间
		if remaining_time <= 0:
			remaining_time = _parse_duration_to_seconds(task_data.get("duration", "15分钟"))

		# 更新UI
		_update_status_button()

		# 发出信号
		task_accepted.emit(get_task_id())
		print("任务 ", get_task_id(), " 已接受，开始执行")

## 解析时长字符串为秒数（如"15分钟" -> 900）
func _parse_duration_to_seconds(duration_str: String) -> float:
	# 简单解析，支持 "XX分钟" 格式
	if duration_str.ends_with("分钟"):
		var num_str = duration_str.replace("分钟", "").strip_edges()
		return float(num_str) * 60.0
	return 600.0  # 默认10分钟

## 格式化秒数为 MM:SS 格式
func _format_time(seconds: float) -> String:
	var total_seconds = int(seconds)
	var minutes = int(total_seconds / 60)
	var secs = total_seconds % 60
	return "%02d:%02d" % [minutes, secs]

## 获取当前任务ID（便于外部引用）
func get_task_id() -> String:
	return task_data.get("id", "")

## 更新单个字段（用于动态更新状态等）
func update_field(field_name: String, value: String) -> void:
	if task_data.has(field_name):
		task_data[field_name] = value
		_update_labels()
