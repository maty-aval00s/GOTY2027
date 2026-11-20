class_name LobbyWaitingScreen
extends Control

const MATCH_SCENE_PATH: String = "res://scenes/match/match.tscn"

@onready var player_texture: TextureRect = %PlayerTexture
@onready var player_name: Label = %PlayerName
@onready var role_button: Button = %RoleButton
@onready var ready_button: Button = %ReadyButton
@onready var player_list: VBoxContainer = %PlayerList
@onready var waiting_label: Label = %WaitingLabel
@onready var back_button: Button = %BackButton
@onready var role_container: PanelContainer = %RoleContainer
@onready var role_list: VBoxContainer = %RoleList
@onready var start_timer: Timer = $StartTimer
@onready var game_start_container: PanelContainer = %GameStartContainer
@onready var game_start_counter: Label = %GameStartCounter
@onready var map_button: Button = %MapButton
@onready var map_container: PanelContainer = %MapContainer
@onready var map_list: VBoxContainer = %MapList

var LOBBY_PLAYER_SCENE: PackedScene = preload("res://lobby/lobby_player.tscn")
var _launching: bool = false


func _ready() -> void:
	_launching = false
	player_name.text = Game.instance.get_current_player().name
	ready_button.pressed.connect(_toggle_ready)
	Game.instance.players_updated.connect(_handle_players_updated)
	Game.instance.player_updated.connect(func(_id: int) -> void: _update_ready_button())
	Game.instance.vote_updated.connect(func(_id: int) -> void: _handle_vote_updated())
	LevelManager.level_changed.connect(func(_index: int) -> void: _refresh_map_ui())
	if _is_server():
		start_timer.timeout.connect(_on_start_timer_timeout)
	_handle_players_updated()
	role_button.visible = Game.instance.use_roles
	back_button.pressed.connect(_handle_back_pressed)
	role_button.pressed.connect(_handle_role_pressed)
	map_button.pressed.connect(_handle_map_pressed)
	role_container.hide()
	map_container.hide()
	game_start_container.hide()
	_fill_map_container()
	_update_ready_button()
	_refresh_map_ui()
	_update_map_controls()

	if Game.instance.use_roles:
		_fill_role_container()
		var role: Statics.Role = Game.instance.get_current_player().role
		role_button.text = Statics.get_role_name(role)
		if role == Statics.Role.NONE:
			role_button.text = "Role?"

	if _is_server():
		_sync_map_selection.rpc(LevelManager.current_level_index)


func _process(_delta: float) -> void:
	game_start_counter.text = str(int(ceil(start_timer.time_left)))


func _is_server() -> bool:
	return multiplayer != null and multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _toggle_ready() -> void:
	Game.instance.set_current_player_vote(not Game.instance.get_current_player().vote)
	_update_player()


func _update_player() -> void:
	var player_ready: bool = Game.instance.get_current_player().vote
	player_texture.modulate = Color.GREEN if player_ready else Color.WHITE
	role_container.hide()
	map_container.hide()


func _handle_players_updated() -> void:
	if _launching:
		return
	for child: Node in player_list.get_children():
		child.queue_free()
	waiting_label.visible = Game.instance.players.size() == 1
	for player: Statics.PlayerData in Game.instance.players:
		if player.id != multiplayer.get_unique_id():
			var lobby_player_inst: LobbyPlayer = LOBBY_PLAYER_SCENE.instantiate()
			lobby_player_inst.set_player(player)
			player_list.add_child(lobby_player_inst)
	_update_ready_button()
	if _is_server():
		Game.instance.reset_votes()
		_sync_map_selection.rpc(LevelManager.current_level_index)


func _handle_back_pressed() -> void:
	if _is_server():
		Lobby.instance.go_to_host()
	else:
		Lobby.instance.go_to_join()


func _handle_role_pressed() -> void:
	map_container.hide()
	role_container.visible = not role_container.visible


func _handle_map_pressed() -> void:
	if not _is_server() or not start_timer.is_stopped() or _launching:
		return
	role_container.hide()
	map_container.visible = not map_container.visible


