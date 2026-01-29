extends Node2D

@export var cell_size: int = 64
@export var line_width: float = 1.0
@export var line_color: Color = Color(1, 1, 1, 0.1)

func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	var w := int(size.x)
	var h := int(size.y)

	for x in range(0, w, cell_size):
		draw_line(Vector2(x, 0), Vector2(x, h), line_color, line_width)
	for y in range(0, h, cell_size):
		draw_line(Vector2(0, y), Vector2(w, y), line_color, line_width)

func _process(_delta: float) -> void:
	queue_redraw() # ← Godot 4 用这个重绘
