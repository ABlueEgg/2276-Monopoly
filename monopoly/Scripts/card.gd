extends Node2D

signal hovered
signal hovered_off

var position_in_hand
var card_slot_card_in_slot
var cardValue 
var cardColour 
# NEW: used by merge logic
var active_colour: String = ""   # set on drop (lowercased, e.g., "red")
var is_locked_in_set: bool = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#all cards must be a child of cardmanager or this errors
	get_parent().connect_card_signals(self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered",self)

func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off",self)

func setup(val, col):
	cardValue = val
	cardColour = col

func get_value():
	return cardValue

func get_colour():
	return cardColour
	
# NEW: helper to enable/disable dragging & hit test
func set_input_enabled(enable: bool) -> void:
	if has_node("Area2D"):
		$Area2D.input_pickable = enable
		if $Area2D.has_node("CollisionShape2D"):
			$Area2D/CollisionShape2D.disabled = not enable
