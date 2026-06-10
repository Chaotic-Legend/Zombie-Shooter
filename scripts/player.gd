extends CharacterBody2D
class_name Player

signal died
signal health_changed(current_hp: int, max_hp: int)

@onready var camera_remote_transform = $CameraRemoteTransform
@onready var shoot_raycast = $ShootRaycast
@onready var shoot_sound = $ShootSound
@onready var hurt_sound = $HurtSound
@onready var death_sound = $DeathSound
@onready var laser_line = $LaserLine2D
@onready var animplayer = $AnimationPlayer

@export var max_hp := 10
@export var damage_cooldown := 1.0

var speed = 325.0
var sprint_multiplier = 2.0
var laser_on := false
var aim_position := Vector2.RIGHT
var current_hp := 10
var is_dead := false
var can_take_damage := true
var touching_enemies: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)
	laser_line.visible = laser_on
	set_aim_position(global_position + Vector2.RIGHT)

func set_aim_position(new_aim_position: Vector2) -> void:
	aim_position = new_aim_position
	look_at(aim_position)

func _process(_delta: float) -> void:
	if is_dead:
		return
	look_at(aim_position)
	if Input.is_action_just_pressed("toggle_laser"):
		laser_on = !laser_on
		laser_line.visible = laser_on
		if laser_line.visible:
			animplayer.play("turn_laser_on")
	if shoot_raycast.is_colliding():
		var cp = shoot_raycast.get_collision_point()
		var local_cp = to_local(cp)
		laser_line.points[1] = local_cp
	else:
		laser_line.points[1] = Vector2(2000, 0)
	if Input.is_action_just_pressed("shoot"):
		shoot_sound.play()
		if shoot_raycast.is_colliding():
			var collider = shoot_raycast.get_collider()
			if collider is StaticBody2D:
				print("Shot a box.\n")
			elif collider is Zombie:
				collider.take_damage(1, self)

func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	damage_from_touching_enemies()
	var move_dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	var current_speed = speed
	if Input.is_action_pressed("sprint"):
		current_speed *= sprint_multiplier
	if move_dir != Vector2.ZERO:
		velocity = current_speed * move_dir.normalized()
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.y = move_toward(velocity.y, 0, current_speed)
	move_and_slide()

func take_damage(amount: int) -> void:
	if is_dead or !can_take_damage:
		return
	if amount <= 0:
		return
	can_take_damage = false
	current_hp = clamp(current_hp - amount, 0, max_hp)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		die()
		return
	if hurt_sound:
		hurt_sound.stop()
		hurt_sound.play()
	if animplayer:
		animplayer.play("take_damage")
	await get_tree().create_timer(damage_cooldown).timeout
	can_take_damage = true

func die() -> void:
	if is_dead:
		return
	is_dead = true
	can_take_damage = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if shoot_sound:
		shoot_sound.stop()
	if hurt_sound:
		hurt_sound.stop()
	died.emit()
	if death_sound:
		death_sound.play()
		death_sound.reparent(get_tree().current_scene)
	queue_free()

func _on_hit_box_body_entered(body: Node2D) -> void:
	if body is Zombie and !touching_enemies.has(body):
		touching_enemies.append(body)
	damage_from_touching_enemies()

func _on_hit_box_body_exited(body: Node2D) -> void:
	if touching_enemies.has(body):
		touching_enemies.erase(body)

func damage_from_touching_enemies() -> void:
	if is_dead or !can_take_damage:
		return
	for enemy in touching_enemies.duplicate():
		if !is_instance_valid(enemy):
			touching_enemies.erase(enemy)
			continue
		if enemy is Zombie:
			take_damage(1)
			return
