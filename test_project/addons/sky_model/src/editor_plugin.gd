# Copyright (c) 2026 Ilia Riabko
#
# Created as part of a bachelor's thesis at Charles University, Prague.
#
# SPDX-License-Identifier: MIT

@tool
extends EditorPlugin

var sky_model_script: Script
var sky_model_icon: Texture2D

func _enter_tree() -> void:
	var current_script := get_script() as Script
	var current_directory: String = current_script.resource_path.get_base_dir()

	var sky_model_script: Script = load(
		current_directory.path_join("sky_model.gd")
	) as Script

	var sky_model_icon: Texture2D = load(
		current_directory.path_join("../icons/01_icon.png")
	) as Texture2D
	
	add_custom_type("SkyModel", "Node", sky_model_script, sky_model_icon)

func _exit_tree() -> void:
	remove_custom_type("SkyModel")
