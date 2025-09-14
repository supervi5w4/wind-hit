extends Node2D

const KNIFE_SCENE := preload("res://scenes/Knife.tscn")

@onready var spawn: Marker2D = $Spawn
@onready var target: Node2D = $Target
@onready var level_loader: Node = $Node
@onready var ui: CanvasLayer = $UI

var _active_knife: Node2D = null

func _ready() -> void:
	# Кнопки UI
	if ui != null:
		if ui.has_signal("restart_requested"):
			ui.connect("restart_requested", Callable(level_loader, "restart_level"))
		if ui.has_signal("next_requested"):
			ui.connect("next_requested", Callable(level_loader, "next_level"))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("throw"):
		_try_throw()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_throw()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch and event.pressed:
		_try_throw()
		get_viewport().set_input_as_handled()
		return

func _input(event: InputEvent) -> void:
	# Дублируем обработку для гарантии срабатывания
	if event.is_action_pressed("throw"):
		_try_throw()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_throw()
		return

	if event is InputEventScreenTouch and event.pressed:
		_try_throw()
		return

func _try_throw() -> void:
	if _active_knife != null:
		return
	var knife: Node2D = KNIFE_SCENE.instantiate() as Node2D
	add_child(knife)
	knife.global_position = spawn.global_position
	_active_knife = knife
	knife.tree_exited.connect(_on_knife_freed)

	# Связь с LevelLoader: попадание и сбор яблока
	if level_loader != null:
		if knife.has_signal("embedded_success"):
			knife.connect("embedded_success", Callable(level_loader, "register_hit"))
		if knife.has_signal("apple_collected"):
			knife.connect("apple_collected", Callable(level_loader, "register_apple_collected"))

	if knife.has_method("launch"):
		knife.call("launch")

func _on_knife_freed() -> void:
	_active_knife = null
