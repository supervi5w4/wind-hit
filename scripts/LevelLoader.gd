extends Node
# LevelLoader.gd — читает JSON-уровень, применяет параметры и ведёт прогресс.

@export var levels_index_path: String = "res://levels/levels_index.json"
@export var use_config_loader: bool = true  # Использовать новый LevelConfigLoader

const APPLE_SCENE := preload("res://scenes/Apple.tscn")

var _levels: Array[String] = []
var _current_index: int = 0
var _level_data: Dictionary = {}

var knives_to_win: int = 0
var embedded_count: int = 0
var bonus_on_pulse: String = "slowmo"

var apples_total: int = 0
var apples_left: int = 0

@onready var target: Node2D = $"../Target"
@onready var wind_field: Node = $"../FXLayer/WindField"
@onready var ui: Node = $"../UI"
@onready var config_loader: LevelConfigLoader = $"../LevelConfigLoader"

func _ready() -> void:
	if not is_in_group("level_loader"):
		add_to_group("level_loader")

	# ВАЖНО: дождаться, пока UI проинициализирует свои @onready ссылки
	if ui != null:
		await ui.ready   # <- ключевая строка

	if use_config_loader and config_loader != null:
		# Подключаемся к сигналам нового загрузчика
		if not config_loader.is_connected("level_loaded", Callable(self, "_on_config_level_loaded")):
			config_loader.connect("level_loaded", Callable(self, "_on_config_level_loaded"))
		# Дожидаемся инициализации конфигурационного загрузчика
		await config_loader.ready
	else:
		# Используем старый метод загрузки
		_load_levels_index()
		load_level_by_index(_current_index)

func _load_levels_index() -> void:
	_levels.clear()
	if not FileAccess.file_exists(levels_index_path):
		push_error("Level index not found: %s" % levels_index_path)
		return
	var f: FileAccess = FileAccess.open(levels_index_path, FileAccess.READ)
	var txt: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Bad levels_index.json")
		return
	var arr: Variant = (data as Dictionary).get("levels")
	if typeof(arr) == TYPE_ARRAY:
		for it in (arr as Array):
			if typeof(it) == TYPE_STRING:
				_levels.append(it as String)

func load_level_by_index(i: int) -> void:
	if use_config_loader and config_loader != null:
		config_loader.load_level_by_index(i)
		_current_index = config_loader.get_current_level_index()
	else:
		if _levels.is_empty():
			push_error("No levels listed.")
			return
		_current_index = clampi(i, 0, _levels.size() - 1)
		var level_path: String = "res://levels/%s" % _levels[_current_index]
		_apply_level_from_file(level_path)

func _apply_level_from_file(path: String) -> void:
	embedded_count = 0
	apples_total = 0
	apples_left = 0
	_clear_target_children()

	if not FileAccess.file_exists(path):
		push_error("Level file not found: %s" % path)
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var txt: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Bad level json: %s" % path)
		return
	_level_data = data as Dictionary

	# 1) Поворот цели
	var rot_deg: float = float(_level_data.get("rotation_speed_deg", 0.0))
	if target != null:
		target.set("rotation_speed_deg", rot_deg)

	# 2) Ветер
	var wind_x: float = float(_level_data.get("wind_strength_x", 0.0))
	if wind_field != null and wind_field.has_method("set_wind_x"):
		wind_field.call("set_wind_x", wind_x)

	# 3) Пульс
	var pulse_interval: float = float(_level_data.get("pulse_interval_sec", 4.0))
	var pulse_node: Node = target.get_node_or_null("Pulse")
	if pulse_node != null and pulse_node.has_method("set_interval_sec"):
		pulse_node.call("set_interval_sec", pulse_interval)
	_connect_pulse_ui(pulse_node)

	# 4) Яблоки
	var apples_arr: Variant = _level_data.get("apples", [])
	if typeof(apples_arr) == TYPE_ARRAY:
		apples_total = (apples_arr as Array).size()
		apples_left = apples_total
		for a in (apples_arr as Array):
			if typeof(a) == TYPE_DICTIONARY:
				var ad: Dictionary = a as Dictionary
				var angle_deg: float = float(ad.get("angle_deg", 0.0))
				var radius: float = float(ad.get("radius", 140.0))
				_spawn_apple(angle_deg, radius)

	# 5) Победа/бонус
	knives_to_win = int(_level_data.get("knives_to_win", 8))
	bonus_on_pulse = String(_level_data.get("bonus_on_pulse", "slowmo"))

	_update_ui_initial(wind_x)

	print("[Level] Loaded: %s | rot=%s | wind=%s | pulse=%s | knives=%s | apples=%s"
		% [String(_level_data.get("name", "Unnamed")), rot_deg, wind_x, pulse_interval, knives_to_win, apples_total])

func _spawn_apple(angle_deg: float, radius: float) -> void:
	if target == null:
		return
	var apple: StaticBody2D = APPLE_SCENE.instantiate() as StaticBody2D
	target.add_child(apple)
	var local_pos: Vector2 = Vector2(radius, 0).rotated(deg_to_rad(angle_deg))
	(apple as Node2D).position = local_pos  # позиция относительно центра цели

