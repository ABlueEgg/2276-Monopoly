extends Node2D
const RENT_SCALES = {
	"brown": [1,2],
	"dblue": [3, 8],
	"green": [2 ,4 ,7],
	"yellow": [2, 4 ,6],
	"red": [2,3,6],
	"orange":[1,3,5],
	"pink":[1,2,4],
	"lightblue":[1,2,3],
	"utility":[1,2],
	"Railroad":[1,2,3,4]
}
const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2
const COLLISION_MASK_BANK = 4
const COLLISION_MASK_PLAY_AREA = 8

const DEFAULT_CARD_MOVE_SPEED = 0.1
const DEFAULT_CARD_SCALE = 0.8
const CARD_BIGGER_SCALE = 0.85
const CARD_SMALLER_SCALE = 0.6
const SLOT_OFFSET:=Vector2(18,-2)
const SLOT_Z_BASE:=200

var screen_size
var card_being_dragged
var is_hovering_on_card
var player_hand_ref
var played_card
var card_Db_Ref 
var cards_played_this_turn 
var timer_enabled := true
var can_play_cards = true
var playing = true
var announced_sets := {}
const TURN_DURATION := 30.0
var timer_active := false
var turn_timer: Timer
var turn_label: Label
var turn_tween: Tween

#targeting 
var is_targeting_mode = false
var pending_action_card = null

func set_cards_playable(playable: bool) -> void:
	for card in get_children():
		# Look for the collider inside each card
		var collider = card.get_node_or_null("Area2D/CollisionShape2D")
		if collider:
			collider.disabled = not playable
# Called when the node enters the scene tree for the first time.
#this function makes sure the cards cant go off screen
func _ready() -> void:
	screen_size = get_viewport_rect().size
	player_hand_ref = $"../PlayerHand"
	$"../InputManager".connect("left_mouse_button_released", on_left_click_released)
	card_Db_Ref = $"../CardDatabase"
	newTurn()
	$"../TimerLabel".visible = false
	turn_timer = $"../TurnTimer"
	turn_label = $"../TurnLabel"
	if turn_label:
		turn_label.visible = false
	if turn_timer == null:
		push_error("TurnTimer node not found!")
		return
	turn_timer.one_shot = true
	if not turn_timer.timeout.is_connected(_on_turn_timer_timeout):
		turn_timer.timeout.connect(_on_turn_timer_timeout)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not playing:
		return
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x),
		clamp(mouse_pos.y, 0, screen_size.y))
	if timer_active and is_instance_valid(turn_timer):
		var tl := $"../TimerLabel" as Label 
		if tl:
			tl.text = "Your turn: %ds" % int(ceil(turn_timer.time_left))
			tl.visible = true
		
func start_turn() -> void:
	show_turn_banner("It is your turn!", Color.GREEN, 3.0)
	timer_active = true
	cards_played_this_turn = 0
	turn_timer.start(TURN_DURATION)

func end_turn(reason: String = "") -> void:
	timer_active = false
	turn_timer.stop()
	show_turn_banner("Opponent's turn", Color.RED, 3.0)
	var msg := "Your turn ended! Starting new turn..."
	var label = $"../MessageLabel" as Label
	if label:
		label.text = msg
		label.visible = true
		label.modulate = Color(1,1,1,1)
		var t = create_tween()
		for i in range(3):
			t.tween_property(label, "self_modulate", Color(1,0,0,1), 0.2) # red
			t.tween_property(label, "self_modulate", Color(1,1,1,1), 0.2) # back to white
		t.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.3)
		#await t.finished
		label.visible = false
		print("Passing turn to AI..")
	var ai = $"../OpponentManager"
	if ai:
		ai.start_ai_turn()
	else:
		print("Error: opponent manager not found")
	
func _on_turn_timer_timeout() -> void:
	if timer_active:
		end_turn("timeout")

func start_drag(card):
	#don't drag opponent cards
	if card.card_in_slot and card.card_in_slot.name.begins_with("Opponent"):
		print("You can't drag the opponent's cards!")
		return 
	card_being_dragged = card
	card.scale = Vector2(DEFAULT_CARD_SCALE,DEFAULT_CARD_SCALE)
	card.z_index = 999
	$"../Deck".draw_cards_at_turn_start()
	
