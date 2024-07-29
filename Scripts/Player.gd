extends CharacterBody3D

# Thejordster135

# Speed variables.
var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const CROUCH_SPEED = 3.0
var JUMP_VELOCITY = 4.0
const WALL_JUMP_VELOCITY = 13.5
const SENSITIVITY = 0.1

# Other
var lerp_speed = 10.0
var height_lerp_speed = 8.0
var crouching_depth = -0.5 # Height for crouching.
var current_head_height = 0.0 # Standing head height (starting with this (It's 0.0 because it is a child of the head)).
var target_head_height = 0.0 # Will be changed based on state.
var free_looking_tilt = -0.08 # To make free looking more realistic.
var wall_tilt_left = -0.2
var wall_tilt_right = 0.2
var head_bobbing = false
var can_shoot = false
var can_shoot_ak = false

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

# Sliding variables.
var slide_timer = 0.0
var slide_timer_max = 1.4
var slide_vec = Vector2.ZERO
var slide_speed = 9.3
var can_slide = true

# Wall stuff.
const FLOOR = 0
const WALL = 1
const AIR =2
var current_state := AIR

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8

# Export variables.
@export var default_cavas : CanvasLayer
@export var pistol_canvas : CanvasLayer
@export var AK_canvas : CanvasLayer
@export var AK_sprite : AnimatedSprite2D
@export var AK_shot_sound : AudioStreamPlayer
@export var pistol_sprite : AnimatedSprite2D
@export var pistol_shot_sound : AudioStreamPlayer
@export var can_shoot_ray : RayCast3D
@export var player : CharacterBody3D
@export var neck : Node3D
@export var head : Node3D
@export var camera : Camera3D
@export var slide_check : RayCast3D
@export var crouch_check : RayCast3D
@export var up_hill_check : RayCast3D
@export var left_wall_check : ShapeCast3D
@export var right_wall_check : ShapeCast3D
@export var standing_collison : CollisionShape3D
@export var crouching_collison : CollisionShape3D
@export var crouching_mesh : MeshInstance3D
@export var standing_mesh : MeshInstance3D
@export var slide_cooldown : Timer



func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pistol_canvas.hide()
	AK_canvas.hide()

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * SENSITIVITY))
			neck.rotation.x = clamp(neck.rotation.x, deg_to_rad(-70), deg_to_rad(80))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		else:
			self.rotate_y(deg_to_rad(-event.relative.x * SENSITIVITY))
			camera.rotate_x(deg_to_rad(-event.relative.y * SENSITIVITY))
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-70), deg_to_rad(80))
		

