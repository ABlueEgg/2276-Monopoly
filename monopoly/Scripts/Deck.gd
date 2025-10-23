extends Node2D

const CARD_SCENE_PATH = "res://scenes/card.tscn"
const CARD_DRAW_SPEED = 0.2
const STARTING_HAND_SIZE = 5 
const MAX_CARDS_PER_TURN = 2

#deck needs to be updated with all the cards, the doubles are temp
var player_deck = ["R_KentuckyAve", "R_Illunois","DB_ParkPlace", "Y_AtlanticAve", 
"G_PacificAve","G_NorthCarolinaAve", "R_IndianaAve", "R_Illunois","Y_VentnorAve"]
var card_database_reference
var cards_drawn_this_turn := 0

func _ready() -> void:
	# Load card database
	card_database_reference = preload("res://Scripts/CardDatabase.gd")
	player_deck.shuffle()
	
	# Make sure deck is visible at start
	set_deck_visible(true)
	
	# Update deck counter
	update_deck_label()
	
	# Draw the starting hand
	for i in range(STARTING_HAND_SIZE):
		draw_card(true)

func set_deck_visible(visible: bool) -> void:
	var sprite = get_node("Sprite2D")
	var area = get_node("Area2D/CollisionShape2D")
	var label = get_node("RichTextLabel")
	if sprite:
		sprite.visible = visible
	if area:
		area.disabled = not visible
	if label:
		label.visible = visible

func update_deck_label() -> void:
	var label = get_node("RichTextLabel")
	if label:
		label.text = str(player_deck.size())

func draw_card(force_draw := false) -> void:
	# Prevent drawing if already drew max cards this turn, unless forced
	if not force_draw and cards_drawn_this_turn >= MAX_CARDS_PER_TURN:
		show_max_card_popup()
		return
	# Stop if deck is empty
	if player_deck.is_empty():
		return
	# Draw the top card
	var card_drawn_name = player_deck[0]
	player_deck.erase(card_drawn_name)
	if not force_draw:
		cards_drawn_this_turn += 1
	# Update deck counter
	update_deck_label()
	# Hide deck visuals only if deck is empty
	if player_deck.is_empty():
		set_deck_visible(false)
	else:
		set_deck_visible(true)  # Ensure deck stays visible if not empty
	# Instantiate the card scene
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	new_card.name = "Card"
	# Assign card image
	var card_image_node = new_card.get_node_or_null("Card_Image")
	if card_image_node:
		card_image_node.texture = load("res://Assets/%sCard.png" % card_drawn_name)
	# Assign Attack and Health safely
	var attack_label = new_card.get_node_or_null("Attack")
	if attack_label:
		attack_label.text = str(card_database_reference.CARDS[card_drawn_name][0])
	var health_label = new_card.get_node_or_null("Health")
	if health_label:
		health_label.text = str(card_database_reference.CARDS[card_drawn_name][1])
	# Add to CardManager and PlayerHand
	var card_manager = get_node("../CardManager")
	var player_hand = get_node("../PlayerHand")
	if card_manager:
		card_manager.add_child(new_card)
	if player_hand:
		player_hand.add_card_to_hand(new_card, CARD_DRAW_SPEED)
	# Play flip animation if exists
	var anim_player = new_card.get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.play("card_flip")

func start_new_turn() -> void:
	cards_drawn_this_turn = 0

func show_max_card_popup() -> void:
	var popup = Label.new()
	popup.text = "You’ve selected the maximum number of cards for this turn!"
	popup.add_theme_color_override("font_color", Color.WHITE)
	popup.add_theme_font_size_override("font_size", 22)
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
