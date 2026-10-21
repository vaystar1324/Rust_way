extends Node


func pin(body_a: RigidBody3D, body_b: RigidBody3D, pin_position: Vector3):
	print("Соединяем объекты гвоздём: ", body_a.name, " и ", body_b.name)
	
	# Защита от соединения объекта с самим собой
	if body_a == body_b:
		return
	
	# 1. Создаём 3D-сустав
	var joint = PinJoint3D.new()
	
	# 2. Указываем тела
	joint.node_a = body_a.get_path()
	joint.node_b = body_b.get_path()
	
	# 3. Настраиваем жесткость (опционально, но полезно)
	# Bias отвечает за "натяжение" сустава. Чем выше — тем жестче гвоздь.
	joint.set_param(PinJoint3D.PARAM_BIAS, 0.3)
	
	# 4. Добавляем в дерево сцены ПЕРЕД установкой позиции
	# Важно: родителем лучше сделать общего предка этих тел, 
	# чтобы пути не сломались при перемещении сцены
	get_tree().current_scene.add_child(joint)
	
	# 5. Ставим в точку удара
	joint.global_position = pin_position
	
	# 6. Отключаем коллизии между склеенными телами
	joint.disable_collision = true
	print("Гвоздь забит!")
