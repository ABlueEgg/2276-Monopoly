extends Node
const CARD_SCENE_PATH = "res://scenes/card.tscn"

@onready var card_slots_parent = $"../CardSlots"
@onready var card_database = $"../CardDatabase"
@onready var deck_ref = $"../Deck"
@onready var card_manager_ref = $"../CardManager"
@onready var ai_bank_ui = $"../OpponentDeck"
@onready var ai_bank_label = $"../OpponentDeck/BankLabel"
# Called when the node enters the scene tree for the first time.
var ai_hand = [] 
var ai_moves_left = 0
var ai_bank_cards = []
var ai_bank_total = 0
const AI_BANK_OFFSET = Vector2(5, -5)
const AI_BANK_CARD_SCALE = 0.8
const AI_BANK_TWEEN_TIME = 0.2

func _ready() -> void:
	_update_ai_bank_label()
	await get_tree().create_timer(1.0).timeout
	for i in range(5):
		draw_card_for_ai()

func start_ai_turn():
	print("\n--- AI TURN START ---")
	draw_card_for_ai()
	draw_card_for_ai()
	ai_moves_left = 3 # reset moves
	do_ai_move_loop() # play loop 

func do_ai_move_loop():
	if ai_moves_left <= 0 or ai_hand.is_empty():
		end_ai_turn()
		return
	await get_tree().create_timer(0.8).timeout
	var random_index = randi() % ai_hand.size()
	var card_to_play = ai_hand[random_index]
	var success = attempt_play_card(card_to_play)
	if success:
		ai_hand.remove_at(random_index)
		ai_moves_left -= 1
		print("AI played: ", card_to_play, "| Moves Left:", ai_moves_left)
	else:
		print("AI cannot play", card_to_play, "(no slots). discard")
		ai_hand.remove_at(random_index)
		ai_moves_left -= 1
	do_ai_move_loop()
		
func end_ai_turn():
	print("--- AI TURN END ---")
	$"../CardManager".start_turn()
	#check everytime ai turn if deck empty then tie 
	var cm = $"../CardManager"
	if cm:
		cm.check_ai_win_or_tie()
		if cm.playing:
			cm._begin_game_turn()
		else:
			print("game over. AI stopped playing.")
	card_manager_ref._begin_game_turn() # back to the player

func draw_card_for_ai():
	var c_name = deck_ref.draw_card_string()
	if c_name != "":
		ai_hand.append(c_name)

func attempt_play_card(card_name: String) -> bool:
	var type = card_database.CARDS[card_name][1]
	var _value = card_database.CARDS[card_name][0]
	if type != "action" and type != "money" and type != "rent":
		return play_property_card(card_name, type)
	if card_name == "AC_PassGo":
		card_manager_ref.show_ai_action("opponent used Pass Go (+2 cards)")
		draw_card_for_ai()
		draw_card_for_ai()
		return true
	if card_name == "AC_SlyDeal":
		card_manager_ref.show_ai_action("opponent used Sly Deal")
		print("AI attempts Sly Deal")
		if card_manager_ref and card_manager_ref.ai_sly_deal():
			print("AI Sly Deal succeeded")
		else:
			print("AI Sly Deal failed")
		return true
	if card_name == "AC_DealBreaker":
		card_manager_ref.show_ai_action("opponent used Deal Breaker")
		print("AI attempts DealBreaker")
		if card_manager_ref and card_manager_ref.ai_deal_breaker():
			print("AI DealBreaker succeeded")
		else:
			print("AI DealBreaker failed")
		return true
	if type == "money":
		play_money_card(card_name)
		return true
	if type == "rent":
		#card_manager_ref.show_ai_action("opponent charged Rent")
		#print("AI plays rent card")
		#if card_manager_ref:
			#card_manager_ref.resolve_rent(["any"])
		return true
	if type == "action":
		print("AI plays action card")
		return true
	print("AI discarded unknown card: ", card_name)
	return true
	
