class_name LevelConfigLoader
extends Node
## LevelConfigLoader - загрузчик конфигурации уровней
## Читает JSON файлы уровней, загружает текстуры и применяет их к узлам сцены

signal level_loaded(level_data: Dictionary)
signal texture_loaded(texture_type: String, texture: Texture2D)

@export var levels_index_path: String = "res://levels/levels_index.json"

# Ссылки на узлы сцены
@onready var background: Node2D = get_node_or_null("../Background")
@onready var target: Node2D = get_node_or_null("../Target")
@onready var existing_level_loader: Node = get_node_or_null("../Node")

var _levels: Array[String] = []
var _current_index: int = 0
var _level_data: Dictionary = {}

func _ready() -> void:
	if not is_in_group("level_config_loader"):
		add_to_group("level_config_loader")
	
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
	if _levels.is_empty():
		push_error("No levels listed.")
		return
	
	_current_index = clampi(i, 0, _levels.size() - 1)
	var level_path: String = "res://levels/%s" % _levels[_current_index]
	_apply_level_from_file(level_path)

func _apply_level_from_file(path: String) -> void:
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
	
	# Загружаем и применяем текстуры
	await _load_and_apply_textures()
	
	# Передаем параметры в существующий LevelLoader
	_configure_existing_loader()
	
	# Сигнализируем о загрузке уровня
	level_loaded.emit(_level_data)
	
	print("[LevelConfigLoader] Loaded level: %s" % _level_data.get("level_name", "Unnamed"))

func _load_and_apply_textures() -> void:
	# Загружаем текстуру фона
	var background_texture_path: String = _level_data.get("background_texture", "")
	if not background_texture_path.is_empty():
		await _load_background_texture(background_texture_path)
	
	# Загружаем текстуру мишени
	var target_texture_path: String = _level_data.get("target_texture", "")
	if not target_texture_path.is_empty():
		await _load_target_texture(target_texture_path)
	
	# Загружаем текстуру оружия
	var weapon_texture_path: String = _level_data.get("weapon_texture", "")
	if not weapon_texture_path.is_empty():
		await _load_weapon_texture(weapon_texture_path)

func _load_background_texture(texture_path: String) -> void:
	var full_path: String = "res://%s" % texture_path
	if not FileAccess.file_exists(full_path):
		push_error("Background texture not found: %s" % full_path)
		return
	
	var texture: Texture2D = load(full_path) as Texture2D
	if texture == null:
		push_error("Failed to load background texture: %s" % full_path)
		return
	
	# Применяем текстуру к узлу Background
	if background != null:
		if background.has_method("set_texture"):
			background.call("set_texture", texture)
		elif background.has_node("Sprite2D"):
			var sprite: Sprite2D = background.get_node("Sprite2D") as Sprite2D
			if sprite != null:
				sprite.texture = texture
				# Центрируем и масштабируем изображение
				_center_and_scale_background(sprite, texture)
		elif background is Sprite2D:
			var bg_sprite: Sprite2D = background as Sprite2D
			bg_sprite.texture = texture
			
			# Центрируем и масштабируем изображение
			_center_and_scale_background(bg_sprite, texture)
	
	texture_loaded.emit("background", texture)
	print("[LevelConfigLoader] Applied background texture: %s" % texture_path)

