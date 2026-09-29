class_name BaseCardMovement extends Node

@export_group("Nodes and Shit")
@export var texture: Texture2D = null
@export var base_card: Button = null

@export var angle_x_max: float = 15.0
@export var angle_y_max: float = 15.0
@export var max_offset_shadow: float = 50.0
@export var default_scaling: float = 3.0

@export var max_tilt_deg: float = 20.0
@export var full_tilt_speed: float = 1200.0   # px/s that gives max tilt

@export var pickup_scale_mult: float = 1.15


@export_category("Oscillator")
@export var spring: float = 150.0
@export var damp: float = 10.0
@export var velocity_multiplier: float = 2.0

@export_category("Follow")
@export var follow_frequency: float = 18.0     # natural frequency ω (rad/s): higher = faster rise time
@export_range(0.1, 2.0, 0.05) var follow_damping_ratio: float = 0.8  # ζ


var follow_velocity: Vector2 = Vector2.ZERO

var displacement: float = 0.0 
var oscillator_velocity: float = 0.0

var tween_rot: Tween
var tween_hover: Tween
var tween_destroy: Tween
var tween_handle: Tween

var last_mouse_pos: Vector2
var mouse_velocity: Vector2
var following_mouse: bool = false
var last_pos: Vector2
var velocity: Vector2
var shadow_base_pos: Vector2
var grab_local: Vector2

var tween_shadow: Tween

@onready var card_texture: TextureRect = %CardTexture
@onready var shadow = %Shadow

func _ready() -> void:
	#Nodes and shit
	if not base_card:
		printerr("BASE CARD NOT CONNECTED ON " + str(base_card.name))
	if texture != null:
		printerr("TEXTURE NOT CONNECTED ON " + str(base_card.name))
		card_texture.texture = texture
		
	angle_x_max = deg_to_rad(angle_x_max)
	angle_y_max = deg_to_rad(angle_y_max)
	shadow_base_pos = shadow.position   # replaces shadow_base_x

	# Natural, unscaled size = the texture's size
	base_card.custom_minimum_size = card_texture.texture.get_size()
	base_card.size = base_card.custom_minimum_size

	# Scale and rotate around the center
	base_card.pivot_offset = base_card.size / 2.0
	base_card.resized.connect(func(): base_card.pivot_offset = base_card.size / 2.0)

	base_card.scale = Vector2.ONE * default_scaling
	


func _process(delta: float) -> void:
	rotate_velocity(delta)
	follow_mouse(delta)
	handle_shadow(delta)
	
func destroy() -> void:
	card_texture.use_parent_material = true
	if tween_destroy and tween_destroy.is_running():
		tween_destroy.kill()
	tween_destroy = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_destroy.tween_property(base_card.material, "shader_parameter/dissolve_value", 0.0, 2.0).from(1.0)
	tween_destroy.parallel().tween_property(shadow, "self_modulate:a", 0.0, 1.0)

func rotate_velocity(delta: float) -> void:
	if not following_mouse: return

	# Smoothed velocity (raw frame-to-frame velocity is noisy)
	var raw_velocity: Vector2 = (base_card.position - last_pos) / delta
	last_pos = base_card.position
	velocity = velocity.lerp(raw_velocity, 1.0 - exp(-20.0 * delta))

	# Spring toward a target angle based on sideways speed
	var target: float = clampf(velocity.x / full_tilt_speed, -1.0, 1.0) * deg_to_rad(max_tilt_deg)
	var force: float = spring * (target - displacement) - damp * oscillator_velocity
	oscillator_velocity += force * delta
	displacement += oscillator_velocity * delta

	base_card.rotation = displacement

func handle_shadow(_delta: float) -> void:
	var center: Vector2 = base_card.get_viewport_rect().size / 2.0
	# Check distance from center of screen to center of card
	var card_center_x: float = base_card.global_position.x + (base_card.size.x * base_card.scale.x / 2.0)
	var distance: float = card_center_x - center.x
	
	var t: float = clampf(absf(distance) / center.x, 0.0, 1.0)
	
	# Push OUTWARD from center: positive distance -> positive offset (right)
	var offset_x: float = signf(distance) * max_offset_shadow * t
	
	# Base position Y remains, but X is purely driven by the light offset
	shadow.position.x = offset_x / base_card.scale.x

