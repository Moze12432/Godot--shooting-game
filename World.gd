extends Node3D

@onready var hit_rect = $UI/HitRect
@onready var spawns = $Map/Spawns
@onready var navigation_region = $Map/NavigationRegion3D
@onready var life_bar = $UI/LifeBar
@onready var zombie_spawn_timer = $ZombieSpawnTimer

var zombies_killed := 0
var player : Node3D
var zombie = load("res://Scenes/Zombie.tscn")
var game_over_screen = preload("res://Scenes/GameOver.tscn")

func _ready():
	randomize()
	player = get_node("Map/NavigationRegion3D/Player")
	
	if player.player_hit.connect(_on_player_hit) != OK:
		push_error("Failed to connect player_hit signal")
	
	if player.player_died.connect(player_died) != OK:
		push_error("Failed to connect player_died signal")
	
	if life_bar:
		life_bar.max_value = player.max_life
		life_bar.value = player.current_life
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Reset spawn timer
	zombie_spawn_timer.start()

func _on_player_hit():
	if not is_instance_valid(hit_rect) or not is_instance_valid(player):
		return
	
	hit_rect.visible = true
	if life_bar and is_instance_valid(player):
		life_bar.value = player.current_life
		life_bar.modulate = Color.RED if player.current_life < 30 else Color.GREEN
	
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(hit_rect):
		hit_rect.visible = false

func _get_random_child(parent_node):
	return parent_node.get_child(randi() % parent_node.get_child_count())

func _on_zombie_spawn_timer_timeout():
	var spawn_point = _get_random_child(spawns).global_position
	var instance = zombie.instantiate()
	instance.position = spawn_point
	navigation_region.add_child(instance)
	# Connect the zombie's death signal when spawned
	instance.tree_exited.connect(_on_zombie_died)

func player_died():
	zombie_spawn_timer.stop()
	get_tree().paused = true
	
	for zombie in get_tree().get_nodes_in_group("enemies"):
		zombie.queue_free()
	
	var game_over = game_over_screen.instantiate()
	add_child(game_over)
	game_over.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_zombie_died():
	zombies_killed += 1
	print("Zombies killed: ", zombies_killed)
	
func get_kill_count() -> int:
	return zombies_killed