func _center_and_scale_background(sprite: Sprite2D, texture: Texture2D) -> void:
	if sprite == null or texture == null:
		return
	
	# Получаем размеры экрана/вида
	var viewport: Viewport = get_viewport()
	var screen_size: Vector2 = viewport.get_visible_rect().size
	
	# Получаем размеры текстуры
	var texture_size: Vector2 = texture.get_size()
	
	print("[LevelConfigLoader] Screen size: %s, Texture size: %s" % [screen_size, texture_size])
	
	# Вычисляем масштаб для покрытия всего экрана (с сохранением пропорций)
	var scale_x: float = screen_size.x / texture_size.x
	var scale_y: float = screen_size.y / texture_size.y
	
	# Используем больший масштаб для полного покрытия экрана
	var scale: float = max(scale_x, scale_y)
	
	print("[LevelConfigLoader] Calculated scales: x=%.3f, y=%.3f, final=%.3f" % [scale_x, scale_y, scale])
	
	# Применяем масштаб
	sprite.scale = Vector2(scale, scale)
	
	# Центрируем изображение - используем центр экрана
	var center_pos: Vector2 = screen_size * 0.5
	sprite.position = center_pos
	
	# Устанавливаем центр спрайта в центр текстуры для правильного центрирования
	sprite.offset = texture_size * 0.5
	
	print("[LevelConfigLoader] Background positioned: pos=%s, offset=%s, scale=%s" % [sprite.position, sprite.offset, sprite.scale])

func _scale_target_to_collision_radius(sprite: Sprite2D, texture: Texture2D, target_node: Node2D) -> void:
	if sprite == null or texture == null or target_node == null:
		return
	
	# Находим коллизию мишени
	var collision_shape: CollisionShape2D = null
	var static_body: StaticBody2D = target_node.get_node_or_null("StaticBody2D")
	if static_body != null:
		collision_shape = static_body.get_node_or_null("CollisionShape2D")
	
	if collision_shape == null or collision_shape.shape == null:
		push_warning("Target collision shape not found, skipping scaling")
		return
	
	var shape: Shape2D = collision_shape.shape
	var target_radius: float = 0.0
	
	# Получаем радиус из формы коллизии
	if shape is CircleShape2D:
		target_radius = (shape as CircleShape2D).radius
	elif shape is RectangleShape2D:
		var rect_size: Vector2 = (shape as RectangleShape2D).size
		target_radius = min(rect_size.x, rect_size.y) * 0.5
	else:
		push_warning("Unsupported collision shape type for target scaling")
		return
	
	# Получаем размеры текстуры
	var texture_size: Vector2 = texture.get_size()
	
	# Вычисляем масштаб для заполнения всего диаметра коллизии
	var target_diameter: float = target_radius * 2.0  # 240px для радиуса 120px
	
	# Используем больший размер текстуры для масштабирования
	var texture_max_size: float = max(texture_size.x, texture_size.y)
	
	# Добавляем небольшой буфер для гарантированного заполнения
	var scale: float = (target_diameter * 1.1) / texture_max_size
	
	# Применяем масштаб
	sprite.scale = Vector2(scale, scale)
	
	# Вычисляем ожидаемый размер после масштабирования
	var scaled_size: Vector2 = Vector2(texture_max_size * scale, texture_max_size * scale)
	print("  - Expected scaled size: %s px" % scaled_size)
	print("  - Should fill diameter: %.1f px" % target_diameter)
	
	# Центрируем спрайт для вращения вокруг своей оси
	sprite.position = Vector2.ZERO
	sprite.offset = Vector2.ZERO  # Убираем offset, чтобы вращение было вокруг центра спрайта
	
	print("[LevelConfigLoader] Target scaling details:")
	print("  - Target radius: %.1f px" % target_radius)
	print("  - Target diameter: %.1f px" % target_diameter)
	print("  - Texture size: %s px" % texture_size)
	print("  - Texture max size: %.1f px" % texture_max_size)
	print("  - Calculated scale: %.3f" % scale)
	print("  - Final sprite scale: %s" % sprite.scale)

