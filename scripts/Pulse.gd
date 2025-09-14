extends Node
# Pulse.gd — пульс цели и бонус-окно.

@export var interval_sec: float = 4.0
@export var pulse_window_sec: float = 0.35
@export var scale_up: float = 1.12
@export var scale_time: float = 0.12

var _active: bool = false
var _t_timer: Timer
var _target_node: Node2D

signal pulse_window_started
signal pulse_window_ended

func _ready() -> void:
	_target_node = get_parent() as Node2D
	if _target_node == null:
		push_warning("Pulse.gd: parent is not Node2D; pulse disabled")
		set_process(false)
		return

	_t_timer = Timer.new()
	_t_timer.one_shot = false
	_t_timer.wait_time = max(0.2, interval_sec)
	add_child(_t_timer)
	_t_timer.timeout.connect(_on_pulse_tick)
	_t_timer.start()

func set_interval_sec(value: float) -> void:
	interval_sec = value
	if _t_timer != null:
		_t_timer.stop()
		_t_timer.wait_time = max(0.2, interval_sec)
		_t_timer.start()

func is_pulse_active() -> bool:
	return _active

func _on_pulse_tick() -> void:
	_active = true
	pulse_window_started.emit()

	var tw: Tween = create_tween()
	tw.tween_property(_target_node, "scale", Vector2.ONE * scale_up, scale_time).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tw.tween_property(_target_node, "scale", Vector2.ONE, scale_time).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_IN)

	var end_t: SceneTreeTimer = get_tree().create_timer(pulse_window_sec)
	await end_t.timeout
	_active = false
	pulse_window_ended.emit()
