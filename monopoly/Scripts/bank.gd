extends Node2D
#Signal to update UI labels
signal bank_value_changed(new_total)

# Keep track of bank cards
var bank_cards := []
var total_value: int = 0 

# Visual stacking settings
const OFFSET = Vector2(5, -5)
const CARD_SCALE = 0.8
const TWEEN_TIME = 0.2
const TARGET_POS = Vector2(97, 972)

func _ready():
	# Ensure everything is visible
	visible = true
	var sprite = $Sprite2D
	if sprite:
		sprite.visible = true
		sprite.z_index = 10
		# Don't override scale 
	else:
		push_warning("Sprite2D not found in bank scene")
	position = TARGET_POS
	
	#Find the label and set its text directly
	var label = $BankLabel
	if label:
		label.text = str(total_value) + "M"
	else:
		push_warning("BankLabel node not found in Bank scene!")
	#emit the signal on start to set any UI Labels to 0

func add_card_to_bank(card: Node2D) -> void:
	if card == null:
		return
		# start 
	if card.has_method("get_value"):
		var value = card.get_value()
		# if we don't have value or it is greater than 0
		if value != null and value > 0:
			total_value += value
			#update the label text
			var label = $BankLabel
			if label:
				label.text = str(total_value) + "M"
			bank_value_changed.emit(total_value)
			print("Bank: Card added. New total : " + str(total_value) + "M")
	bank_cards.append(card)
	# Disable collisions
	# This is visual logic from here
	var area = card.get_node_or_null("Area2D/CollisionShape2D")
	if area:
		area.disabled = true
	# Capture the card's global position BEFORE reparenting
	var prev_global_pos = card.global_position
	# Reparent under bank slot
	if card.get_parent():
		card.get_parent().remove_child(card)
	add_child(card)
	# Restore card's visual position in world space
	card.global_position = prev_global_pos
	# Scale card appropriately
	card.scale = Vector2(0.8, 0.8)
	# Compute *local* position offset for stacking (not global)
	var local_target_pos = OFFSET * (bank_cards.size() - 1)
	# Animate card to local pile position
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", local_target_pos, TWEEN_TIME)
	tween.tween_property(card, "z_index", bank_cards.size(), TWEEN_TIME)

#Helper function
func get_total_value()-> int:
	return total_value
