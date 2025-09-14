extends Node2D
# Target.gd — мишень. Добавили вращение по параметру уровня.

const EMBEDDED_SCENE := preload("res://scenes/EmbeddedKnife.tscn")

@export var rotation_speed_deg: float = 0.0
@onready var hit_body: StaticBody2D = $HitBody

func _ready() -> void:
	if not is_in_group("target"):
		add_to_group("target")

func _process(delta: float) -> void:
	if abs(rotation_speed_deg) > 0.0:
		rotation += deg_to_rad(rotation_speed_deg) * delta

func add_embedded_knife_at(global_pos: Vector2, angle: float) -> void:
	var embedded := EMBEDDED_SCENE.instantiate() as StaticBody2D
	add_child(embedded)
	embedded.global_position = global_pos
	embedded.rotation = angle
