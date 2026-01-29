extends CanvasLayer
class_name SolarStorage

## Solar energy storage that receives sun contributions and displays UI
## Reusable module with UI - instantiate in game scenes

@export var initial_sun: int = 50  ## Starting sun amount

var current_sun: int = 0

signal sun_changed(new_amount: int)

@onready var sun_label: Label = $SunDisplay/Panel/HBoxContainer/SunLabel

func _ready():
	current_sun = initial_sun
	_update_display()
	print("SolarStorage initialized with ", current_sun, " sun")

func add_sun(amount: int) -> void:
	"""Add sun energy to storage"""
	current_sun += amount
	sun_changed.emit(current_sun)
	_update_display()
	print("Sun collected! Current sun: ", current_sun, " (+", amount, ")")

func spend_sun(amount: int) -> bool:
	"""Attempt to spend sun energy. Returns true if successful"""
	if current_sun >= amount:
		current_sun -= amount
		sun_changed.emit(current_sun)
		_update_display()
		print("Sun spent! Current sun: ", current_sun, " (-", amount, ")")
		return true
	else:
		print("Not enough sun! Need ", amount, " but only have ", current_sun)
		return false

func get_current_sun() -> int:
	"""Get current sun amount"""
	return current_sun

func set_sun(amount: int) -> void:
	"""Set sun to specific amount (for initialization/cheats)"""
	current_sun = amount
	sun_changed.emit(current_sun)
	_update_display()

func _update_display() -> void:
	"""Update UI to show current sun amount"""
	if sun_label:
		sun_label.text = str(current_sun)

func get_collection_target_position() -> Vector2:
	"""Get the world position where suns should fly to when collected
	Converts screen-space (CanvasLayer) position to world-space position
	accounting for camera position and zoom"""

	# Get screen position from CollectionTarget or fallback
	var screen_pos: Vector2
	if has_node("CollectionTarget"):
		screen_pos = get_node("CollectionTarget").global_position
	elif sun_label:
		screen_pos = sun_label.global_position
	else:
		screen_pos = Vector2(50, 20)  # Safe fallback

	# Convert screen-space to world-space
	var viewport = get_viewport()
	if viewport:
		var camera = viewport.get_camera_2d()
		if camera:
			# Get viewport size
			var viewport_size = viewport.get_visible_rect().size

			# Calculate offset from viewport center
			var offset_from_center = screen_pos - viewport_size / 2

			# Convert to world position: camera position + offset scaled by zoom
			var world_pos = camera.global_position + offset_from_center / camera.zoom
			return world_pos

	# Fallback if no camera (shouldn't happen in normal gameplay)
	return screen_pos
