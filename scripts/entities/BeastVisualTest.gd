extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer # Adjust path if AnimationPlayer is nested deeper

func _ready() -> void:
	if animation_player == null:
		animation_player = _find_animation_player(self)
	
	if animation_player:
		# Print available animations to the output log to confirm names
		var anims: PackedStringArray = animation_player.get_animation_list()
		print("Available animations: ", anims)
		
		if anims.size() > 0:
			var target_anim: String = anims[0]
			for a in anims:
				var lower := a.to_lower()
				if "walk" in lower or "idle" in lower:
					target_anim = a
					break
			
			var anim_res: Animation = animation_player.get_animation(target_anim)
			if anim_res != null:
				anim_res.loop_mode = Animation.LOOP_LINEAR
			
			if animation_player.current_animation != target_anim or not animation_player.is_playing():
				animation_player.play(target_anim)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null
