extends HBoxContainer
class_name TaskRow

## 任务行UI组件，用于显示单条任务数据
## 从父容器接收数据字典并更新所有Label

# 缓存所有Label节点引用
@onready var label_id: Label = $Label2
@onready var label_name: Label = $Label3
@onready var label_faction: Label = $Label
@onready var label_type: Label = $Label4
@onready var label_difficulty: Label = $Label5
@onready var label_reward: Label = $Label6
@onready var label_duration: Label = $Label7
@onready var label_status: Label = $Label8

# 存储当前任务数据
var task_data: Dictionary = {}

func _ready() -> void:
	# 如果有初始数据，则显示
	if not task_data.is_empty():
		_update_labels()

## 设置任务数据并更新UI
## @param data: 包含任务信息的字典
func set_task_data(data: Dictionary) -> void:
	task_data = data
	if is_node_ready():
		_update_labels()

## 内部方法：更新所有Label文本
func _update_labels() -> void:
	label_id.text = task_data.get("id", "")
	label_name.text = task_data.get("name", "")
	label_faction.text = task_data.get("faction", "")
	label_type.text = task_data.get("type", "")
	label_difficulty.text = task_data.get("difficulty", "")
	label_reward.text = task_data.get("reward", "")
	label_duration.text = task_data.get("duration", "")
	label_status.text = task_data.get("status", "")

## 获取当前任务ID（便于外部引用）
func get_task_id() -> String:
	return task_data.get("id", "")

## 更新单个字段（用于动态更新状态等）
func update_field(field_name: String, value: String) -> void:
	if task_data.has(field_name):
		task_data[field_name] = value
		_update_labels()
