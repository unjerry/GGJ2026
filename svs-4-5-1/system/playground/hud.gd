extends CanvasLayer

@onready var info: Label = $Info
@export var zombie_path: NodePath

func _process(_delta: float) -> void:
	var z := get_node_or_null(zombie_path)
	if z and z is CharacterBody2D:
		var body := z as CharacterBody2D
		var v: Vector2 = body.velocity
		info.text = "pos: (%.0f, %.0f)\nvel: (%.1f, %.1f)\nfps: %d" % [
			body.global_position.x, body.global_position.y, v.x, v.y, Engine.get_frames_per_second()
		]
