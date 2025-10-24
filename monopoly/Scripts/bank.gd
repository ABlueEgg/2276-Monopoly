extends Node2D

# Keep track of bank cards
var bank_cards := []

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
		# Don't override scale — keep what you set in the editor
	else:
		push_warning("Sprite2D not found in bank scene")
	position = TARGET_POS
	# Optional: move to visible coordinates if needed

func add_card_to_bank(card: Node2D) -> void:
	if card == null:
		return
	bank_cards.append(card)
	# Disable collisions
	var area = card.get_node_or_null("Area2D/CollisionShape2D")
	if area:
		area.disabled = true
	# Capture the card's global position BEFORE reparenting
	var prev_global_pos = card.global_position
	# Reparent under bank slot
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
