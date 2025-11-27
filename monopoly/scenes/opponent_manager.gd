extends Node
const CARD_SCENE_PATH = "res://scenes/card.tscn"

@onready var card_slots_parent = $"../CardSlots"
@onready var card_database = $"../CardDatabase"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	setup_opponent_board()

func setup_opponent_board():
	var slot1= card_slots_parent.get_node("OpponentCardSlot")
	spawn_card_into_slot(slot1, "DB_ParkPlace", "dblue")
	var slot2 = card_slots_parent.get_node("OpponentCardSlot2")
	spawn_card_into_slot(slot2, "Y_VentnorAve", "yellow")
	
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
	new_card.scale = Vector2(1,1) # smaller than plyayer
	new_card.card_in_slot = slot_node
	
	
	# update slot 
	var existing_cards = []
	if slot_node.has_meta("cards_in_box"):
		existing_cards = slot_node.get_meta("cards_in_box")
	existing_cards.append(new_card)
	slot_node.set_meta("cards_in_box", existing_cards)
	slot_node.set_meta("assigned_colour", color)
	print("oppoent played: " + card_name)
