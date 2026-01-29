extends CharacterBody2D

@export var life: int = 300
@onready var label: Label = $Label

@export var base_speed: float = 30.0
@export var speed_factor: float = 1.0 # ← 动画来改它（0/1/脉冲）
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var sm: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var front_probe: RayCast2D = $FrontProbe
@export var bite_damage: int = 20

func _ready() -> void:
	_refresh()

func _physics_process(_delta: float) -> void:
	velocity.x = - base_speed * speed_factor
	move_and_slide()

func bite() -> void:
	# 被 attack 动画的方法轨在关键帧调用
	if front_probe.is_colliding():
		var target := front_probe.get_collider()
		if target and target.has_method("apply_damage"):
			target.apply_damage(bite_damage)

func apply_damage(amount: int) -> void:
	life = max(life - amount, 0)
	_refresh()
	if life == 0:
		queue_free() # 血空就消失
		
func _refresh() -> void:
	if is_instance_valid(label):
		label.text = str(life)