func _clear_target_children() -> void:
	if target == null:
		return
	var to_remove: Array[Node] = []
	for child in target.get_children():
		if child is Node and (child as Node).is_in_group("apple"):
			to_remove.append(child)
		elif child is Node and (child as Node).is_in_group("embedded"):
			to_remove.append(child)
	for n in to_remove:
		n.queue_free()

func register_hit() -> void:
	embedded_count += 1
	_update_ui_progress()
	if embedded_count >= knives_to_win:
		_go_next_level()

func register_apple_collected() -> void:
	apples_left = max(0, apples_left - 1)
	_update_ui_progress()

func restart_level() -> void:
	if use_config_loader and config_loader != null:
		config_loader.restart_level()
	else:
		load_level_by_index(_current_index)

func next_level() -> void:
	if use_config_loader and config_loader != null:
		config_loader.next_level()
	else:
		_go_next_level()

func _go_next_level() -> void:
	var next_i: int = _current_index + 1
	if next_i >= _levels.size():
		next_i = 0
	load_level_by_index(next_i)

func _update_ui_initial(wind_x: float) -> void:
	if ui == null:
		return
	if ui.has_method("set_level_name"):
		ui.call("set_level_name", String(_level_data.get("name", "Unnamed")))
	if ui.has_method("set_wind"):
		ui.call("set_wind", wind_x)
	_update_ui_progress()

func _update_ui_progress() -> void:
	if ui == null:
		return
	if ui.has_method("set_hits"):
		ui.call("set_hits", embedded_count, knives_to_win)
	if ui.has_method("set_apples"):
		ui.call("set_apples", apples_left, apples_total)

func _connect_pulse_ui(pulse_node: Node) -> void:
	if ui == null or pulse_node == null:
		return
	var started := Callable(self, "_on_pulse_started")
	var ended := Callable(self, "_on_pulse_ended")
	if not pulse_node.is_connected("pulse_window_started", started):
		pulse_node.connect("pulse_window_started", started)
	if not pulse_node.is_connected("pulse_window_ended", ended):
		pulse_node.connect("pulse_window_ended", ended)

func _on_pulse_started() -> void:
	if ui != null and ui.has_method("set_pulse_active"):
		ui.call("set_pulse_active", true)

func _on_pulse_ended() -> void:
	if ui != null and ui.has_method("set_pulse_active"):
		ui.call("set_pulse_active", false)

# Методы для работы с новым LevelConfigLoader
func _on_config_level_loaded(level_data: Dictionary) -> void:
	_level_data = level_data
	_apply_config_level_data()

func _apply_config_level_data() -> void:
	embedded_count = 0
	apples_total = 0
	apples_left = 0
	_clear_target_children()

	# 1) Поворот цели
	var rot_deg: float = float(_level_data.get("target_rotation_speed_deg", _level_data.get("rotation_speed_deg", 0.0)))
	if target != null:
		target.set("rotation_speed_deg", rot_deg)

	# 2) Ветер
	var wind_x: float = float(_level_data.get("wind_strength_x", 0.0))
	if wind_field != null and wind_field.has_method("set_wind_x"):
		wind_field.call("set_wind_x", wind_x)

	# 3) Пульс
	var pulse_interval: float = float(_level_data.get("pulse_interval_sec", 4.0))
	var pulse_node: Node = target.get_node_or_null("Pulse")
	if pulse_node != null and pulse_node.has_method("set_interval_sec"):
		pulse_node.call("set_interval_sec", pulse_interval)
	_connect_pulse_ui(pulse_node)

	# 4) Яблоки
	var apples_arr: Variant = _level_data.get("apples", [])
	if typeof(apples_arr) == TYPE_ARRAY:
		apples_total = (apples_arr as Array).size()
		apples_left = apples_total
		for a in (apples_arr as Array):
			if typeof(a) == TYPE_DICTIONARY:
				var ad: Dictionary = a as Dictionary
				var angle_deg: float = float(ad.get("angle_deg", 0.0))
				var radius: float = float(ad.get("radius", 140.0))
				_spawn_apple(angle_deg, radius)

	# 5) Победа/бонус
	knives_to_win = int(_level_data.get("hit_count_required", _level_data.get("knives_to_win", 8)))
	bonus_on_pulse = String(_level_data.get("bonus_on_pulse", "slowmo"))

	_update_ui_initial(wind_x)

	print("[LevelLoader] Applied config level: %s | rot=%s | wind=%s | pulse=%s | knives=%s | apples=%s"
		% [String(_level_data.get("level_name", _level_data.get("name", "Unnamed"))), rot_deg, wind_x, pulse_interval, knives_to_win, apples_total])

# Методы для совместимости с новым загрузчиком
func set_target_rotation_speed(speed: float) -> void:
	if target != null:
		target.set("rotation_speed_deg", speed)

func set_knives_to_win(count: int) -> void:
	knives_to_win = count
