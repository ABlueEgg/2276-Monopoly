extends Node2D

const COLLISION_MASK_CARD: int = 1
const COLLISION_MASK_CARD_SLOT: int = 2
const DEFAULT_CARD_MOVE_SPEED: float = 0.1
const DEFAULT_CARD_SCALE: float = 0.8
const CARD_BIGGER_SCALE: float = 0.85
const CARD_SMALLER_SCALE: float = 0.6

const SLOT_OFFSET := Vector2(18, -2) 
const SLOT_Z_BASE := 200     

var screen_size: Vector2
var card_being_dragged: Node2D
var is_hovering_on_card: bool = false
var player_hand_reference: Node
var cardDbRef: Node
var cards_played_this_turn: int = 0

var playing: bool = true
var total_sets_done: int = 0
var announced_sets := {}

func _ready() -> void:
	screen_size = get_viewport_rect().size
	player_hand_reference = $"../PlayerHand"
	$"../InputManager".connect("left_mouse_button_released", on_left_click_released)
	cardDbRef = $"../CardDatabase"

func _process(_delta: float) -> void:
	if not playing:
		return
	if card_being_dragged:
		var mouse_pos: Vector2 = get_global_mouse_position()
		card_being_dragged.position = Vector2(
			clamp(mouse_pos.x, 0, screen_size.x),
			clamp(mouse_pos.y, 0, screen_size.y)
		)

func start_drag(card: Node2D) -> void:
	if card.has_method("is_locked_in_set") and card.is_locked_in_set:
		return
	card_being_dragged = card
	card.z_as_relative = false
	card.z_index = 10000
	card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)

func finish_drag() -> void:
	if card_being_dragged == null:
		return
	var slot = raycast_check_for_card_slot()
	var bank = raycast_check_for_bank_pile()
	if slot and cards_played_this_turn < 3:
		var col: String = _normalize_colour(str(card_being_dragged.get_colour()))
		if _slot_can_accept(slot, col):
			_place_card_into_slot(slot, card_being_dragged, col)
			player_hand_reference.remove_card_from_hand(card_being_dragged)
			cards_played_this_turn += 1
			if _slot_is_complete(slot):
				_finalize_slot_set(slot)
				_check_global_win()
		else:
			_reject_to_hand_with_reason(card_being_dragged, slot)
	elif bank and cards_played_this_turn < 3:
		bank.add_card_to_bank(card_being_dragged)
		player_hand_reference.remove_card_from_hand(card_being_dragged)
		cards_played_this_turn += 1
	else:
		if cards_played_this_turn >= 3:
			max_cards_played_popup()
		var shape := card_being_dragged.get_node("Area2D/CollisionShape2D") as CollisionShape2D
		if shape: shape.disabled = false
		player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
	if is_instance_valid(card_being_dragged):
		card_being_dragged.scale = Vector2(CARD_BIGGER_SCALE, CARD_BIGGER_SCALE)
	card_being_dragged = null
	
func newTurn() -> void:
	cards_played_this_turn = 0

func _ensure_slot_data(slot: Node) -> void:
	if not slot.has_meta("assigned_colour"):
		slot.set_meta("assigned_colour", "")
	if not slot.has_meta("cards_in_box"):
		slot.set_meta("cards_in_box", [])
	if not slot.has_meta("completed"):
		slot.set_meta("completed", false)
	if not slot.has_meta("required"):
		slot.set_meta("required", 0)

#save one color for one slot
func _slot_assigned_colour(slot: Node) -> String:
	_ensure_slot_data(slot)
	return String(slot.get_meta("assigned_colour"))

func _slot_cards(slot: Node) -> Array:
	_ensure_slot_data(slot)
	return slot.get_meta("cards_in_box") as Array

func _slot_completed(slot: Node) -> bool:
	_ensure_slot_data(slot)
	return bool(slot.get_meta("completed"))

func _slot_required(slot: Node) -> int:
	_ensure_slot_data(slot)
	return int(slot.get_meta("required"))

#user can only added same color cards to one slot
func _slot_set_assigned(slot: Node, col: String) -> void:
	slot.set_meta("assigned_colour", col)
	var req := 0
	if cardDbRef and cardDbRef.COLOURS.has(col):
		req = int(cardDbRef.COLOURS[col])
	slot.set_meta("required", max(req, 1))

#check users' cards can be added to a slot
func _slot_can_accept(slot: Node, col: String) -> bool:
	_ensure_slot_data(slot)
	if _slot_completed(slot):
		return false
	var assigned := _slot_assigned_colour(slot)
	if assigned == "":
		return true
	return assigned == col

#put cards into the slot
func _place_card_into_slot(slot: Node2D, card: Node2D, col: String) -> void:
	_ensure_slot_data(slot)
	if _slot_assigned_colour(slot) == "":
		_slot_set_assigned(slot, col)
	if _slot_assigned_colour(slot) != col:
		return 
	var shape := card.get_node("Area2D/CollisionShape2D") as CollisionShape2D
	if shape: shape.disabled = true
	_reparent_keep_global(card, slot.get_parent())  
	card.z_as_relative = false
	var cards := _slot_cards(slot)
	var index := cards.size()
	card.scale = Vector2(CARD_SMALLER_SCALE, CARD_SMALLER_SCALE)
	card.z_index = SLOT_Z_BASE + index
	var target_pos := (slot as Node2D).position + SLOT_OFFSET * index
	var t := create_tween()
	t.tween_property(card, "position", target_pos, 0.18)
	cards.append(card)
	slot.set_meta("cards_in_box", cards)
	if card.has_method("set_input_enabled"):
		card.set_input_enabled(true) 
	card.set("card_slot_card_in_slot", slot)

