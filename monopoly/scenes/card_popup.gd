extends PopupPanel

@onready var description_label: Label = $Label
const PADDING = Vector2(20,20)

func _ready():
	gui_disable_input = true # Optional: prevents it from blocking mouse clicks
	unfocusable = true
	hide()

func set_description(text: String):
	description_label.text = text
	description_label.queue_redraw()
	var required_label_size = description_label.get_minimum_size()
	size = required_label_size + PADDING
	set_deferred("visible", true)
