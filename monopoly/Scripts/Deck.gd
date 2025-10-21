extends Node2D

const CARD_SCENE_PATH = "res://scenes/card.tscn"
const CARD_DRAW_SPEED = 0.2
const STARTING_HAND_SIZE = 5
const MAX_CARDS_PER_TURN = 2

var player_deck = ["Knight", "Knight", "Knight", "Knight", "Knight", "Knight", "Knight", "Knight"]
var cards_drawn_this_turn := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Update the deck counter
	update_deck_label()
	# Draw the starting hand
	for i in range(STARTING_HAND_SIZE):
		draw_card(true)

func update_deck_label() -> void:
	$RichTextLabel.text = str(player_deck.size())

func draw_card(force_draw := false) -> void:
	# Prevent drawing if already drew 2 cards this turn, unless forced (for starting hand)
	if not force_draw and cards_drawn_this_turn >= MAX_CARDS_PER_TURN:
		show_max_card_popup()  
		return
	# If deck is empty, stop drawing
	if player_deck.is_empty():
		return
	# Draw the top card
	var card_drawn = player_deck[0]
	player_deck.erase(card_drawn)
	if not force_draw:
		cards_drawn_this_turn += 1
	# Update UI
	update_deck_label()
	# Disable deck visuals if empty
	if player_deck.is_empty():
		$Area2D/CollisionShape2D.disabled = true
		$Sprite2D.visible = false
		$RichTextLabel.visible = false
	# Instantiate the card scene
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	new_card.name = "Card"
	# Add to the player's hand
	$"../CardManager".add_child(new_card)
	$"../PlayerHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)

func start_new_turn() -> void:
	# Reset draw counter each turn
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
	tween.tween_property(popup, "modulate:a", 1.0, 0.3)  # fade in
	tween.tween_interval(1.5)
	tween.tween_property(popup, "modulate:a", 0.0, 0.5)  # fade out
	await tween.finished
	popup.queue_free()
