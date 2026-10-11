extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer # Adjust path if AnimationPlayer is nested deeper

func _ready() -> void:
	if animation_player:
		# Print available animations to the output log to confirm names
		print("Available animations: ", animation_player.get_animation_list())
		
		# Play the first available animation or a specific name like "Walk"
		var anims = animation_player.get_animation_list()
		if anims.size() > 0:
			animation_player.play(anims[0])