func finish_drag():
	if card_being_dragged == null:
		return
	if not timer_active and timer_enabled:
		print("wait for your turn!")
		_return_card_to_hand()
		card_being_dragged = null
		return
	if not can_play_cards:
		print("You must draw 2 cards before playing!")
		player_hand_ref.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
		card_being_dragged.scale = Vector2(CARD_BIGGER_SCALE, CARD_BIGGER_SCALE)
		card_being_dragged = null
		return
	var slot: Node = raycast_check_for_card_slot()
	var bank_pile: Node = raycast_check_for_bank_pile()
	var play_area_hit: bool = raycast_check_for_play_area() 
	if cards_played_this_turn >=3:
		max_cards_played_popup()
		_return_card_to_hand()
		if is_instance_valid(card_being_dragged):
			card_being_dragged.scale = Vector2(CARD_BIGGER_SCALE, CARD_BIGGER_SCALE)
			card_being_dragged.z_index = 1
		card_being_dragged = null
		return
	# dropped in slot
	if slot:
		var col := _normalize_colour(str(card_being_dragged.get_colour()))
		if _slot_can_accept(slot, col):
			_place_card_into_slot(slot, card_being_dragged, col)
			player_hand_ref.remove_card_from_hand(card_being_dragged)
			if card_Db_Ref.COLOURS.has(col):
				card_Db_Ref.COLOURS[col] -= 1
				print(col, "now at", card_Db_Ref.COLOURS[col])
			check_win()
			cards_played_this_turn += 1
		else:
			_reject_to_hand_with_reason(card_being_dragged, slot)
	#2 dropped in bank
	elif bank_pile:
		if card_being_dragged.get_value() > 0:
			bank_pile.add_card_to_bank(card_being_dragged)
			player_hand_ref.remove_card_from_hand(card_being_dragged)
			cards_played_this_turn += 1
		else:
			_return_card_to_hand()
	#3. dropped in play area(action cards)
	elif play_area_hit:
		var c_type = card_Db_Ref.CARDS[card_being_dragged.cardName][1]
		#for debug
		print("DEbug: dropped ", card_being_dragged.cardName, "| Type: ", c_type)
		if c_type == "action" or c_type == "rent":
			execute_action_card(card_being_dragged)
			cards_played_this_turn += 1
		
		else:
			print("Only action cards can be played in the center!")
			_return_card_to_hand()
	#4 Dropped nowhere
	else:
		_return_card_to_hand()
	# Reset drag visuals
	if is_instance_valid(card_being_dragged):
		card_being_dragged.scale = Vector2(CARD_BIGGER_SCALE, CARD_BIGGER_SCALE)
		if card_being_dragged.card_in_slot:
			card_being_dragged.z_index = SLOT_Z_BASE + _slot_cards(card_being_dragged.card_in_slot).size()-1
	card_being_dragged = null

func _return_card_to_hand():
	var shape := card_being_dragged.get_node("Area2D/CollisionShape2D") as CollisionObject2D
	if shape:
		shape.disabled = false
	player_hand_ref.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)

#Action card 
func execute_action_card(card):
	var name = card.cardName
	print("Playing action:" + name)
	match name:
		"AC_PassGo":
			#draw 2 card
			var deck = $"../Deck"
			deck.draw_card(true)
			deck.draw_card(true)
			#action cards go to discard 
			discard_card(card)
		"AC_SlyDeal":
			#1 dont discard yet wait for target
			print("select")
			is_targeting_mode = true
			pending_action_card = card 
			#show message
			var label = $"../MessageLabel"
			if label:
				label.text = "select property to steal"
				label.visible = true
				label.modulate.a = 1.0
		"AC_DealBreaker":
			print("Select a completed set to steal")
			is_targeting_mode = true
			pending_action_card = card
			
			var label = $"../MessageLabel"
			if label:
				label.text = "Select a completed set to steal"
				label.visible = true
				label.modulate.a = 1.0
		"AC_Rent_Generic":
			resolve_rent(["any"])
			discard_card(card)
		_:
			print("Action logic not implemented for" + name)
			_return_card_to_hand()
			#decrement counter cuz we didnt play it
			cards_played_this_turn -= 1

func on_card_clicked(clicked_card):
	if not is_targeting_mode:
		start_drag(clicked_card)
		return
	if is_targeting_mode:
		if clicked_card.card_in_slot and clicked_card.card_in_slot.name.begins_with("Opponent"):
			if pending_action_card.cardName == "AC_SlyDeal":
				resolve_sly_deal(clicked_card)
			elif pending_action_card.cardName == "AC_DealBreaker":
				resolve_deal_breaker(clicked_card)
		else:
			print("Invalid Target! You must pick opponent's card.")
	