#check if cards is complete as set in a slot
func _slot_is_complete(slot: Node) -> bool:
	var req := _slot_required(slot)
	var count := _slot_cards(slot).size()
	return req > 0 and count >= req

#show the message when a set is finish, 
func _finalize_slot_set(slot: Node) -> void:
	if _slot_completed(slot):
		return
	slot.set_meta("completed", true)
	var cards := _slot_cards(slot)
	var base := (slot as Node2D).position
	for i in range(cards.size()):
		var c: Node2D = cards[i]
		if c.has_method("set_input_enabled"):
			c.set_input_enabled(false)
		c.set("is_locked_in_set", true)
		c.z_index = SLOT_Z_BASE + i
		var offset := SLOT_OFFSET * i
		var t := create_tween()
		t.tween_property(c, "position", base + offset, 0.12)
		t.parallel().tween_property(
			c, "rotation_degrees",
			lerp(-4.0, 4.0, float(i) / max(1, cards.size() - 1)),
			0.12
		)
	var col := _slot_assigned_colour(slot)
	total_sets_done += 1
	if total_sets_done < 3:
		var remaining = max(3 - total_sets_done, 0)
		var remaining_msg := "  %d set%s left to win!" % [remaining, ("" if remaining == 1 else "s")]
		_toast("%s Set Completed!%s" % [col.capitalize(), remaining_msg])
	else:
		win()
		
func _check_global_win() -> void:
	if total_sets_done >= 3:
		win()

func _toast(msg: String) -> void:
	var label: Label = $"../MessageLabel" as Label
	if not is_instance_valid(label):
		return
	label.text = msg
	label.visible = true
	label.modulate.a = 1.0
	label.scale = Vector2(0.9, 0.9)
	var t := create_tween()
	t.tween_property(label, "scale", Vector2(1, 1), 0.18)
	t.tween_property(label, "modulate:a", 0.0, 2.0).set_delay(0.6)
	t.tween_callback(func(): label.visible = false)

#show message when user try to put different color in a slot that already has color
func _reject_to_hand_with_reason(card: Node2D, slot: Node) -> void:
	var assigned := _slot_assigned_colour(slot)
	if assigned == "":
		_toast("This box is already complete.")
	else:
		_toast("This box is reserved for %s." % assigned.capitalize())
	var shape := card.get_node("Area2D/CollisionShape2D") as CollisionShape2D
	if shape: shape.disabled = false
	player_hand_reference.add_card_to_hand(card, DEFAULT_CARD_MOVE_SPEED)

func max_cards_played_popup() -> void:
	var popup := Label.new()
	popup.text = "You can only play three cards per turn!"
	popup.add_theme_color_override("font_color", Color.WHITE)
	popup.add_theme_font_size_override("font_size", 40)
	popup.modulate = Color(1, 1, 1, 0)
	popup.position = Vector2(800, 540)
	popup.z_index = 999
	get_tree().current_scene.add_child(popup)
	var tween := get_tree().create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(popup, "modulate:a", 0.0, 0.5)
	await tween.finished
	popup.queue_free()

func win() -> void:
	$"../winLabel".visible = true
	playing = false

func connect_card_signals(card) -> void:
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)
	card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
	card.z_index = 1

func on_hovered_over_card(card: Node2D) -> void:
	if card.card_slot_card_in_slot:
		return
	if not is_hovering_on_card:
		is_hovering_on_card = true
	card.z_as_relative = false
	card.z_index = 5000
	card.scale = Vector2(CARD_BIGGER_SCALE, CARD_BIGGER_SCALE)

func on_hovered_off_card(card: Node2D) -> void:
	if card.card_slot_card_in_slot or card_being_dragged:
		return
	card.z_as_relative = false
	card.z_index = 1
	card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
	is_hovering_on_card = false

func _normalize_colour(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	for key in cardDbRef.COLOURS.keys():
		var k := str(key).to_lower()
		if s == k:
			return k
	if s == "dark blue" or s == "dark_blue" or s == "blue(dark)":
		return "dblue"
	for key in cardDbRef.COLOURS.keys():
		var k2 := str(key).to_lower()
		if s.findn(k2) != -1:
			return k2
	return s

func _reparent_keep_global(node: Node2D, new_parent: Node) -> void:
	var gp: Vector2 = node.global_position
	var old: Node = node.get_parent()
	if old:
		old.remove_child(node)
	new_parent.add_child(node)
	node.global_position = gp

func on_left_click_released() -> void:
	if card_being_dragged:
		finish_drag()

func raycast_check_for_card_slot() -> Node:
	var space_state := get_world_2d().direct_space_state
	var parameters := PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD_SLOT
	var result: Array = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null

func raycast_check_for_bank_pile() -> Node:
	var space_state := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collision_mask = 4  
	var result: Array = space_state.intersect_point(params)
	if result.size() == 0:
		return null
	for i in range(result.size()):
		var collider = result[i].collider
		if collider == null:
			continue
		var node: Node = collider.get_parent()
		while node:
			if node.has_method("add_card_to_bank"):
				return node
			if node == get_tree().current_scene:
				break
			node = node.get_parent()
	return null
