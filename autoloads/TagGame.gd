extends Node

signal it_changed(player_id: int, time_left: float)
signal player_exploded(player_id: int)
signal game_over(winner_id: int)

const START_TIME: float = 50.0
const TAG_COOLDOWN: float = 1.0
const SYNC_INTERVAL: float = 1.0

var it_player_id: int = -1
var time_left: float = 0.0
var game_active: bool = false
var alive_player_ids: Array = []

var _tag_cooldown_timer: float = 0.0
var _sync_accum: float = 0.0

func _ready() -> void:
	Game.instance.players_updated.connect(_on_players_updated)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not game_active:
		return

	time_left -= delta
	if _tag_cooldown_timer > 0.0:
		_tag_cooldown_timer -= delta

	_sync_accum += delta
	if _sync_accum >= SYNC_INTERVAL:
		_sync_accum = 0.0
		_sync_time.rpc(time_left)

	if time_left <= 0.0:
		_explode(it_player_id)

func start_game() -> void:
	if not multiplayer.is_server():
		return
	alive_player_ids.clear()
	for p: Statics.PlayerData in Game.instance.players:
		alive_player_ids.append(p.id)
	_start_round()

func _start_round() -> void:
	if alive_player_ids.is_empty():
		return
	var chosen: int = alive_player_ids[randi() % alive_player_ids.size()]
	time_left = START_TIME
	it_player_id = chosen
	_sync_game_active.rpc(true)
	_sync_it.rpc(it_player_id, time_left)


@rpc("authority", "call_local", "reliable")
func _sync_game_active(value: bool) -> void: 
	game_active = value

func _try_tag(tagger_id: int, target_id: int) -> void:
	if not game_active or tagger_id != it_player_id:
		return
	if target_id == it_player_id or _tag_cooldown_timer > 0.0:
		return

	it_player_id = target_id
	_tag_cooldown_timer = TAG_COOLDOWN
	_sync_it.rpc(it_player_id, time_left)  # no reinicia time_left

func _explode(player_id: int) -> void:
	_sync_game_active.rpc(false)
	alive_player_ids.erase(player_id)
	_on_explode.rpc(player_id)

	if alive_player_ids.size() <= 1:
		var winner: int = alive_player_ids[0] if alive_player_ids.size() == 1 else -1
		_on_game_over.rpc(winner)
		return

	_start_round()

# Si alguien se desconecta a mitad de partida, lo sacamos de la lista de vivos
func _on_players_updated() -> void:
	if not multiplayer.is_server() or not game_active:
		return

	var current_ids: Array = []
	for p: Statics.PlayerData in Game.instance.players:
		current_ids.append(p.id)

	var disconnected: bool = false
	for id in alive_player_ids.duplicate():
		if id not in current_ids:
			alive_player_ids.erase(id)
			disconnected = true

	if not disconnected:
		return

	if it_player_id not in alive_player_ids:
		# El que la llevaba se desconectó: se la pasamos a otro al azar
		if alive_player_ids.size() <= 1:
			var winner: int = alive_player_ids[0] if alive_player_ids.size() == 1 else -1
			_on_game_over.rpc(winner)
			return
		_start_round()

@rpc("any_peer", "call_local", "reliable")
func request_tag(target_id: int) -> void:
	if not multiplayer.is_server():
		return
	_try_tag(multiplayer.get_remote_sender_id(), target_id)

@rpc("authority", "call_local", "reliable")
func _sync_it(player_id: int, remaining: float) -> void:
	it_player_id = player_id
	time_left = remaining
	it_changed.emit(player_id, remaining)

@rpc("authority", "call_local", "unreliable")
func _sync_time(remaining: float) -> void:
	time_left = remaining

@rpc("authority", "call_local", "reliable")
func _on_explode(player_id: int) -> void:
	player_exploded.emit(player_id)

@rpc("authority", "call_local", "reliable")
func _on_game_over(winner_id: int) -> void:
	game_over.emit(winner_id)
