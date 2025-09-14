extends StaticBody2D

func _ready() -> void:
	if not is_in_group("apple"):
		add_to_group("apple")
