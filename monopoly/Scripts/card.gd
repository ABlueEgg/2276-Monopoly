extends Node2D

signal hovered
signal hovered_off

var position_in_hand
var card_in_slot
var cardValue 
var cardColour 
var cardName = "" 
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#all cards must be a child of cardmanager or this errors
	if get_parent().has_method("connect_card_signals"):
		get_parent().connect_card_signals(self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered",self)

func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off",self)

func setup(val, col, c_name):
	cardValue = val
	cardColour = col
	cardName = c_name

func get_value():
	return cardValue

func get_colour():
	return cardColour