func resolve_rent(allowed_colors: Array)->void:
	var best_rent = 0
	var best_color = ""
	#checks all colors
	var colors_to_check = allowed_colors
	if allowed_colors.has("any"):
		colors_to_check = RENT_SCALES.keys()
	# find the highest rent u can charge
	for col in colors_to_check:
		var rent_value = calculate_player_rent_for_color(col)
		if rent_value > best_rent:
			best_rent = rent_value
			best_color = col
	#charge now
	if best_rent > 0:
		print("Charging opponent" + str(best_rent))
		charge_opponent(best_rent)
		#visual
		var label = $"../MessageLabel"
		if label:
			label.text = "CHARGED AI" + str(best_rent) + "M RENT!"
			label.visible = true
			label.modulate = Color.GREEN
			label.self_modulate = Color.WHITE
			var t = create_tween()
			t.tween_interval(2.0)
			t.tween_property(label, "modulate:a", 0.0, 1.0)
			t.tween_callback(func(): label.visible = false)
	else:
		print("you don't own any properties to charge rent for!")
func calculate_player_rent_for_color(color: String)-> int:
	if not RENT_SCALES.has(color):
		return 0
	var count = 0
	var slots_parent = $"../CardSlots"
	#how many cards of this color u have played
	for slot in slots_parent.get_children():
		if slot.name.begins_with("Opponent"):
			continue
		if slot.has_meta("assigned_colour") and slot.get_meta("assigned_colour") == color:
			var cards = slot.get_meta("cards_in_box")
			count += cards.size()
	var scale = RENT_SCALES[color]
	if count <= 0:
		return 0
	var index = min(count -1, scale.size() -1)
	return scale[index]
func charge_opponent(amount:int)->void:
	var ai = $"../OpponentManager"
	var player_bank = $"../Bank"
	if not player_bank:
		print("Error: cound not find Player Bank")
		return
	if ai: 
		var payment_cards = ai.force_pay_from_bank(amount)
		if payment_cards.size() == 0:
			print("AI is broke! no cards to pay with")
			return
		var total_value_received = 0
		# move each card to player bank
		for card in payment_cards:
			var area = card.get_node_or_null("Area2D/CollisionShape2D")
			if area: 
				area.disabled = false
			if card.has_method("get_value"):
				total_value_received += card.get_value()
			player_bank.add_card_to_bank(card)
		print("Received " + str(total_value_received)+ "M in rent")

func resolve_deal_breaker(target_card):
	var target_slot = target_card.card_in_slot
	# is it a full set?
	var color = target_slot.get_meta("assigned_colour")
	var cards_in_slot = target_slot.get_meta("cards_in_box")
	var required_count = card_Db_Ref.COLOURS[color]
	
	if cards_in_slot.size() < required_count:
		print("This is not a full set")
		var label = $"../MessageLabel"
		if label:
			label.text = "That set is not full"
			label.visible = true
			label.modulate.a = 1.0
			var t = create_tween()
			t.tween_interval(1.5)
			t.tween_property(label, "modulate:a", 0.0, 1.0)
			t.tween_callback(func(): label.visible = false)
		is_targeting_mode = false
		if pending_action_card:
			player_hand_ref.add_card_to_hand(pending_action_card, DEFAULT_CARD_MOVE_SPEED)
			cards_played_this_turn = max(cards_played_this_turn - 1, 0)
			pending_action_card = null
		return
	print("stealing " + color)
	#duplicate the array 
	var cards_to_steal = cards_in_slot.duplicate()
	for card in cards_to_steal:
		#remove from opponent
		var current_list = target_slot.get_meta("cards_in_box")
		current_list.erase(card)
		target_slot.set_meta("cards_in_box", current_list)
		#move to plyaer hand
		_reparent_keep_global(card,self)
		card.card_in_slot = null
		var area = card.get_node("Area2D/CollisionShape2D")
		if area: area.disabled = false
		player_hand_ref.add_card_to_hand(card, DEFAULT_CARD_MOVE_SPEED)
	#no action card
	is_targeting_mode = false
	discard_card(pending_action_card)
	pending_action_card = null
	var label = $"../MessageLabel"
	if label:
		label.visible = false
	check_win()

