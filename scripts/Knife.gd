extends CharacterBody2D
# Knife.gd — летящий нож: скорость (vertical_speed), ветер, без рекурсии на яблоках.

signal embedded_success
signal apple_collected

const L_KNIFE := 1
const L_TARGET := 1 << 1     # 2
const L_EMBEDDED := 1 << 2   # 4
const L_APPLE := 1 << 3      # 8

@export var vertical_speed: float = -1800.0
const EMBEDDED_SCENE := preload("res://scenes/EmbeddedKnife.tscn")

var weapon_texture: Texture2D = null
var _launched: bool = false
var _done: bool = false
var _pending_remainder: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("knife")
	# Применяем текстуру оружия, если она была установлена
	if weapon_texture != null:
		set_weapon_texture(weapon_texture)

func launch() -> void:
	_launched = true

func set_weapon_texture(texture: Texture2D) -> void:
	weapon_texture = texture
	var weapon_sprite: Sprite2D = get_node_or_null("WeaponSprite")
	if weapon_sprite != null:
		weapon_sprite.texture = texture

func _physics_process(delta: float) -> void:
	if not _launched:
		return
	if _done:
		return

	if _pending_remainder != Vector2.ZERO:
		var c_rem: KinematicCollision2D = move_and_collide(_pending_remainder)
		_pending_remainder = Vector2.ZERO
		if c_rem != null:
			_handle_collision(c_rem, delta)
			return

	var wind_x: float = _get_wind_strength_x()
	var motion: Vector2 = Vector2(wind_x, vertical_speed) * delta
	var c: KinematicCollision2D = move_and_collide(motion)
	if c != null:
		_handle_collision(c, delta)

func _get_wind_strength_x() -> float:
	var winds: Array = get_tree().get_nodes_in_group("wind")
	if winds.size() > 0:
		var w: Node = winds[0] as Node
		if w != null and w.has_method("get_wind_x"):
			return float(w.call("get_wind_x"))
	return 0.0

func _handle_collision(collision: KinematicCollision2D, delta: float) -> void:
	var collider_obj: Object = collision.get_collider()
	if collider_obj == null:
		return

	var layer_bits: int = 0
	if collider_obj is CollisionObject2D:
		layer_bits = (collider_obj as CollisionObject2D).collision_layer

	# ЯБЛОКО
	if (layer_bits & L_APPLE) != 0:
		if collider_obj is Node:
			(collider_obj as Node).queue_free()
		apple_collected.emit()
		_done = true  # Останавливаем нож после сбора яблока
		queue_free()
		return

	# ВТЫКАННЫЙ НОЖ — поражение
	if (layer_bits & L_EMBEDDED) != 0:
		_done = true
		get_tree().reload_current_scene()
		return

	# МИШЕНЬ — втыкаемся
	if (layer_bits & L_TARGET) != 0:
		_on_hit_target(collision)
		return

func _on_hit_target(collision: KinematicCollision2D) -> void:
	var hit_pos: Vector2 = collision.get_position()
	var collider_obj: Object = collision.get_collider()
	var target_root: Node2D = null

	if collider_obj is Node:
		var n: Node = collider_obj as Node
		while n != null and not (n is Node2D and n.is_in_group("target")):
			n = n.get_parent()
		if n != null and n is Node2D and n.is_in_group("target"):
			target_root = n as Node2D

	if target_root == null:
		queue_free()
		return

	# Слоумо, если активен пульс
	var pulse_node: Node = target_root.get_node_or_null("Pulse")
	var pulse_active: bool = false
	if pulse_node != null and pulse_node.has_method("is_pulse_active"):
		pulse_active = bool(pulse_node.call("is_pulse_active"))
	if pulse_active:
		_apply_pulse_bonus_slowmo(0.4)

	var dir_to_center: Vector2 = hit_pos.direction_to(target_root.global_position)
	var angle: float = dir_to_center.angle() + PI * 0.5

	var embedded: StaticBody2D = EMBEDDED_SCENE.instantiate() as StaticBody2D
	target_root.add_child(embedded)
	embedded.global_position = hit_pos
	embedded.rotation = angle

	embedded_success.emit()

	_done = true
	queue_free()

func _apply_pulse_bonus_slowmo(duration: float) -> void:
	Engine.time_scale = 0.6
	var t: SceneTreeTimer = get_tree().create_timer(duration)
	await t.timeout
	Engine.time_scale = 1.0