func play_money_card(card_name: String) -> bool:
	var card_scene = load(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	var data = card_database.CARDS[card_name]
	new_card.setup(data[0], data[1], card_name)
	var img = new_card.get_node_or_null("Card_Image")
	if img:
		var path = "res://Assets/%sCard.png" % card_name
		if ResourceLoader.exists(path):
			img.texture = load(path)
	add_card_to_ai_bank(new_card)
	return true

func add_card_to_ai_bank(card: Node2D) -> void:
	if card == null:
		return
	if card.has_method("get_value"):
		var value = card.get_value()
		if value != null and value > 0:
			ai_bank_total += value
			_update_ai_bank_label()
			print("AI Bank: Card added. New total: " + str(ai_bank_total) + "M")
	ai_bank_cards.append(card)
	var shape = card.get_node_or_null("Area2D/CollisionShape2D")
	if shape:
		shape.disabled = true
	var old_parent = card.get_parent()
	if old_parent:
		old_parent.remove_child(card)
	ai_bank_ui.add_child(card)
	card.scale = Vector2(AI_BANK_CARD_SCALE, AI_BANK_CARD_SCALE)
	var index = ai_bank_cards.size() - 1
	var local_target_pos = AI_BANK_OFFSET * index
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", local_target_pos, AI_BANK_TWEEN_TIME)
	tween.tween_property(card, "z_index", index + 1, AI_BANK_TWEEN_TIME)

func _update_ai_bank_label() -> void:
	if ai_bank_label:
		ai_bank_label.text = str(ai_bank_total) + "M"
		ai_bank_label.z_index = 100 
		print("AI Bank label updated to:", ai_bank_label.text)
	else:
		push_warning("AI bank label is NULL – check the path to OpponentDeck/BankLabel")

func get_ai_bank_total() -> int:
	return ai_bank_total

func spend_from_ai_bank(amount: int) -> bool:
	if ai_bank_total >= amount:
		ai_bank_total -= amount
		_update_ai_bank_label()
		print("AI Bank: Spent " + str(amount) + "M")
		return true
	print("AI Bank: Not enough money to spend")
	return false
	
func play_property_card(card_name, color) -> bool:
	var slot_to_use = null
	var all_slots = []
	for child in card_slots_parent.get_children():
		if child.name.begins_with("Opponent"):
			all_slots.append(child)
	# find a slot with the same color
	for slot in all_slots:
		if slot_matches_color(slot,color):
			slot_to_use = slot
			break
	#if there is none with the same color, use a new one
	if slot_to_use == null:
		for slot in all_slots:
			if is_slot_empty(slot):
				slot_to_use = slot
				break
	if slot_to_use:
		spawn_card_into_slot(slot_to_use, card_name, color)
		return true
	return false

func slot_matches_color(slot, col):
	if not slot.has_meta("assigned_colour"):
		return false
	return slot.get_meta("assigned_colour") == col
func is_slot_empty(slot):
	if not slot.has_meta("cards_in_box"):
		return true
	var cards = slot.get_meta("cards_in_box")
	return cards.size() == 0 

func spawn_card_into_slot(slot_node, card_name, color):
	if not slot_node or not card_database:
		print("Error: missing slot or database")
		return
	var card_scene = load(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	var card_data = card_database.CARDS[card_name]
	new_card.setup(card_data[0], card_data[1], card_name)
	var card_image_node = new_card.get_node_or_null("Card_Image")
	if card_image_node:
		var path = "res://Assets/%sCard.png" % card_name
		if ResourceLoader.exists(path):
			card_image_node.texture = load(path)
	slot_node.add_child(new_card)
	new_card.position = Vector2.ZERO
	new_card.scale = Vector2(1,1) # smaller than player
	new_card.card_in_slot = slot_node
	
	#disable interaction
	var area = new_card.get_node_or_null("Area2D/CollisionShape2D")
	if area:
		area.disabled = false
	# metadata update
	var existing_cards = []
	if slot_node.has_meta("cards_in_box"):
		existing_cards = slot_node.get_meta("cards_in_box")
	
	var offset = Vector2(0, 20 * existing_cards.size())
	new_card.position = offset
	new_card.z_index = existing_cards.size()
	existing_cards.append(new_card)
	slot_node.set_meta("cards_in_box", existing_cards)
	slot_node.set_meta("assigned_colour", color)

func spawn_card_into_ai_slot(card: Node2D, color: String = "") -> void:
	if card_slots_parent == null:
		print("AI: no card_slots_parent")
		return
	if color == "" and card.has_method("get_colour"):
		color = str(card.get_colour()).to_lower()
	else:
		color = color.strip_edges().to_lower()
	var all_slots: Array = []
	for child in card_slots_parent.get_children():
		if child.name.begins_with("Opponent"):
			all_slots.append(child)
	if all_slots.size() == 0:
		print("AI: no opponent slots found")
		return
	var slot_to_use: Node = null
	for slot in all_slots:
		if slot.has_meta("assigned_colour"):
			var assigned = str(slot.get_meta("assigned_colour")).to_lower()
			if assigned == color and color != "":
				slot_to_use = slot
				break
	if slot_to_use == null:
		for slot in all_slots:
			var cards: Array = []
			if slot.has_meta("cards_in_box"):
				cards = slot.get_meta("cards_in_box")
			if cards.size() == 0:
				slot_to_use = slot
				break
	if slot_to_use == null:
		slot_to_use = all_slots[0]
	if card.get_parent():
		card.get_parent().remove_child(card)
	slot_to_use.add_child(card)
	card.card_in_slot = slot_to_use
	var existing_cards: Array = []
	if slot_to_use.has_meta("cards_in_box"):
		existing_cards = slot_to_use.get_meta("cards_in_box")
	var index := existing_cards.size()
	var offset := Vector2(0, 20 * index)
	card.position = offset
	card.scale = Vector2(1, 1)
	card.z_index = index
	existing_cards.append(card)
	slot_to_use.set_meta("cards_in_box", existing_cards)
	if not slot_to_use.has_meta("assigned_colour") or str(slot_to_use.get_meta("assigned_colour")) == "":
		slot_to_use.set_meta("assigned_colour", color)

func force_pay_from_bank(amount_requested: int)-> Array:
	var cards_to_pay_with = []
	var value_collected = 0
	for i in range(ai_bank_cards.size() -1, -1, -1):
		if value_collected >= amount_requested:
			break
		var card = ai_bank_cards[i]
		var card_val = 0
		if card.has_method("get_value"):
			card_val = card.get_value()
		value_collected += card_val
		ai_bank_total -= card_val
		#remove from ai list
		ai_bank_cards.remove_at(i)
		#remove from visual tree
		if card.get_parent():
			card.get_parent().remove_child(card)
		#add to payment
		cards_to_pay_with.append(card)
	#update ai visuals
	if ai_bank_total < 0:
		ai_bank_total = 0
	_update_ai_bank_label()
	print("AI is paying" + str(value_collected) + "M using" + str(cards_to_pay_with.size()) + " cards.")
	return cards_to_pay_with
	
