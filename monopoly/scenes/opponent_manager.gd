extends Node
const CARD_SCENE_PATH = "res://scenes/card.tscn"

@onready var card_slots_parent = $"../CardSlots"
@onready var card_database = $"../CardDatabase"
@onready var deck_ref = $"../Deck"
@onready var card_manager_ref = $"../CardManager"
# Called when the node enters the scene tree for the first time.
var ai_hand = [] 
var ai_moves_left = 0

func _ready() -> void:
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
	card_manager_ref._begin_game_turn() # back to the player

func draw_card_for_ai():
	var c_name = deck_ref.draw_card_string()
	if c_name != "":
		ai_hand.append(c_name)

func attempt_play_card(card_name: String) -> bool:
	var type = card_database.CARDS[card_name][1]
	var value = card_database.CARDS[card_name][0]
	if type != "action" and type != "money" and type != "rent":
		return play_property_card(card_name, type)
	if card_name == "AC_PassGo":
		draw_card_for_ai()
		draw_card_for_ai()
		return true
	if type == "money" or type == "action" or type == "rent":
		return true
	print("AI discarded unknown card: ", card_name)
	return true

func play_property_card(card_name, color) -> bool:
	var slot_to_use = null
	var s1 = card_slots_parent.get_node("OpponentCardSlot")
	if _slot_matches_color(s1,color): slot_to_use = s1
	var s2 = card_slots_parent.get_node("OpponentCardSlot2")
	if slot_to_use == null and _slot_matches_color(s2,color): slot_to_use = s2
	if slot_to_use == null:
		if _is_slot_empty(s1): slot_to_use = s1
		elif _is_slot_empty(s2): slot_to_use = s2
	if slot_to_use:
		spawn_card_into_slot(slot_to_use, card_name, color)
		return true
	return false

func _slot_matches_color(slot, col):
	if not slot.has_meta("assigned_colour"):
		return false
	return slot.get_meta("assigned_colour") == col
func _is_slot_empty(slot):
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
	
