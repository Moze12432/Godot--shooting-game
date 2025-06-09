extends CanvasLayer

@onready var retry_button: Button = $MarginContainer/VBoxContainer/RetryButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/QuitButton
@onready var kill_label: Label = $MarginContainer/VBoxContainer/KillLabel

func _ready():
	# Make sure UI is on top and interactive
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect signals
	retry_button.pressed.connect(_on_retry_pressed.bind())
	quit_button.pressed.connect(_on_quit_pressed.bind())
	
	# Show mouse and focus button
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	retry_button.grab_focus()
	
	var world = get_tree().root.get_node_or_null("World")
	if world and world.has_method("get_kill_count"):
		kill_label.text = "Zombies Killed: %d" % world.get_kill_count()
	else:
		kill_label.text = "Zombies Killed: 0"

func _on_retry_pressed():
	print("Performing complete game reset...")
	
	# 1. Unpause everything
	get_tree().paused = false
	
	# 2. Clean up all game nodes
	var world = get_tree().root.get_node_or_null("World")
	if world:
		world.queue_free()
		await world.tree_exited
	
	# 3. Remove all remaining nodes except the root
	for child in get_tree().root.get_children():
		if child != self:
			child.queue_free()
	
	# 4. Create fresh instances
	var new_world = load("res://Scenes/World.tscn").instantiate()
	
	# 5. Add to scene tree and reset everything
	get_tree().root.add_child(new_world)
	
	# 6. Reset input and camera
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 7. Remove game over screen
	queue_free()

func _on_quit_pressed():
	if OS.has_feature("web"):
		get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
	else:
		get_tree().quit()