func _fill_role_container() -> void:
	for i: int in Statics.Role.size() - 1:
		var button: Button = Button.new()
		button.text = Statics.get_role_name(i + 1)
		button.pressed.connect(func() -> void: _update_role(i + 1))
		role_list.add_child(button)


func _fill_map_container() -> void:
	for child: Node in map_list.get_children():
		child.queue_free()
	for i: int in LevelManager.get_level_count():
		var button: Button = Button.new()
		button.text = LevelManager.get_level_name(i)
		var map_index: int = i
		button.pressed.connect(func() -> void: _select_map(map_index))
		map_list.add_child(button)


func _update_role(role: Statics.Role) -> void:
	Game.instance.set_current_player_role(role)
	role_button.text = Statics.get_role_name(role)
	role_container.hide()


func _select_map(index: int) -> void:
	if not _is_server() or not start_timer.is_stopped() or _launching:
		return
	LevelManager.set_level_index(index)
	_sync_map_selection.rpc(LevelManager.current_level_index)
	map_container.hide()


func _handle_vote_updated() -> void:
	if _launching:
		return
	_update_player()
	if _is_server():
		var all_voted: bool = true
		for player: Statics.PlayerData in Game.instance.players:
			all_voted = all_voted and player.vote
		if all_voted and _can_start_game():
			_start_timer.rpc()
		elif not start_timer.is_stopped():
			_stop_timer.rpc()


@rpc("reliable", "call_local")
func _start_timer() -> void:
	if _launching:
		return
	start_timer.start()
	game_start_container.show()
	role_button.disabled = true
	map_container.hide()
	_update_map_controls()


@rpc("reliable", "call_local")
func _stop_timer() -> void:
	if _launching:
		return
	start_timer.stop()
	game_start_container.hide()
	role_button.disabled = false
	_update_map_controls()


func _on_start_timer_timeout() -> void:
	if not _is_server() or _launching:
		return
	_start_game.rpc(LevelManager.current_level_index)


@rpc("reliable", "call_local")
func _start_game(level_index: int) -> void:
	_launching = true
	start_timer.stop()
	LevelManager.set_level_index(level_index)
	get_tree().change_scene_to_file(MATCH_SCENE_PATH)


func _can_start_game() -> bool:
	var quantity: bool = Game.instance.players.size() >= Game.instance.min_players
	var completion: bool = not Game.instance.use_roles or not Game.instance.all_roles or _are_all_roles_selected()
	var uniqueness: bool = not Game.instance.use_roles or not Game.instance.unique_roles or _are_all_roles_unique()
	var fullness: bool = not Game.instance.use_roles or _all_players_selected_role()
	var has_map: bool = LevelManager.can_select()
	return quantity and completion and uniqueness and fullness and has_map


func _update_ready_button() -> void:
	ready_button.disabled = not _can_start_game()


func _are_all_roles_selected() -> bool:
	var roles: Array = Statics.Role.values()
	roles.pop_front()
	for player: Statics.PlayerData in Game.instance.players:
		roles.erase(player.role)
	return roles.is_empty()


func _are_all_roles_unique() -> bool:
	var roles: Array = Statics.Role.values()
	roles.pop_front()
	for player: Statics.PlayerData in Game.instance.players:
		if roles.has(player.role):
			roles.erase(player.role)
		else:
			return false
	return true


func _all_players_selected_role() -> bool:
	for player: Statics.PlayerData in Game.instance.players:
		if player.role == Statics.Role.NONE:
			return false
	return true


@rpc("authority", "call_local", "reliable")
func _sync_map_selection(index: int) -> void:
	LevelManager.set_level_index(index)
	_refresh_map_ui()


func _refresh_map_ui() -> void:
	if LevelManager.get_level_count() <= 0:
		map_button.text = "Sin mapas"
		return
	map_button.text = LevelManager.get_level_name()


func _update_map_controls() -> void:
	if map_button == null:
		return
	var can_change: bool = _is_server() and start_timer.is_stopped() and not _launching and LevelManager.get_level_count() > 0
	map_button.disabled = not can_change
