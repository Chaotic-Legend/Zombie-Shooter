extends CharacterBody2D
class_name Zombie

signal killed

@onready var animplayer = $AnimationPlayer
@onready var hurt_sound = $HurtSound
@onready var death_sound = $DeathSound

var player: Player = null
var speed: float = 125.0
var direction := Vector2.ZERO
var stop_distance := 20.0
var close_chase_distance := 260.0
var hit_points: int = 3
var alerted := false
var is_dead := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("zombies")
	refresh_player_reference()

func _process(_delta: float) -> void:
	refresh_player_reference()
	if should_follow_player():
		look_at(player.global_position)

func _physics_process(_delta: float) -> void:
	refresh_player_reference()
	if !should_follow_player():
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.y = move_toward(velocity.y, 0, speed)
		move_and_slide()
		return
	var enemy_to_player = player.global_position - global_position
	if enemy_to_player.length() > stop_distance:
		direction = enemy_to_player.normalized()
	else:
		direction = Vector2.ZERO
	if direction != Vector2.ZERO:
		velocity = speed * direction
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.y = move_toward(velocity.y, 0, speed)
	move_and_slide()

func refresh_player_reference() -> void:
	if is_instance_valid(player):
		return
	player = null
	var players = get_tree().get_nodes_in_group("player")
	for possible_player in players:
		if possible_player is Player and is_instance_valid(possible_player):
			player = possible_player
			return

func should_follow_player() -> bool:
	if !is_instance_valid(player):
		return false
	if alerted:
		return true
	if global_position.distance_to(player.global_position) <= close_chase_distance:
		alerted = true
		return true
	return false

func force_target(new_player: Player) -> void:
	if is_instance_valid(new_player):
		player = new_player

func _on_player_detector_body_entered(body: Node2D) -> void:
	if body is Player:
		player = body

func _on_player_detector_body_exited(body: Node2D) -> void:
	if body is Player and !alerted:
		player = null

func take_damage(amount: int, attacker: Player = null) -> void:
	if amount <= 0 or is_dead:
		return
	if is_instance_valid(attacker):
		player = attacker
		alerted = true
	hit_points -= amount
	if hit_points <= 0:
		is_dead = true
		print(name + " has died.\n")
		killed.emit()
		set_physics_process(false)
		set_process(false)
		velocity = Vector2.ZERO
		player = null
		if hurt_sound:
			hurt_sound.stop()
		if death_sound:
			death_sound.play()
		await death_sound.finished
		queue_free()
		return
	if hurt_sound:
		hurt_sound.stop()
		hurt_sound.play()
	animplayer.play("take_damage")
