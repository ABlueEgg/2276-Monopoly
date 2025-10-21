extends Node2D


const CARD_WIDTH = 200 
const HAND_Y_POSITION = 955
const DEFAULT_CARD_MOVE_SPEED = 0.5

var player_hand = []
var center_screen_x

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	center_screen_x = get_viewport().size.x / 2


func add_card_to_hand(card, speed):
	if card not in player_hand:
		player_hand.insert(0, card)
		update_hand_positions(speed)
	else:
		animate_card_to_position(card, card.position_in_hand, speed)
	
func update_hand_positions(speed):
	for i in range(player_hand.size()):
		#get new card position based on index
		var new_position = Vector2(calculate_card_position(i), HAND_Y_POSITION)
		var card = player_hand[i]
		card.position_in_hand = new_position
		animate_card_to_position(card, new_position, speed)
		
func calculate_card_position(index):
	var total_width = (player_hand.size() -1) * CARD_WIDTH 
	var x_offset = center_screen_x + index * CARD_WIDTH - total_width / 2
	return x_offset

# Called every frame. 'delta' is the elapsed time since the previous frame.
func animate_card_to_position(card, target_position, speed, is_recentering := false):
	# If there's an existing tween on this card, kill it so it doesn't block interaction
	if card.has_meta("tween") and card.get_meta("tween") != null:
		var old_tween = card.get_meta("tween")
		if old_tween is Tween:
			old_tween.kill()
		card.set_meta("tween", null)
	# ensure collision is enabled while moving (so it can be picked up)
	var collision = card.get_node_or_null("Area2D/CollisionShape2D")
	if collision:
		collision.disabled = false
	var tween = get_tree().create_tween()
	card.set_meta("tween", tween)
	var duration = is_recentering if is_recentering else speed
	tween.tween_property(card, "position", target_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# when finished, clean up and ensure interaction is available
	await tween.finished
	# clear stored tween reference
	card.set_meta("tween", null)
	# ensure collision is enabled at end (so the player can hover/select immediately)
	if collision:
		collision.disabled = false
	
func remove_card_from_hand(card):
	if card in player_hand:
		player_hand.erase(card)
		update_hand_positions(DEFAULT_CARD_MOVE_SPEED)
