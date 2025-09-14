extends StaticBody2D

func _ready() -> void:
	if not is_in_group("embedded"):
		add_to_group("embedded")
