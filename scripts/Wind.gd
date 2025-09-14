extends Node2D
# Wind.gd — источник силы ветра и его визуализация (полоски).

@export var strength_x: float = 80.0
@export var visualize: bool = true
@export var lines_count: int = 10
@export var line_length_min: float = 20.0
@export var line_length_max: float = 120.0
@export var line_spacing: float = 96.0
@export var speed_factor: float = 0.5

var _phase: float = 0.0

signal strength_changed(value: float)

func _ready() -> void:
	if not is_in_group("wind"):
		add_to_group("wind")
	set_process(true)

func get_wind_x() -> float:
	return strength_x

func set_wind_x(value: float) -> void:
	strength_x = value
	strength_changed.emit(strength_x)

func _process(delta: float) -> void:
	if not visualize:
		return
	_phase += strength_x * speed_factor * delta
	queue_redraw()

func _draw() -> void:
	if not visualize:
		return

	var rect: Rect2 = get_viewport_rect()
	var width: float = float(rect.size.x)
	var height: float = float(rect.size.y)

	var len: float = clamp(abs(strength_x) * 0.8, line_length_min, line_length_max)
	var dir: float = 1.0
	if strength_x < 0.0:
		dir = -1.0

	var start_y: float = height * 0.2
	var cnt: int = max(1, lines_count)

	for i in range(cnt):
		var y: float = start_y + float(i) * line_spacing
		if y > height * 0.9:
			break
		var offset: float = fmod(_phase + float(i) * 37.0, width)
		var x: float = fposmod(offset, width)
		var from: Vector2 = Vector2(x, y)
		var to: Vector2 = Vector2(x + dir * len, y)
		draw_line(from, to, Color(1, 1, 1, 0.25), 2.0, true)
		var tip: Vector2 = to
		draw_line(tip, tip + Vector2(-10.0 * dir, -6.0), Color(1, 1, 1, 0.25), 2.0, true)
		draw_line(tip, tip + Vector2(-10.0 * dir,  6.0), Color(1, 1, 1, 0.25), 2.0, true)
