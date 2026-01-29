extends Plant

@onready var front_probe: RayCast2D = $FrontProbe
@export var pea_scene: PackedScene

func shoot() -> void:
	if pea_scene == null:
		return
	var pea = pea_scene.instantiate()
	get_parent().add_child(pea) # 或者合适的容器节点
	pea.global_position = $shoot_point.global_position
