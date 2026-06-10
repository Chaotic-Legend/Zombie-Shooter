extends Node2D

@onready var player: Player = $Player
@onready var main_camera = $MainCamera
@onready var pause_label = $UI/CenterContainer/PauseLabel
@onready var crosshair = $UI/Crosshair
@onready var hp_panel = $UI/HPPanel
@onready var health_bar = $UI/HPPanel/UIHealthBar
@onready var zombies_killed_label = $UI/ZombiesKilledLabel
@onready var background_music = $BackgroundMusic

var paused := false
var mouse_debug := false
var player_dead := false
var zombies_killed := 0
var last_crosshair_position := Vector2.ZERO
var start_aim_offset := Vector2(220, 0)
var minimum_crosshair_distance := 90.0

func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	$UI.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_label.visible = false
	update_zombies_killed_label()
	set_process_input(true)
	if is_instance_valid(player):
		player.add_to_group("player")
		player.died.connect(_on_player_died)
		player.health_changed.connect(_on_player_health_changed)
		player.camera_remote_transform.remote_path = main_camera.get_path()
	setup_health_bar()
	await get_tree().process_frame
	set_starting_aim()
	refresh_zombie_targets()
	setup_background_music()
	apply_mouse_state()

func setup_health_bar() -> void:
	if hp_panel != null:
		var panel_stylebox := StyleBoxFlat.new()
		panel_stylebox.bg_color = Color.TRANSPARENT
		panel_stylebox.border_color = Color.BLACK
		panel_stylebox.border_width_left = 4
		panel_stylebox.border_width_top = 4
		panel_stylebox.border_width_right = 4
		panel_stylebox.border_width_bottom = 4
		panel_stylebox.corner_radius_top_left = 6
		panel_stylebox.corner_radius_top_right = 6
		panel_stylebox.corner_radius_bottom_left = 6
		panel_stylebox.corner_radius_bottom_right = 6
		hp_panel.add_theme_stylebox_override("panel", panel_stylebox)
	if health_bar == null:
		return
	var fill_stylebox := StyleBoxFlat.new()
	fill_stylebox.bg_color = Color(0.2, 0.85, 0.2, 1)
	fill_stylebox.corner_radius_top_left = 4
	fill_stylebox.corner_radius_top_right = 4
	fill_stylebox.corner_radius_bottom_left = 4
	fill_stylebox.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("fill", fill_stylebox)
	var background_stylebox := StyleBoxFlat.new()
	background_stylebox.bg_color = Color(0.15, 0.05, 0.05, 1)
	background_stylebox.corner_radius_top_left = 4
	background_stylebox.corner_radius_top_right = 4
	background_stylebox.corner_radius_bottom_left = 4
	background_stylebox.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("background", background_stylebox)
	health_bar.show_percentage = false
	if is_instance_valid(player):
		_on_player_health_changed(player.current_hp, player.max_hp)

func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	if health_bar == null:
		return
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	if max_hp > 0:
		var fill_stylebox = health_bar.get_theme_stylebox("fill")
		if fill_stylebox is StyleBoxFlat:
			fill_stylebox.bg_color = lerp(Color(0.9, 0.05, 0.05, 1), Color(0.2, 0.85, 0.2, 1),
			float(current_hp) / float(max_hp))

func setup_background_music() -> void:
	if background_music == null:
		return
	background_music.process_mode = Node.PROCESS_MODE_ALWAYS
	if !background_music.finished.is_connected(_on_background_music_finished):
		background_music.finished.connect(_on_background_music_finished)
	background_music.stream_paused = false
	background_music.play()

func _on_background_music_finished() -> void:
	if background_music != null:
		background_music.play()

func set_starting_aim() -> void:
	if !is_instance_valid(player):
		return
	last_crosshair_position = player.get_global_transform_with_canvas().origin + start_aim_offset
	crosshair.position = last_crosshair_position - crosshair.size * 0.5
	get_viewport().warp_mouse(last_crosshair_position)
	player.set_aim_position(player.global_position + Vector2.RIGHT)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_debug"):
		mouse_debug = !mouse_debug
		if !mouse_debug:
			get_viewport().warp_mouse(last_crosshair_position)
			crosshair.position = last_crosshair_position - crosshair.size * 0.5
			if is_instance_valid(player):
				player.set_aim_position(screen_to_world(last_crosshair_position))
		apply_mouse_state()
		refresh_zombie_targets()
	elif event.is_action_pressed("pause"):
		toggle_pause()
	elif event.is_action_pressed("reset"):
		if background_music != null:
			background_music.stop()
			background_music.stream_paused = false
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().reload_current_scene()
		return
	elif event.is_action_pressed("quit"):
		get_tree().quit()

func _process(_delta: float) -> void:
	if paused or player_dead or !is_instance_valid(player):
		return
	if !mouse_debug:
		last_crosshair_position = get_locked_crosshair_screen_position(get_viewport().get_mouse_position())
		crosshair.position = last_crosshair_position - crosshair.size * 0.5
	player.set_aim_position(screen_to_world(last_crosshair_position))

func get_locked_crosshair_screen_position(screen_position: Vector2) -> Vector2:
	if !is_instance_valid(player):
		return screen_position
	var player_screen_position = player.get_global_transform_with_canvas().origin
	var aim_direction = screen_position - player_screen_position
	if aim_direction.length() < minimum_crosshair_distance:
		var last_direction = last_crosshair_position - player_screen_position
		if last_direction.length() < 1.0:
			last_direction = Vector2.RIGHT
		return player_screen_position + last_direction.normalized() * minimum_crosshair_distance
	return screen_position

func screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

func toggle_pause() -> void:
	if player_dead:
		return
	paused = !paused
	if paused:
		if !mouse_debug:
			last_crosshair_position = get_locked_crosshair_screen_position(get_viewport().get_mouse_position())
		crosshair.position = last_crosshair_position - crosshair.size * 0.5
		if is_instance_valid(player):
			player.set_aim_position(screen_to_world(last_crosshair_position))
		get_tree().paused = true
		if background_music != null:
			background_music.stream_paused = true
	else:
		get_viewport().warp_mouse(last_crosshair_position)
		crosshair.position = last_crosshair_position - crosshair.size * 0.5
		if is_instance_valid(player):
			player.set_aim_position(screen_to_world(last_crosshair_position))
		get_tree().paused = false
		if background_music != null:
			background_music.stream_paused = false
		refresh_zombie_targets()
	pause_label.visible = paused
	apply_mouse_state()

func apply_mouse_state() -> void:
	if paused or mouse_debug or player_dead:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		crosshair.visible = false
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		crosshair.visible = true

func refresh_zombie_targets() -> void:
	if !is_instance_valid(player):
		return
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if zombie is Zombie and is_instance_valid(zombie):
			zombie.force_target(player)
			if !zombie.killed.is_connected(_on_zombie_killed):
				zombie.killed.connect(_on_zombie_killed)

func _on_zombie_killed() -> void:
	zombies_killed += 1
	update_zombies_killed_label()

func update_zombies_killed_label() -> void:
	if zombies_killed_label != null:
		zombies_killed_label.text = "ZOMBIES KILLED: " + str(zombies_killed)

func _on_player_died() -> void:
	player_dead = true
	paused = false
	get_tree().paused = false
	pause_label.visible = false
	apply_mouse_state()
	print("Game Over.\n")
	await get_tree().create_timer(1.5).timeout
	if background_music != null:
		background_music.stop()
		background_music.stream_paused = false
	get_tree().reload_current_scene()
