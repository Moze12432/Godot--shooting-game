extends CharacterBody3D

# Signals
signal player_hit
signal player_died

# Movement
var speed: float
const WALK_SPEED := 8.0
const SPRINT_SPEED := 12.0
const JUMP_VELOCITY := 4.5
const SENSITIVITY := 0.004
const HIT_STAGGER := 8.0

# Health
var max_life := 100
var current_life := max_life
var life_drain_per_hit := 10
var is_invulnerable := false
var gravity = 9.8

# Camera Effects
const BOB_FREQ := 2.4
const BOB_AMP := 0.08
var t_bob := 0.0
const BASE_FOV := 75.0
const FOV_CHANGE := 1.5

# Weapons
var bullet = preload("res://Scenes/Bullet.tscn")
var can_shoot := true
var shoot_cooldown := 0.15
var current_gun := "right"  # "right" or "left"
# Nodes
@onready var head := $Head
@onready var camera := $Head/Camera3D
@onready var right_gun_anim := $Head/Camera3D/Rifle/AnimationPlayer
@onready var right_gun_barrel := $Head/Camera3D/Rifle/RayCast3D
@onready var left_gun_anim := $Head/Camera3D/Rifle2/AnimationPlayer
@onready var left_gun_barrel := $Head/Camera3D/Rifle2/RayCast3D
@onready var collision_shape := $CollisionShape3D
@onready var gunshot_sound = $GunshotSound

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle Sprint.
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 15.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 15.0)
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
	
	# Head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	# Shooting
	if Input.is_action_pressed("shoot") and can_shoot:
		can_shoot = false
		
		# Fire right gun
		right_gun_anim.play("Shoot")
		var right_bullet = bullet.instantiate()
		get_parent().add_child(right_bullet)
		right_bullet.global_transform = right_gun_barrel.global_transform
		right_bullet.position += right_bullet.transform.basis * Vector3(0, 0, -0.5)
		
		# Fire left gun
		left_gun_anim.play("Shoot")
		var left_bullet = bullet.instantiate()
		get_parent().add_child(left_bullet)
		left_bullet.global_transform = left_gun_barrel.global_transform
		left_bullet.position += left_bullet.transform.basis * Vector3(0, 0, -0.5)
		
		gunshot_sound.play()
		
		await get_tree().create_timer(shoot_cooldown).timeout
		can_shoot = true
	
	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func hit(dir: Vector3):
	if is_invulnerable:
		return
	
	is_invulnerable = true
	emit_signal("player_hit")
	current_life = max(0, current_life - life_drain_per_hit)
	velocity += dir * HIT_STAGGER
	
	if current_life <= 0:
		die()
	
	await get_tree().create_timer(0.5).timeout
	is_invulnerable = false

func die():
	set_physics_process(false)
	set_process_unhandled_input(false)
	collision_shape.set_deferred("disabled", true)
	emit_signal("player_died")

func reset_player():
	# Reset all player states
	current_life = max_life
	velocity = Vector3.ZERO
	is_invulnerable = false
	can_shoot = true
	
	# Reset guns
	right_gun_anim.stop(true)
	left_gun_anim.stop(true)
	
	# Enable processing
	set_physics_process(true)
	set_process_unhandled_input(true)
	
	# Reset camera
	camera.rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
