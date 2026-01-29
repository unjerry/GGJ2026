extends Control

var money := 0

@onready var money_label: Label = $"../Label"
@onready var add_button: Button = $"."

func _ready():
	add_button.pressed.connect(on_add_pressed)
	update_ui()

func on_add_pressed():
	money += 1
	update_ui()

func update_ui():
	money_label.text = "Money: %d" % money
