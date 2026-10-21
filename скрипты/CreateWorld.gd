extends Node



func create(name, seed):
	print("Создание: мир: ", name, " | Сид: ", seed)
	Slw.seed = seed
	get_tree().change_scene_to_packed(preload("res://сцены/пустыня.tscn"))
