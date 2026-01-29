extends CharacterBody2D

@export var base_speed: float = 30.0
@export var speed_factor: float = 1.0 # ← 动画来改它（0/1/脉冲）
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var sm: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var front_probe: RayCast2D = $FrontProbe
@export var bite_damage: int = 20

func _ready() -> void:
	pass

func _physics_process(_delta: float) -> void:
	velocity.x = base_speed * speed_factor
	move_and_slide()

func bite() -> void:
	# 被 attack 动画的方法轨在关键帧调用
	var target := front_probe.get_collider()
	if target and target.has_method("apply_damage"):
		target.apply_damage(bite_damage)
