extends Node2D

func _ready() -> void:
	var discard_scene = preload("res://scenes/discard_slot.tscn")
	var discard_instance = discard_scene.instantiate()
	discard_instance.position = Vector2(152, 774)  # Adjust to visible area
	add_child(discard_instance)
	# Hide gameplay elements at start
	$Deck.visible = false
	$RulesPrompt/RulesText.visible = false
	$RulesPrompt/StartGameButton.visible = false
	# Connect buttons
	$RulesPrompt/Panel/YesButton.pressed.connect(_on_yes_pressed)
	$RulesPrompt/Panel/NoButton.pressed.connect(_on_no_pressed)
	$RulesPrompt/StartGameButton.pressed.connect(_on_start_game_pressed)

func _on_yes_pressed() -> void:
	$RulesPrompt/RulesText.text = """Game Rules:
How to play
Deal: Each player starts with 5 cards
Turn: Draw two cards 
Action: Play up to three cards from your hand
Bank: Money and action cards with a money value go into your bank
Properties: Place property cards in the card slots in front of you. Stack same-colored properties together and start a new pile for different colors. 
End turn: You cannot have more than seven cards in your hand at the end of your turn. Discard any excess cards. 
Winning the game
The first player to collect three full property sets of different colors wins the game. 
You can win with two of the same color property set, as long as there are other full sets of different colors. 
"""
	$RulesPrompt/RulesText.visible = true
	$RulesPrompt/StartGameButton.visible = true
	$RulesPrompt/Panel/YesButton.visible = false
	$RulesPrompt/Panel/NoButton.visible = false
	hide_rules_label()

func hide_rules_label():
	if $RulesPrompt/Panel/Label:
		$RulesPrompt/Panel/Label.visible = false

func _on_no_pressed() -> void:
	_start_game()

func _on_start_game_pressed() -> void:
	_start_game()

func _start_game() -> void:
	$RulesPrompt.visible = false
	$Deck.visible = true
	if $Deck.has_method("_ready"):
		$Deck._ready()
	$Deck.start_deck()
	
