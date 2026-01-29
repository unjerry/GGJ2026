extends StaticBody2D
class_name Plant # 注册为全局类名（可在编辑器中直接选）

@export var life: int = 100
@onready var label: Label = $Label

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if is_instance_valid(label):
		label.text = str(life)

func apply_damage(amount: int) -> void:
	life = max(life - amount, 0)
	_refresh()
	if life == 0:
		queue_free() # 血空就消失

func die() -> void:
	queue_free()
