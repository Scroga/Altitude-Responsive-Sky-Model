@tool
extends Node

@onready var terrain: Terrain3D = find_child("Terrain3D")

func _ready():
	if not Engine.is_editor_hint() and has_node("UI"):
		$UI.player = $Player
			
		
