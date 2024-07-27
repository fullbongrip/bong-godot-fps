extends CharacterBody3D

# Speed variables.
var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const CROUCH_SPEED = 3.0
const JUMP_VELOCITY = 4.0
const SENSITIVITY = 0.1
var input_dir = Input.get_vector("left", "right", "forward", "back")

# Other
var lerp_speed = 10.0
var height_lerp_speed = 8.0
var crouching_depth = -0.5 # Height for crouching.
var current_head_height = 0.0 # Standing head height (starting with this (It's 0.0 because it is a child of the head)).
var target_head_height = 0.0 # Will be changed based on state.
var free_looking_tilt = -0.08 # To make free looking more realistic.

# States
var walking = false
var sprinting = false
var crouching = false
var free_looking = false
var sliding = false

# Sobbing variables.
const BOB_FREQ = 1.5
const BOB_AMP = 0.08
var t_bob = 0.0

# FOV variables.
var BASE_FOV = 95.0
const FOV_CHANGE = 1.04

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8

# Export variables.
@export var neck : Node3D
@export var head : Node3D
@export var camera : Camera3D
@export var slide_check : RayCast3D
@export var crouch_check : RayCast3D
@export var standing_collison : CollisionShape3D
@export var crouching_collison : CollisionShape3D
@export var crouching_mesh : MeshInstance3D
@export var standing_mesh : MeshInstance3D

# Sliding variables.
@export var slide_cooldown : Timer
var slide_timer = 0.0
var slide_timer_max = 1.4

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * SENSITIVITY))
			neck.rotation.x = clamp(neck.rotation.x, deg_to_rad(-70), deg_to_rad(80))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		else:
			head.rotate_y(deg_to_rad(-event.relative.x * SENSITIVITY))
			camera.rotate_x(deg_to_rad(-event.relative.y * SENSITIVITY))
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-70), deg_to_rad(80))

func _physics_process(delta):
	
	# Falling gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jumping.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle Sprinting.
	if Input.is_action_pressed("crouch") or crouch_check.is_colliding():
		
		speed = CROUCH_SPEED
		head.position.y = lerp(head.position.y, current_head_height + crouching_depth, delta*height_lerp_speed)
		
		standing_collison.disabled = true
		crouching_collison.disabled = false
		crouching_mesh.show()
		standing_mesh.hide()
		
		if sprinting && input_dir > 0.0:
			sliding = true
			slide_timer = slide_timer_max
		
		walking = false
		sprinting = false
		crouching = true
		
	else:
		standing_collison.disabled = false
		crouching_collison.disabled = true
		
		crouching_mesh.hide()
		standing_mesh.show()
		
		head.position.y = lerp(head.position.y, current_head_height, delta*height_lerp_speed)
		
		
		if Input.is_action_pressed("sprint"):
			speed = SPRINT_SPEED
			walking = false
			sprinting = true
			crouching = false
		else:
			speed = WALK_SPEED
			walking = true
			sprinting = false
			crouching = false

	# Handle Free Looking.
	if Input.is_action_pressed("free_look"):
		free_looking = true
		camera.rotation.z = neck.rotation.y * free_looking_tilt

	else:
		free_looking = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * 8.0)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 8.0)
	
	
	# Get the input direction and handle the movement/deceleration.
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * lerp_speed)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * lerp_speed)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
	
	# Head Bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	move_and_slide()
	
	# Smoothly interpolate the head height
	current_head_height = lerp(current_head_height, target_head_height, 8.0 * delta)


func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