func follow_mouse(delta: float) -> void:
	if not following_mouse: return
	
	# Target position is mouse position minus original click offset
	var target_pos: Vector2 = base_card.get_global_mouse_position() - grab_offset
	var error: Vector2 = target_pos - base_card.global_position

	var w: float = follow_frequency
	var accel: Vector2 = w * w * error - 2.0 * follow_damping_ratio * w * follow_velocity
	follow_velocity += accel * delta
	base_card.global_position += follow_velocity * delta

var grab_offset: Vector2 = Vector2.ZERO

func handle_mouse_click(event: InputEvent) -> void:
	if not event is InputEventMouseButton: return
	if event.button_index != MOUSE_BUTTON_LEFT: return

	if event.is_pressed():
		# Store the distance from global_position to the mouse
		grab_offset = base_card.get_global_mouse_position() - base_card.global_position
		last_pos = base_card.position
		velocity = Vector2.ZERO
		follow_velocity = Vector2.ZERO
		displacement = 0.0
		oscillator_velocity = 0.0
		following_mouse = true
		_tween_shadow(1.0, 0.2)

		if tween_rot and tween_rot.is_running():
			tween_rot.kill()
		card_texture.material.set_shader_parameter("x_rot", 0.0)
		card_texture.material.set_shader_parameter("y_rot", 0.0)

		_tween_scale(default_scaling * pickup_scale_mult, 0.35)
	else:
		following_mouse = false
		follow_velocity = Vector2.ZERO
		_tween_shadow(0.0, 0.25)
		if tween_handle and tween_handle.is_running():
			tween_handle.kill()
		tween_handle = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween_handle.tween_property(base_card, "rotation", 0.0, 0.3)

		# Back to hover size if still under the cursor, otherwise resting size
		var rest: float = default_scaling * (1.2 if base_card.is_hovered() else 1.0)
		_tween_scale(rest, 0.55)

func _tween_scale(target: float, duration: float) -> void:
	if tween_hover and tween_hover.is_running():
		tween_hover.kill()
	tween_hover = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween_hover.tween_property(base_card, "scale", Vector2.ONE * target, duration)

func _on_gui_input(event: InputEvent) -> void:
	
	handle_mouse_click(event)
	
	# Don't compute rotation when moving the card
	if following_mouse: return
	if not event is InputEventMouseMotion: return
	
	# Handles rotation
	# Get local mouse pos
	var mouse_pos: Vector2 = base_card.get_local_mouse_position()
	#print("Mouse: ", mouse_pos)
	#print("Card: ", position + size)
	var diff: Vector2 = (base_card.position + base_card.size) - mouse_pos

	var lerp_val_x: float = remap(mouse_pos.x, 0.0, base_card.size.x, 0, 1)
	var lerp_val_y: float = remap(mouse_pos.y, 0.0, base_card.size.y, 0, 1)
	#print("Lerp val x: ", lerp_val_x)
	#print("lerp val y: ", lerp_val_y)

	var rot_x: float = rad_to_deg(lerp_angle(-angle_x_max, angle_x_max, lerp_val_x))
	var rot_y: float = rad_to_deg(lerp_angle(angle_y_max, -angle_y_max, lerp_val_y))
	print("Rot x: ", rot_x)
	print("Rot y: ", rot_y)
	
	card_texture.material.set_shader_parameter("x_rot", rot_y)
	card_texture.material.set_shader_parameter("y_rot", rot_x)

func _on_mouse_entered() -> void:
	if following_mouse: return
	if tween_hover and tween_hover.is_running():
		tween_hover.kill()
	tween_hover = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween_hover.tween_property(base_card, "scale", Vector2.ONE * default_scaling * 1.2, 0.5)


func _on_mouse_exited() -> void:
	# Reset rotation
	if following_mouse: return
	if tween_rot and tween_rot.is_running():
		tween_rot.kill()
	tween_rot = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_parallel(true)
	tween_rot.tween_property(card_texture.material, "shader_parameter/x_rot", 0.0, 0.5)
	tween_rot.tween_property(card_texture.material, "shader_parameter/y_rot", 0.0, 0.5)
	
	# Reset scale
	if tween_hover and tween_hover.is_running():
		tween_hover.kill()
	tween_hover = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween_hover.tween_property(base_card, "scale", Vector2.ONE * default_scaling, 0.55)


func _tween_shadow(target_alpha: float, duration: float) -> void:
	if tween_shadow and tween_shadow.is_running():
		tween_shadow.kill()
	tween_shadow = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_shadow.tween_property(shadow, "modulate:a", target_alpha, duration)