func resolve_sly_deal(target_card):
	print("stealing" + target_card.cardName)
	var old_slot = target_card.card_in_slot
	var old_list = old_slot.get_meta("cards_in_box")
	old_list.erase(target_card)
	old_slot.set_meta("cards_in_box", old_list)
	#add to player hand
	_reparent_keep_global(target_card, self)
	target_card.card_in_slot = null 
	# enable collision again
	var area = target_card.get_node("Area2D/CollisionShape2D")
	if area: area.disabled = false
	
	player_hand_ref.add_card_to_hand(target_card, DEFAULT_CARD_MOVE_SPEED)
	#3. cleanup action
	is_targeting_mode = false
	discard_card(pending_action_card) # no more action card
	pending_action_card = null
	
	# hide message
	var label = $"../MessageLabel"
	if label: label.visible = false
	check_win() 

func ai_sly_deal() -> bool:
	var slots_parent = $"../CardSlots"
	var target_card = null
	var old_slot = null
	#get a property card from player's slot
	for slot in slots_parent.get_children():
		if slot.name.begins_with("Opponent"):
			continue
		if not slot.has_meta("cards_in_box"):
			continue
		var cards = slot.get_meta("cards_in_box")
		if cards.size() == 0:
			continue
		target_card = cards[0]
		old_slot = slot
		break
	#if cant find it then just return
	if target_card == null:
		print("AI Sly Deal: no cards")
		return false
	#remove the card that has been stolen by ai from player slot 
	print("AI Sly Deal: ", target_card.cardName)
	var old_list = old_slot.get_meta("cards_in_box")
	old_list.erase(target_card)
	old_slot.set_meta("cards_in_box", old_list)
	#pass the card to ai to place on its slot
	var ai_manager = $"../OpponentManager"
	if ai_manager and ai_manager.has_method("spawn_card_into_ai_slot"):
		ai_manager.spawn_card_into_ai_slot(target_card)
	else:
		print("something goes wrong")
		return false
	check_ai_win_or_tie()
	return true

func ai_deal_breaker() -> bool:
	var slots_parent = $"../CardSlots"
	var target_slot = null
	var target_color = ""
	# find player's complete set
	for slot in slots_parent.get_children():
		# skip opponent set
		if slot.name.begins_with("Opponent"):
			continue
		if not slot.has_meta("assigned_colour"):
			continue
		if not slot.has_meta("cards_in_box"):
			continue
		var col = str(slot.get_meta("assigned_colour"))
		if col == "":
			continue
		var cards = slot.get_meta("cards_in_box") as Array
		if cards.size() == 0:
			continue
		# check if it is complete set
		if RENT_SCALES.has(col):
			var need = RENT_SCALES[col].size()
			if cards.size() >= need:
				target_slot = slot
				target_color = col
				break
	# check if there is no set to steal
	if target_slot == null:
		print("AI DealBreaker: no full set to steal")
		return false
	print("AI DealBreaker stealing full set of color: ", target_color)
	# get a copy a set for stealing
	var cards_to_steal = (target_slot.get_meta("cards_in_box") as Array).duplicate()
	# move a set to ai's slot
	var ai_manager = $"../OpponentManager"
	if ai_manager == null or not ai_manager.has_method("spawn_card_into_ai_slot"):
		print("ERROR: OpponentManager or spawn_card_into_ai_slot missing")
		return false
	for card in cards_to_steal:
		# move a set from player's slot
		var current_list = target_slot.get_meta("cards_in_box")
		current_list.erase(card)
		target_slot.set_meta("cards_in_box", current_list)
		card.card_in_slot = null
		ai_manager.spawn_card_into_ai_slot(card)
	check_ai_win_or_tie()
	return true

func discard_card(card):
	# lets just delete. we dont really need array for take care of these stuff
	player_hand_ref.remove_card_from_hand(card)
	card.queue_free()

func max_cards_played_popup() -> void:
	var popup = Label.new()
	popup.text = "You can only play three cards per turn!"
	popup.add_theme_color_override("font_color", Color.RED)
	popup.add_theme_font_size_override("font_size", 40)
	popup.modulate = Color(1, 1, 1, 0)
	popup.position = Vector2(800, 540)
	popup.z_index = 999
	get_tree().current_scene.add_child(popup)
	var tween = get_tree().create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(popup, "modulate:a", 0.0, 0.5)
	await tween.finished
	popup.queue_free()

func newTurn():
	cards_played_this_turn = 0

func _ensure_slot_data(slot: Node) -> void:
	if not slot.has_meta("assigned_colour"):
		slot.set_meta("assigned_colour", "")
	if not slot.has_meta("cards_in_box"):
		slot.set_meta("cards_in_box", [])

