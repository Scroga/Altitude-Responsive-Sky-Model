# Copyright (c) 2026 Ilia Riabko
#
# Created as part of a bachelor's thesis at Charles University, Prague.
#
# SPDX-License-Identifier: MIT

@tool
extends EditorPlugin

const sky_model_script: Script = preload("res://addons/sky_generator/src/sky_model.gd")
const sky_model_icon: Texture2D = preload("res://addons/sky_generator/icons/01_icon.png")

func _enter_tree() -> void:
	add_custom_type("SkyModel", "Node", sky_model_script, sky_model_icon)

func _exit_tree() -> void:
	remove_custom_type("SkyModel")