func _load_target_texture(texture_path: String) -> void:
	var full_path: String = "res://%s" % texture_path
	if not FileAccess.file_exists(full_path):
		push_error("Target texture not found: %s" % full_path)
		return
	
	var texture: Texture2D = load(full_path) as Texture2D
	if texture == null:
		push_error("Failed to load target texture: %s" % full_path)
		return
	
	# Применяем текстуру к узлу Target
	if target != null:
		if target.has_method("set_texture"):
			target.call("set_texture", texture)
		elif target.has_node("TargetSprite"):
			var sprite: Sprite2D = target.get_node("TargetSprite") as Sprite2D
			if sprite != null:
				sprite.texture = texture
				_scale_target_to_collision_radius(sprite, texture, target)
		elif target.has_node("Sprite2D"):
			var sprite: Sprite2D = target.get_node("Sprite2D") as Sprite2D
			if sprite != null:
				sprite.texture = texture
				_scale_target_to_collision_radius(sprite, texture, target)
		elif target is Sprite2D:
			var target_sprite: Sprite2D = target as Sprite2D
			target_sprite.texture = texture
			_scale_target_to_collision_radius(target_sprite, texture, target.get_parent())
	
	texture_loaded.emit("target", texture)
	print("[LevelConfigLoader] Applied target texture: %s" % texture_path)

func _load_weapon_texture(texture_path: String) -> void:
	var full_path: String = "res://%s" % texture_path
	if not FileAccess.file_exists(full_path):
		push_error("Weapon texture not found: %s" % full_path)
		return
	
	var texture: Texture2D = load(full_path) as Texture2D
	if texture == null:
		push_error("Failed to load weapon texture: %s" % full_path)
		return
	
	# Применяем текстуру к WeaponSprite в экземплярах ножей
	_apply_weapon_texture_to_knives(texture)
	
	texture_loaded.emit("weapon", texture)
	print("[LevelConfigLoader] Applied weapon texture: %s" % texture_path)

func _apply_weapon_texture_to_knives(texture: Texture2D) -> void:
	# Ищем все экземпляры ножей в сцене и применяем текстуру
	var knives = get_tree().get_nodes_in_group("knife")
	for knife in knives:
		if knife.has_node("WeaponSprite"):
			var weapon_sprite: Sprite2D = knife.get_node("WeaponSprite") as Sprite2D
			if weapon_sprite != null:
				weapon_sprite.texture = texture
		elif knife is Sprite2D and knife.name == "WeaponSprite":
			(knife as Sprite2D).texture = texture

func _configure_existing_loader() -> void:
	if existing_level_loader == null:
		push_warning("Existing LevelLoader not found, skipping configuration")
		return
	
	# Передаем скорость вращения мишени
	var rotation_speed: float = float(_level_data.get("target_rotation_speed_deg", 0.0))
	if existing_level_loader.has_method("set_target_rotation_speed"):
		existing_level_loader.call("set_target_rotation_speed", rotation_speed)
	elif target != null and target.has_method("set_rotation_speed_deg"):
		target.call("set_rotation_speed_deg", rotation_speed)
	
	# Передаем необходимое число попаданий
	var hit_count: int = int(_level_data.get("hit_count_required", 0))
	if existing_level_loader.has_method("set_knives_to_win"):
		existing_level_loader.call("set_knives_to_win", hit_count)
	
	# Для совместимости с существующим форматом
	var knives_to_win: int = int(_level_data.get("knives_to_win", hit_count))
	if existing_level_loader.has_method("set_knives_to_win"):
		existing_level_loader.call("set_knives_to_win", knives_to_win)
	
	print("[LevelConfigLoader] Configured existing loader: rotation=%s, hits=%s" % [rotation_speed, hit_count])

func get_current_level_data() -> Dictionary:
	return _level_data

func get_current_level_index() -> int:
	return _current_index

func get_levels_count() -> int:
	return _levels.size()

func restart_level() -> void:
	load_level_by_index(_current_index)

func next_level() -> void:
	var next_i: int = _current_index + 1
	if next_i >= _levels.size():
		next_i = 0
	load_level_by_index(next_i)

func previous_level() -> void:
	var prev_i: int = _current_index - 1
	if prev_i < 0:
		prev_i = _levels.size() - 1
	load_level_by_index(prev_i)
