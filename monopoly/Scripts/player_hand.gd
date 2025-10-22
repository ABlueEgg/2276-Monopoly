extends Node2D

const CARD_WIDTH = 200
const HAND_Y_POSITION = 955
const DEFAULT_CARD_MOVE_SPEED = 0.5
const RECENTER_SPEED = 0.25  # faster recenters

var player_hand = []
var center_screen_x

func _ready() -> void:
	center_screen_x = get_viewport().size.x / 2

func add_card_to_hand(card, speed):
	if card not in player_hand:
		player_hand.insert(0, card)
		# Immediately place roughly in the center before animating
		card.position = Vector2(center_screen_x, HAND_Y_POSITION)
		update_hand_positions(speed)
	else:
		animate_card_to_position(card, card.position_in_hand, speed)

func update_hand_positions(speed := DEFAULT_CARD_MOVE_SPEED, is_recentering := true):
	center_screen_x = get_viewport().size.x / 2
	for i in range(player_hand.size()):
		var new_position = Vector2(calculate_card_position(i), HAND_Y_POSITION)
		var card = player_hand[i]
		card.position_in_hand = new_position
		animate_card_to_position(card, new_position, speed, is_recentering)

func calculate_card_position(index):
	var total_width = (player_hand.size() -1) * CARD_WIDTH 
	var x_offset = center_screen_x + index * CARD_WIDTH - total_width / 2
	return x_offset

func animate_card_to_position(card, target_position, speed, is_recentering := false):
	# Kill existing tween
	if card.has_meta("tween") and card.get_meta("tween") != null:
		var old_tween = card.get_meta("tween")
		if old_tween is Tween:
			old_tween.kill()
	card.set_meta("tween", null)
	var collision = card.get_node_or_null("Area2D/CollisionShape2D")
	if collision:
		collision.disabled = false
	# ✅ Proper tween speed logic
	var duration = RECENTER_SPEED if is_recentering else speed
	var tween = get_tree().create_tween()
	card.set_meta("tween", tween)
	tween.tween_property(card, "position", target_position, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished
	card.set_meta("tween", null)
	if collision:
		collision.disabled = false

func remove_card_from_hand(card):
	if card in player_hand:
		player_hand.erase(card)
		update_hand_positions(RECENTER_SPEED, true)
