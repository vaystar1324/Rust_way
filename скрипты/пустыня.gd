extends Node3D

@onready var terrain: VoxelLodTerrain = $VoxelLodTerrain
@onready var new_seed = Slw.seed 

func _ready() -> void:
	restart_script()

func restart_script():
	print("загрузка скрипта для voxel generation")
	if terrain:
		terrain.generator = null
	else:
		printerr("не найден voxel generation для создания мира")
		get_tree().change_scene_to_packed(preload("res://сцены/главное_меню.tscn"))
		return
	if load("res://скрипты/воксельный мир генерация.tres"):
		terrain.generator = load("res://скрипты/воксельный мир генерация.tres")
		print("загрузка завершина")
	else:
		printerr("скрипт для создания мира не найден")
		get_tree().change_scene_to_packed(preload("res://сцены/главное_меню.tscn"))
		return