func _physics_process(delta):
	# Get Movement Input.
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	# Falling gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle Weapon Switching.
	if Input.is_action_just_pressed("AK"):
		if !AK_canvas.visible:
			default_cavas.hide()
			pistol_canvas.hide()
			AK_canvas.show()
			can_shoot_ak = true
			can_shoot = false
		else:
			default_cavas.show()
			pistol_canvas.hide()
			AK_canvas.hide()
			can_shoot_ak = false
			can_shoot = false
			
	if Input.is_action_just_pressed("pistol"):
		if !pistol_canvas.visible:
			default_cavas.hide()
			AK_canvas.hide()
			pistol_canvas.show()
			can_shoot_ak = false
			can_shoot = true
		else:
			default_cavas.show()
			pistol_canvas.hide()
			AK_canvas.hide()
			can_shoot_ak = false
			can_shoot = false
	
	
	# Handle Sprinting.
	if Input.is_action_pressed("crouch") or crouch_check.is_colliding() or sliding or Input.is_action_pressed("slide"):
		
		speed = CROUCH_SPEED
		camera.position.y = lerp(camera.position.y, current_head_height + crouching_depth, delta*height_lerp_speed)
		
		standing_collison.disabled = true
		crouching_collison.disabled = false
		crouching_mesh.show()
		standing_mesh.hide()
		
		# Slide starting logic.
		
		if sprinting && input_dir != Vector2.ZERO && can_slide:
			free_looking = true
			sliding = true
			slide_vec = input_dir
			slide_timer = slide_timer_max
		
		walking = false
		sprinting = false
		crouching = true
		
	else:
		standing_collison.disabled = false
		crouching_collison.disabled = true
		
		crouching_mesh.hide()
		standing_mesh.show()
		
		camera.position.y = lerp(camera.position.y, current_head_height, delta*height_lerp_speed)
		
		
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
	if Input.is_action_pressed("free_look") or sliding:
		free_looking = true
		camera.rotation.z = neck.rotation.y * free_looking_tilt
	else:
		free_looking = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * 8.0)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 8.0)
		
		if left_wall_check.is_colliding() && current_state == WALL:
			camera.rotation.z = lerp(camera.rotation.z, wall_tilt_left, delta * 12)
		if right_wall_check.is_colliding() && current_state == WALL:
			camera.rotation.z = lerp(camera.rotation.z, wall_tilt_right, delta * 12)
		
		else:
			camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 12)
	
	# Handle Slide Ending.
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0 or Input.is_action_just_released("slide") or Input.is_action_just_released("crouch"):
			sliding = false
			free_looking = false
			can_slide = false
			slide_cooldown.start()
		JUMP_VELOCITY = 8.0
	
	# Get the input direction and handle the movement/deceleration.
	gravity = 10
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			
			if sliding:
				velocity.x = direction.x * (slide_timer +0.1) * slide_speed
				velocity.z = direction.z * (slide_timer +0.1) * slide_speed
				if get_floor_angle() >= 5.0 && slide_check.is_colliding():
					velocity.x = direction.x * (slide_timer +0.1) * slide_speed * (get_floor_angle()/10.0)
					velocity.z = direction.z * (slide_timer +0.1) * slide_speed * (get_floor_angle()/10.0)
				elif get_floor_angle() >= 5.0 && up_hill_check.is_colliding():
					velocity.x = direction.x * (slide_timer +0.1) * slide_speed / get_floor_angle()
					velocity.z = direction.z * (slide_timer +0.1) * slide_speed / get_floor_angle()
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * lerp_speed)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * lerp_speed)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
	
	# Head Bob
	if !sliding:
	
		t_bob += delta * velocity.length() * float(is_on_floor())
		head.transform.origin = _headbob(t_bob)
		head.position += _headbob(t_bob)
		JUMP_VELOCITY = 4.0
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	move_and_slide()
	update_state()
	check_jump()
	wall_run()
	pistol_shot()
	AK_shot()
	
	# Smoothly interpolate the head height
	current_head_height = lerp(current_head_height, target_head_height, 8.0 * delta)

	if sliding:
		direction = transform.basis * Vector3(slide_vec.x,0,slide_vec.y).normalized()
		

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func update_state():
	if is_on_wall_only() && left_wall_check.is_colliding() or is_on_wall_only() && right_wall_check.is_colliding():
		current_state = WALL
	elif (left_wall_check.is_colliding() && not is_on_wall() or right_wall_check.is_colliding()) && not is_on_wall() && not is_on_floor():
		current_state = AIR
	elif is_on_floor():
		current_state = FLOOR
	elif not left_wall_check.is_colliding() && not right_wall_check.is_colliding() && not is_on_floor():
		current_state = AIR
	else:
		current_state = AIR
	
	
func wall_run():
	if not is_on_floor_only():
		if current_state == WALL && Input.is_action_pressed("sprint") && Input.is_action_pressed("forward") && speed >= 2:
			gravity = 1
		if left_wall_check.is_colliding() or right_wall_check.is_colliding() && current_state == WALL:
			velocity.y = -0.2
			gravity = 1
		else:
			gravity = 10.0

func check_jump():
	if Input.is_action_pressed("jump"):
		if current_state == FLOOR:
			velocity.y = JUMP_VELOCITY
			sliding = false
		elif current_state == WALL && not is_on_floor_only():
			velocity = get_wall_normal() * WALL_JUMP_VELOCITY * 1.5
			velocity.y = JUMP_VELOCITY * 5

func _on_slide_cooldown_timeout():
	can_slide = true

func pistol_shot():
	if !can_shoot:
		return
	if pistol_canvas.visible:
		if Input.is_action_pressed("left_mouse"):
				can_shoot = false
				pistol_sprite.play("pistol_fire")
				pistol_shot_sound.play()

func AK_shot():
	if !can_shoot_ak:
		return
	if AK_canvas.visible:
		if Input.is_action_pressed("left_mouse"):
			can_shoot_ak = false
			AK_sprite.play("ak_fire")
			AK_shot_sound.play()


func shoot_anim_done():
	can_shoot = true


func ak_shoot_anim_done():
	can_shoot_ak = true