func _slot_assigned_colour(slot: Node) -> String:
	_ensure_slot_data(slot)
	return String(slot.get_meta("assigned_colour"))

func _slot_cards(slot: Node) -> Array:
	_ensure_slot_data(slot)
	return slot.get_meta("cards_in_box") as Array

func _slot_set_assigned(slot: Node, col: String) -> void:
	slot.set_meta("assigned_colour", col)

func _slot_can_accept(slot: Node, col: String) -> bool:
	_ensure_slot_data(slot)
	var assigned := _slot_assigned_colour(slot)
	if assigned == "":
		return true
	return assigned == col

func _place_card_into_slot(slot: Node2D, card: Node2D, col: String) -> void:
	_ensure_slot_data(slot)
	if _slot_assigned_colour(slot) == "":
		_slot_set_assigned(slot, col)
	if _slot_assigned_colour(slot) != col:
		return
	var shape := card.get_node("Area2D/CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = true
	_reparent_keep_global(card, slot.get_parent())
	card.z_as_relative = false
	var cards := _slot_cards(slot)
	var index := cards.size()
	card.scale = Vector2(CARD_SMALLER_SCALE, CARD_SMALLER_SCALE)
	card.z_index = SLOT_Z_BASE + index
	var target_pos := slot.position + SLOT_OFFSET * index
	var t := create_tween()
	t.tween_property(card, "position", target_pos, 0.18)
	cards.append(card)
	slot.set_meta("cards_in_box", cards)
	card.card_in_slot = slot

func _reparent_keep_global(node: Node2D, new_parent: Node) -> void:
	var gp := node.global_position
	var old_parent := node.get_parent()
	if old_parent:
		old_parent.remove_child(node)
	new_parent.add_child(node)
	node.global_position = gp

func _reject_to_hand_with_reason(card: Node2D, slot: Node) -> void:
	var assigned := ""
	if slot and slot.has_meta("assigned_colour"):
		assigned = String(slot.get_meta("assigned_colour"))
	var msg := ""
	if assigned == "":
		msg = "This box is already complete."
	else:
		msg = "This box is reserved for %s." % assigned.capitalize()
	if has_node("../MessageLabel"):
		var label := $"../MessageLabel" as Label
		label.text = msg
		label.visible = true
		label.modulate.a = 1.0
		var t := create_tween()
		t.tween_property(label, "modulate:a", 0.0, 2.0).set_delay(0.5)
		t.tween_callback(func(): label.visible = false)
	var shape := card.get_node("Area2D/CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = false
	player_hand_ref.add_card_to_hand(card, DEFAULT_CARD_MOVE_SPEED)
	
func connect_card_signals(card):
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)
	card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)  
	card.z_index = 1 

func check_win():
	var counter := 0
	# 1) First pass: count completed sets
	for col in card_Db_Ref.COLOURS:
		if card_Db_Ref.COLOURS[col] <= 0:
			counter += 1
	# 2) Second pass: announce any *newly* completed colours and show "sets left"
	for col in card_Db_Ref.COLOURS:
		if card_Db_Ref.COLOURS[col] <= 0 and not announced_sets.get(col, false):
			announced_sets[col] = true
			var remaining: int = max(3 - counter, 0)
			#do not show once it gets to zero
			if remaining > 0:
				var info_label := $"../MessageLabel"
				info_label.text = "%s Set Completed!  %d set%s left to win!" % [col,remaining,("s" if remaining != 1 else "")]
				info_label.visible = true
				info_label.modulate.a = 1.0
				var t := create_tween()
				t.tween_property(info_label, "modulate:a", 0.0, 2.0).set_delay(0.5)
				t.tween_callback(func(): info_label.visible = false)
	# 3) Win check
	if counter >= 3:
		win()
	check_ai_win_or_tie()

func win():
	$"../winLabel".visible = true
	#$"../horribleSpaghetti".visible = true
	playing = false
	timer_active = false
	if is_instance_valid(turn_timer):
		turn_timer.stop()

func ai_win():
	var label = $"../winLabel"
	if label:
		label.text = "You lose!"
		label.visible = true
	playing = false
	timer_active = false
	if is_instance_valid(turn_timer):
		turn_timer.stop()

