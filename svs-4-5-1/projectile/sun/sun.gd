extends Area2D

## Reusable sun collectible that can be produced by Sunflower, Sky, etc.
## Animation-driven pattern: Click sets flag, StateMachine handles everything
## Uses speed_factor pattern (like zombie/pea) for animation-driven movement

signal collected(sun_value: int)  ## Emitted when sun is clicked/collected

@export var sun_value: int = 25  ## How much sun energy this provides
@export var solar_storage: NodePath  ## Path to SolarStorage node (set per scene for modularity)
@export var collection_speed: float = 200.0  ## Movement speed in pixels per second
@export var speed_factor: float = 0.0  ## Animation controls this (0.0 to 1.0)
@export var is_collecting: bool = false  ## StateMachine watches this for auto-transition

var storage_node: Node = null
var target_position: Vector2 = Vector2.ZERO
var is_moving_to_target: bool = false

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var sm: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")

func _ready():
	# Get reference to storage node if path is set
	if solar_storage:
		storage_node = get_node_or_null(solar_storage)
		if storage_node == null:
			push_warning("Sun: solar_storage path is set but node not found: ", solar_storage)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		_collect()

func _collect() -> void:
	# Just flip the flag - StateMachine and animation handle everything!
	is_collecting = true

func _physics_process(delta: float) -> void:
	if is_moving_to_target and speed_factor > 0:
		var direction = global_position.direction_to(target_position)
		var distance = global_position.distance_to(target_position)

		if distance < 2.0:  # Close enough - arrived at target
			global_position = target_position
			is_moving_to_target = false
			speed_factor = 0.0
		else:
			# Move toward target: animation controls speed via speed_factor
			global_position += direction * collection_speed * speed_factor * delta

# Called by animation method track at start of "collect" animation
func _start_fly_to_storage() -> void:
	# Emit signal for event-driven listeners
	collected.emit(sun_value)

	# Set target position and start moving (animation controls speed_factor)
	if storage_node and storage_node.has_method("get_collection_target_position"):
		target_position = storage_node.get_collection_target_position()
		is_moving_to_target = true

	# Add sun to storage
	if storage_node and storage_node.has_method("add_sun"):
		storage_node.add_sun(sun_value)

	# TODO: 播放收集音效

# Note: queue_free() is called by animation method track, not here!
