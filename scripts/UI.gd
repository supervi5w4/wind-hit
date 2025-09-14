extends CanvasLayer
# UI.gd — HUD: имя уровня, ветер, пульс, попадания, яблоки, кнопки.

signal restart_requested
signal next_requested

@onready var lbl_level: Label = $Root/Top/LevelName
@onready var lbl_wind: Label = $Root/Top/Wind
@onready var pulse_panel: Panel = $Root/Top/Pulse
@onready var lbl_hits: Label = $Root/HBoxContainer/Hits
@onready var lbl_apples: Label = $Root/HBoxContainer/Apples
@onready var btn_restart: Button = $Root/Bottom/Buttons/Restart
@onready var btn_next: Button = $Root/Bottom/Buttons/Next

func _ensure_refs() -> void:
	if lbl_level == null:
		lbl_level = $Root/Top/LevelName
	if lbl_wind == null:
		lbl_wind = $Root/Top/Wind
	if pulse_panel == null:
		pulse_panel = $Root/Top/Pulse
	if lbl_hits == null:
		lbl_hits = $Root/HBoxContainer/Hits
	if lbl_apples == null:
		lbl_apples = $Root/HBoxContainer/Apples
	if btn_restart == null:
		btn_restart = $Root/Bottom/Buttons/Restart
	if btn_next == null:
		btn_next = $Root/Bottom/Buttons/Next

func _ready() -> void:
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_next.pressed.connect(_on_next_pressed)
	set_pulse_active(false)
	set_wind(0.0)
	set_level_name("-")
	set_hits(0, 0)
	set_apples(0, 0)
	
	# Убеждаемся, что кнопки активны и видны
	btn_restart.visible = true
	btn_restart.disabled = false
	btn_next.visible = true
	btn_next.disabled = false
	
	
	# Убеждаемся, что UI не блокирует события мыши
	var root_control = get_node("Root")
	if root_control != null:
		root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_level_name(name: String) -> void:
	_ensure_refs()
	lbl_level.text = "Level: " + name

func set_hits(current: int, total: int) -> void:
	_ensure_refs()
	lbl_hits.text = "Hits: %d/%d" % [current, total]

func set_apples(left: int, total: int) -> void:
	_ensure_refs()
	lbl_apples.text = "Apples: %d/%d" % [left, total]

func set_wind(w: float) -> void:
	_ensure_refs()
	var dir: String = "→"
	if w < 0.0:
		dir = "←"
	lbl_wind.text = "Wind: %d %s" % [int(abs(w)), dir]

func set_pulse_active(active: bool) -> void:
	_ensure_refs()
	if active:
		# Кратко загораемся панель при пульсе
		pulse_panel.visible = true
		pulse_panel.modulate = Color.WHITE
		var tween = create_tween()
		tween.tween_property(pulse_panel, "modulate", Color(1, 1, 1, 0), 0.35)
		tween.tween_callback(func(): pulse_panel.visible = false)
	else:
		pulse_panel.visible = false

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_next_pressed() -> void:
	next_requested.emit()
