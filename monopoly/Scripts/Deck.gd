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
var initialized := false  # prevent multiple starts

func _ready() -> void:
	# Load card database once
	card_database_reference = $"../CardDatabase"
	# Hide deck visuals until the player starts the game
	set_deck_visible(false)
	update_deck_label()
	$"../EndTurnButton".pressed.connect(start_new_turn)

func start_deck() -> void:
	if initialized:
		return
	initialized = true
	player_deck.shuffle()
	set_deck_visible(true)
	update_deck_label()
	# Draw the starting hand after the player starts
	for i in range(STARTING_HAND_SIZE):
		draw_card(true)

func set_deck_visible(visible: bool) -> void:
	var sprite = get_node_or_null("Sprite2D")
	var area = get_node_or_null("Area2D/CollisionShape2D")
	var label = get_node_or_null("RichTextLabel")
	if sprite:
		sprite.visible = visible
	if area:
		area.disabled = not visible
	if label:
		label.visible = visible

func update_deck_label() -> void:
	var label = get_node_or_null("RichTextLabel")
	if label:
		label.text = str(player_deck.size())

func draw_card(force_draw := false) -> void:
	if not force_draw and cards_drawn_this_turn >= MAX_CARDS_PER_TURN:
		show_max_card_popup()
		return
	if player_deck.is_empty():
		return
	var card_drawn_name = player_deck[0]
	player_deck.erase(card_drawn_name)
	if not force_draw:
		cards_drawn_this_turn += 1
	update_deck_label()
	if player_deck.is_empty():
		set_deck_visible(false)
	else:
		set_deck_visible(true)
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	new_card.name = "Card"
	new_card.setup(card_database_reference.CARDS[card_drawn_name][0], card_database_reference.CARDS[card_drawn_name][1])
	var card_image_node = new_card.get_node_or_null("Card_Image")
	if card_image_node:
		card_image_node.texture = load("res://Assets/%sCard.png" % card_drawn_name)
	var card_manager = get_node("../CardManager")
	var player_hand = get_node("../PlayerHand")
	if card_manager:
		card_manager.add_child(new_card)
	if player_hand:
		player_hand.add_card_to_hand(new_card, CARD_DRAW_SPEED)
	var anim_player = new_card.get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.play("card_flip")
	

func start_new_turn() -> void:
	cards_drawn_this_turn = 0
	var counter = 0
	for col in card_database_reference.COLOURS:
		if counter > 1:
			win()
			return

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
	
func win():
	var popup = Label.new()
	popup.text = "You Won!"
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
