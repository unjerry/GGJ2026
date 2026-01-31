extends HBoxContainer
class_name TaskRow

## 任务行UI组件，用于显示单条任务数据
## 从父容器接收数据字典并更新所有Label

# 信号：任务被接受时发出（携带任务ID和冒险家ID）
signal task_accepted(task_id: String, adventurer_id: String)

# 缓存所有Label/Button节点引用
@onready var label_id: Label = $Label2
@onready var label_name: Label = $Label3
@onready var label_faction: Label = $Label
@onready var label_type: Label = $Label4
@onready var label_difficulty: Label = $Label5
@onready var label_reward: Label = $Label6
@onready var label_duration: Label = $Label7
@onready var button_status: Button = $Label8  # 状态按钮

# 冒险家选择器（动态创建）
var adventurer_selector: OptionButton = null

# 存储当前任务数据
var task_data: Dictionary = {}

# 倒计时时间（秒），用于显示"执行中 XX:XX"
var remaining_time: float = 0.0
var is_task_running: bool = false

func _ready() -> void:
	# 创建冒险家选择器（在状态按钮之前插入）
	_create_adventurer_selector()

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
		_update_adventurer_selector()  # 更新冒险家选择器

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

		# 获取选中的冒险家ID
		var selected_adventurer_id = ""
		if adventurer_selector and adventurer_selector.selected >= 0:
			selected_adventurer_id = adventurer_selector.get_item_metadata(adventurer_selector.selected)
			if selected_adventurer_id == null:
				selected_adventurer_id = ""

		# 更新UI
		_update_status_button()

		# 发出信号（携带冒险家ID）
		task_accepted.emit(get_task_id(), selected_adventurer_id)
		print("任务 ", get_task_id(), " 已接受，冒险家: ", selected_adventurer_id if selected_adventurer_id != "" else "自动分配")

## 解析时长字符串为秒数（如"15分钟" -> 900，"5000毫秒" -> 5.0）
func _parse_duration_to_seconds(duration_str: String) -> float:
	if duration_str.ends_with("毫秒"):
		var num_str = duration_str.replace("毫秒", "").strip_edges()
		return float(num_str) / 1000.0  # 毫秒转秒
	elif duration_str.ends_with("秒"):
		var num_str = duration_str.replace("秒", "").strip_edges()
		return float(num_str)
	elif duration_str.ends_with("分钟"):
		var num_str = duration_str.replace("分钟", "").strip_edges()
		return float(num_str) * 60.0
	return 60.0  # 默认1分钟

## 格式化秒数为合适的显示格式（毫秒/秒/MM:SS）
func _format_time(seconds: float) -> String:
	if seconds < 1.0:
		# 小于1秒，显示毫秒
		var millis = int(seconds * 1000)
		return str(millis) + "ms"
	elif seconds < 60.0:
		# 小于60秒，显示秒.小数
		return "%.1fs" % seconds
	else:
		# 超过60秒，显示 MM:SS
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

## 创建冒险家选择器
func _create_adventurer_selector() -> void:
	# 创建 OptionButton
	adventurer_selector = OptionButton.new()
	adventurer_selector.custom_minimum_size = Vector2(150, 0)
	adventurer_selector.tooltip_text = "选择执行此任务的冒险家"
	adventurer_selector.visible = false  # 初始隐藏

	# 将选择器插入到状态按钮之前
	if button_status:
		var status_btn_index = button_status.get_index()
		add_child(adventurer_selector)
		move_child(adventurer_selector, status_btn_index)

## 更新冒险家选择器
func _update_adventurer_selector() -> void:
	if not adventurer_selector:
		return

	var status = task_data.get("status", "")

	# 只有"可接取"状态才显示选择器
	if status == "可接取":
		adventurer_selector.visible = true
		adventurer_selector.clear()

		# 添加"自动分配"选项
		adventurer_selector.add_item("自动分配", 0)
		adventurer_selector.set_item_metadata(0, "")

		# 获取可用冒险家列表
		var available_adventurers = _get_available_adventurers()

		var idx = 1
		for adv in available_adventurers:
			var adv_name = adv.get("name", "")
			var adv_id = adv.get("id", "")
			var adv_class = adv.get("class", "")

			# 显示：名字 (职业)
			var display_text = "%s (%s)" % [adv_name, adv_class]
			adventurer_selector.add_item(display_text, idx)
			adventurer_selector.set_item_metadata(idx, adv_id)
			idx += 1

		# 默认选择"自动分配"
		adventurer_selector.selected = 0
	else:
		# 非可接取状态，隐藏选择器
		adventurer_selector.visible = false

## 获取可用冒险家列表（从父节点的 GameManager 获取）
func _get_available_adventurers() -> Array:
	# 通过场景树向上查找 GameManager
	var root = get_tree().root
	var main_scene = root.get_child(root.get_child_count() - 1)

	# 查找 game_manager 节点
	var game_manager = main_scene.get_node_or_null("GameManager")
	if game_manager == null:
		print("⚠️ 未找到 GameManager")
		return []

	# 调用 GameManager 的方法获取可用冒险家
	if game_manager.has_method("get_available_adventurers"):
		return game_manager.get_available_adventurers()

	return []