func check_ai_win_or_tie() -> void:
	if not playing:
		return
	var label = $"../winLabel"
	var deck = $"../Deck"
	var ai_sets = _count_ai_sets()
	if ai_sets >= 3:
		ai_win()
		return
	if deck.is_empty()==true:
		var player_sets = _count_player_sets()
		if player_sets < 3 and ai_sets < 3:
			if label:
				label.text = "Tie!"
				label.visible = true
			playing = false
			timer_active = false
			if is_instance_valid(turn_timer):
				turn_timer.stop()

func _count_player_sets():
	var n = 0
	for col in card_Db_Ref.COLOURS:
		if card_Db_Ref.COLOURS[col] <= 0:
			n += 1
	return n
	
func _count_ai_sets():
	var n = 0
	var slots_parent = $"../CardSlots"
	#for loop to check if the slot is ai's or player's
	for slot in slots_parent.get_children():
		if not slot.name.begins_with("Opponent"):
			continue
		if not slot.has_meta("assigned_colour"):
			continue
		if not slot.has_meta("cards_in_box"):
			continue
		var col = str(slot.get_meta("assigned_colour"))
		if col == "":
			continue
		var cards = slot.get_meta("cards_in_box")
		var need = 0
		if RENT_SCALES.has(col):
			need = RENT_SCALES[col].size()
		if need > 0 and cards.size() >= need:
			n += 1
	print("AI set = ", n)
	return n

func on_left_click_released():
	if card_being_dragged:
		finish_drag()

func on_hovered_over_card(card):
	if !is_hovering_on_card:
		is_hovering_on_card = true
		highlight_card(card, true)
	
func on_hovered_off_card(card):
	#check if card is in a slot and not being dragged
	if !card.card_in_slot && !card_being_dragged:
		#if not dragging
		highlight_card(card, false)
		#check if hovered off card straight on to another card
		var new_card_hovered = raycast_check_for_card()
		if new_card_hovered:
			highlight_card(new_card_hovered, true)
		else:
			is_hovering_on_card = false
	
func highlight_card(card, hovered):
	if card.card_in_slot:
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

func _on_end_turn_button_pressed() -> void:
	if timer_active:
		end_turn("button")

func _normalize_colour(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	for key in card_Db_Ref.COLOURS.keys():
		var k := str(key).to_lower()
		if s == k:
			return k
	if s == "dark blue" or s == "dark_blue" or s == "blue(dark)":
		return "dblue"
	for key in card_Db_Ref.COLOURS.keys():
		var k2 := str(key).to_lower()
		if s.findn(k2) != -1:
			return k2
	return s

func _begin_game_turn():
	if not timer_enabled:
		timer_active = true
		if $"../TimerLabel": $"../TimerLabel".visible = false
	if $"../TimerLabel":
		$"../TimerLabel".visible = true
	start_turn()
	
func raycast_check_for_play_area() -> bool:
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	#layer 4
	params.collision_mask = COLLISION_MASK_PLAY_AREA
	var result = space_state.intersect_point(params)
	return result.size() > 0

func show_turn_message(text: String, color: Color = Color.WHITE)->void:
	var label = $"../MessageLabel" as Label
	if label:
		if label.has_meta("active_tween"):
			var old_t = label.get_meta("active_tween")
			if old_t and old_t.is_valid():
				old_t.kill()
		label.self_modulate = Color.WHITE
		label.text = text
		label.modulate = color
		label.modulate.a = 1.0
		label.visible = true 
		var t = create_tween()
		label.set_meta("active_tween", t)
		t.tween_interval(5.0) 
		t.tween_property(label, "modulate:a", 0.0, 1.0)
		t.tween_callback(func(): label.visible = false)
 
func show_turn_banner(text: String, color: Color = Color.WHITE, duration: float = 5.0) -> void:
	if turn_label == null:
		return
	if turn_tween and turn_tween.is_valid():
		turn_tween.kill()
	turn_label.text = text
	turn_label.add_theme_font_size_override("font_size", 48)
	turn_label.modulate = color
	turn_label.modulate.a = 1.0
	turn_label.visible = true
	turn_tween = create_tween()
	turn_tween.tween_interval(duration)
	turn_tween.tween_property(turn_label, "modulate:a", 0.0, 0.6)
	turn_tween.tween_callback(func(): turn_label.visible = false)
	
#when ai uses action cards show a message
func show_ai_action(msg: String) -> void:
	var label = $"../MessageLabel" as Label
	if label:
		label.text = msg
		label.visible = true
		label.modulate.a = 1.0
		var t = create_tween()
		t.tween_interval(1.5)
		t.tween_property(label, "modulate:a", 0.0, 1.0)
		t.tween_callback(func(): label.visible = false)
