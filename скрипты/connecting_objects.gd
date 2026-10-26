extends Node


func connect_objs(fb, sb, held_obj):
	#fb first obj
	#sb second obj
	print(fb," ", sb, " | ", are_touching(fb, sb))
	if are_touching(fb, sb):
		var duplicate_root
		var main_obj
		if held_obj == fb:
			duplicate_root = sb
			main_obj = fb
		else:
			duplicate_root = fb
			main_obj = sb
		
		for child in duplicate_root.get_children():
			duplicate_root.remove_child(child)
			main_obj.add_child(child)
			if child is Node3D:
				child.global_position = duplicate_root.global_position + child.position
				child.global_rotation = duplicate_root.global_rotation + child.rotation
		main_obj.mass += duplicate_root.mass
		duplicate_root.queue_free()


# Проверяет, касаются ли два физических объекта (любого типа с коллизией).
# Работает через PhysicsDirectSpaceState3D и не требует contact_monitor.
func are_touching(obj_a: CollisionObject3D, obj_b: CollisionObject3D) -> bool:
	if obj_a == null or obj_b == null:
		return false
	if obj_a == obj_b:
		return false

	# Получаем физическое пространство из любого объекта
	var space_state := obj_a.get_world_3d().direct_space_state
	if space_state == null:
		return false

	# Перебираем ВСЕ формы коллизий объекта A и проверяем пересечение с B
	for shape_owner_id in obj_a.get_shape_owners():
		var owner_transform := obj_a.shape_owner_get_transform(shape_owner_id)
		for i in obj_a.shape_owner_get_shape_count(shape_owner_id):
			var shape := obj_a.shape_owner_get_shape(shape_owner_id, i)
			if shape == null:
				continue

			var params := PhysicsShapeQueryParameters3D.new()
			params.shape = shape
			# Глобальная трансформация формы = трансформация тела * трансформация владельца формы
			params.transform = obj_a.global_transform * owner_transform
			params.exclude = [obj_a.get_rid()]
			params.collide_with_bodies = true
			params.collide_with_areas = true
			params.margin = 0.01 # Небольшой зазор, чтобы ловить почти-касания

			var results := space_state.intersect_shape(params)
			for result in results:
				if result.collider == obj_b:
					return true

	return false
