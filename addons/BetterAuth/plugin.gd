@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type(
		"BetterAuth",             # Node name
		"Node",                   # Base type
		preload("auth_client.gd"),# Script to attach
		preload("icon.svg")
	)


func _exit_tree() -> void:
	remove_custom_type("BetterAuth")
