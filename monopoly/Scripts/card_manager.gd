extends Node2D
# the image attached to cards is a temp image that can be changed later

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2
const DEFAULT_CARD_MOVE_SPEED = 0.1
const DEFAULT_CARD_SCALE = 0.8
const CARD_BIGGER_SCALE = 0.85
const CARD_SMALLER_SCALE = 0.6

var screen_size
var card_being_dragged
var is_hovering_on_card
var player_hand_reference
var played_card
var cardDbRef 
#var slot_cards := [] #array to track cards placed in slots

var playing = true

# Called when the node enters the scene tree for the first time.
#this function makes sure the cards cant go off screen
func _ready() -> void:
	screen_size = get_viewport_rect().size
	player_hand_reference = $"../PlayerHand"
	$"../InputManager".connect("left_mouse_button_released", on_left_click_released)
	cardDbRef = $"../CardDatabase"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not playing:
		return
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x),
		clamp(mouse_pos.y, 0, screen_size.y))

func start_drag(card):
	card_being_dragged = card
	card.scale = Vector2(DEFAULT_CARD_SCALE,DEFAULT_CARD_SCALE)
	
func finish_drag():
	if card_being_dragged == null:
		return
	var card_slot_found = raycast_check_for_card_slot()
	var bank_pile_found = raycast_check_for_bank_pile()
	if card_slot_found and not card_slot_found.card_in_slot:
		# Card dropped in a valid empty slot
		card_being_dragged.scale = Vector2(CARD_SMALLER_SCALE, CARD_SMALLER_SCALE)
		card_being_dragged.z_index = -1
		card_being_dragged.card_slot_card_in_slot = card_slot_found
		player_hand_reference.remove_card_from_hand(card_being_dragged)
		card_being_dragged.position = card_slot_found.position
		card_being_dragged.get_node("Area2D/CollisionShape2D").disabled = true
		card_slot_found.card_in_slot = true
		var col = card_being_dragged.get_colour()
		if cardDbRef.COLOURS.has(col):
			cardDbRef.COLOURS[col] -= 1
			print(col,"now at",cardDbRef.COLOURS[col])
		check_win()
	elif bank_pile_found:
		bank_pile_found.add_card_to_bank(card_being_dragged)
		player_hand_reference.remove_card_from_hand(card_being_dragged)
	else:
		# Return card to player's hand
		card_being_dragged.get_node("Area2D/CollisionShape2D").disabled = false
		player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
	card_being_dragged.scale = Vector2(CARD_BIGGER_SCALE, CARD_BIGGER_SCALE)
	card_being_dragged = null
			
func connect_card_signals(card):
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)
	card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)  
	card.z_index = 1 

func check_win():
	var counter = 0
	for col in cardDbRef.COLOURS:
		if cardDbRef.COLOURS[col] <= 0:
			counter += 1
	if counter >= 3:
		win()

func win():
	$"../winLabel".visible = true
	#$"../horribleSpaghetti".visible = true
	playing = false

func on_left_click_released():
	if card_being_dragged:
		finish_drag()

func on_hovered_over_card(card):
	if !is_hovering_on_card:
		is_hovering_on_card = true
		highlight_card(card, true)
	
func on_hovered_off_card(card):
	#check if card is in a slot and not being dragged
	if !card.card_slot_card_in_slot && !card_being_dragged:
		#if not dragging
		highlight_card(card, false)
		#check if hovered off card straight on to another card
		var new_card_hovered = raycast_check_for_card()
		if new_card_hovered:
			highlight_card(new_card_hovered, true)
		else:
			is_hovering_on_card = false
	
func highlight_card(card, hovered):
	if card.card_slot_card_in_slot:
		return
	if hovered:
		card.scale = Vector2(CARD_BIGGER_SCALE,CARD_BIGGER_SCALE)
		card.z_index = 2
	else:
		card.scale = Vector2(DEFAULT_CARD_SCALE,DEFAULT_CARD_SCALE)
		card.z_index = 1
	
func raycast_check_for_card_slot():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD_SLOT  # This should be 2
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null
	
func raycast_check_for_card():
	# pulled from godot documentation
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return get_card_with_highest_z_index(result)
	return null
	
func raycast_check_for_bank_pile():
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	# keep bank collision mask here (ensure Bank uses this layer)
	params.collision_mask = 4
	var result = space_state.intersect_point(params)
	if result.size() == 0:
		return null
	# loop through all hits and find a parent that implements add_card_to_bank
	for i in range(result.size()):
		var collider = result[i].collider
		if collider == null:
			continue
		var node = collider.get_parent()  # often Area2D's parent
		# climb parents to find an appropriate node (safety: stop at scene root)
		while node:
			if node.has_method("add_card_to_bank"):
				return node
			# stop if we've reached the scene root (avoid infinite loop)
			if node == get_tree().current_scene:
				break
			node = node.get_parent()
	return null
	
func get_card_with_highest_z_index(cards):
	var highest_z_card = cards[0].collider.get_parent()
	var highest_z_index = highest_z_card.z_index

	for i in range(1, cards.size()):
		var current_card = cards[i].collider.get_parent()
		if current_card.z_index > highest_z_index:
			highest_z_card = current_card
			highest_z_index = current_card.z_index
	return highest_z_card
