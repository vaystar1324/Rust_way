extends Node3D


@warning_ignore("confusable_identifier")
func _on_одиночная_игра_pressed() -> void:
	$"главное меню".hide()
	$"выбор мира".show()


@warning_ignore("confusable_identifier")
func _on_многопользовательская_игра_pressed() -> void:
	pass


@warning_ignore("confusable_identifier")
func _on_настройки_pressed() -> void:
	pass


@warning_ignore("confusable_identifier")
func _on_закрыть_игру_pressed() -> void:
	get_tree().quit()


@warning_ignore("confusable_identifier")
func _on_назад_pressed() -> void:
	$"главное меню".show()
	$"выбор мира".hide()


@warning_ignore("confusable_identifier")
func _on_список_миров_item_activated(index: int) -> void:
	if index == 0:
		show_world_creation_dialog()


func show_world_creation_dialog() -> void:
	# Создаём окно
	var dialog := AcceptDialog.new()
	dialog.title = "Создание мира"
	dialog.ok_button_text = " "  # скрываем стандартную кнопку OK
	dialog.dialog_hide_on_ok = false  # не закрывать по Enter, если не нужно
	dialog.get_ok_button().visible = false  # полностью прячем стандартную кнопку
	
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(360, 0)
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)
	
	var name_label := Label.new()
	name_label.text = "Название мира:"
	vbox.add_child(name_label)
	
	var name_input := LineEdit.new()
	name_input.placeholder_text = "Введите название..."
	vbox.add_child(name_input)
	
	var seed_label := Label.new()
	seed_label.text = "Сид мира:"
	vbox.add_child(seed_label)
	
	var seed_input := LineEdit.new()
	seed_input.placeholder_text = "Введите сид..."
	vbox.add_child(seed_input)
	
	var hint := Label.new()
	hint.text = "Пустое поле ответа — сид будет случайным."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hint)
	
	var create_button := Button.new()
	create_button.text = "Создать"
	create_button.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(create_button)
	
	create_button.pressed.connect(func():
		var world_name: String = name_input.text.strip_edges()
		if world_name.is_empty():
			world_name = Time.get_datetime_string_from_system()
		
		var seed_text: String = seed_input.text.strip_edges()
		var world_seed: int
		if seed_text.is_empty():
			world_seed = randi()
		elif seed_text.is_valid_int():
			world_seed = int(seed_text)
		else:
			world_seed = hash(seed_text)
		
		CreateWorld.create(world_name, world_seed)
		
		dialog.hide()
		dialog.queue_free()
	)
	
	var theme := Theme.new()
	theme.default_font_size = 32
	dialog.theme = theme

	add_child(dialog)
	dialog.popup_centered()
