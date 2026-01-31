extends Control

## testt.tscn 主控制脚本
## 管理四面板：任务、资源、冒险家、协会
## 集成 GameManager 进行数据管理

# ========== 场景引用 ==========
var row_scene: PackedScene = preload("res://system/tess/row/row.tscn")
const GameManagerScript = preload("res://ControlTest/game_manager.gd")

# ========== 游戏管理器 ==========
var game_manager

# ========== 面板容器引用 ==========
# 任务面板
@onready var task_container: VBoxContainer = $Control/VBoxContainer/Panel/ScrollContainer/VBoxContainer
# 资源面板
@onready var resource_container: HBoxContainer = $Control2/VBoxContainer/Panel/ScrollContainer/HBoxContainer
# 冒险家面板
@onready var adventurer_container: VBoxContainer = $Control3/VBoxContainer/Panel/ScrollContainer/VBoxContainer
# 协会面板
@onready var guild_container: VBoxContainer = $Control4/VBoxContainer/Panel/ScrollContainer/VBoxContainer

# ========== 协会UI引用 ==========
@onready var guild_level_label: Label = $Control4/VBoxContainer/Panel/ScrollContainer/VBoxContainer/HBoxContainer/Label2
@onready var guild_cost_label: Label = $Control4/VBoxContainer/Panel/ScrollContainer/VBoxContainer/HBoxContainer/Label3
@onready var guild_upgrade_button: Button = $Control4/VBoxContainer/Panel/ScrollContainer/VBoxContainer/HBoxContainer/Button

# ========== 存储行实例 ==========
var task_rows: Array = []
var adventurer_rows: Array = []
var guild_recruit_rows: Array = []
var resource_columns: Array = []

# ========== 生命周期 ==========

func _ready() -> void:
	# 创建游戏管理器
	game_manager = GameManagerScript.new()
	add_child(game_manager)

	# 连接信号
	_connect_signals()

	# 等待管理器加载完成
	await get_tree().process_frame

	# 初始化所有面板
	_init_all_panels()

func _connect_signals() -> void:
	game_manager.game_loaded.connect(_on_game_loaded)
	game_manager.resources_changed.connect(_on_resources_changed)
	game_manager.task_started.connect(_on_task_started)
	game_manager.task_completed.connect(_on_task_completed)
	game_manager.adventurer_recruited.connect(_on_adventurer_recruited)
	game_manager.adventurer_status_changed.connect(_on_adventurer_status_changed)
	game_manager.guild_upgraded.connect(_on_guild_upgraded)
	game_manager.game_saved.connect(_on_game_saved)

	# 连接协会升级按钮
	if guild_upgrade_button:
		guild_upgrade_button.pressed.connect(_on_guild_upgrade_pressed)

func _init_all_panels() -> void:
	refresh_task_panel()
	refresh_resource_panel()
	refresh_adventurer_panel()
	refresh_guild_panel()

# ========== 任务面板 ==========

func refresh_task_panel() -> void:
	# 清除现有任务行（保留表头）
	_clear_rows(task_container, task_rows)

	# 创建任务行
	var tasks = game_manager.get_all_tasks()
	for task_data in tasks:
		var row_instance = row_scene.instantiate()
		row_instance.set_task_data(task_data)

		# 连接任务开始信号
		if row_instance.has_signal("task_accepted"):
			row_instance.task_accepted.connect(_on_task_accept_requested)

		task_container.add_child(row_instance)
		task_rows.append(row_instance)

	print("✅ 任务面板刷新: ", task_rows.size(), " 个任务")

func _on_task_accept_requested(task_id: String, adventurer_id: String) -> void:
	print("🔍 [testt] 收到 task_accepted 信号: task_id=", task_id, ", adventurer_id=", adventurer_id)

	# 检查是否可以接受任务
	if not game_manager.can_accept_new_task():
		print("❌ 无法接受更多任务！需要招募更多冒险家。")
		print("   当前任务: ", game_manager.get_running_tasks_count(), "/", game_manager.get_max_concurrent_tasks())
		return

	# 开始任务（传入指定的冒险家ID，如果为空则自动分配）
	print("🔍 [testt] 调用 game_manager.start_task(", task_id, ", ", adventurer_id, ")")
	var success = game_manager.start_task(task_id, adventurer_id)
	if success:
		print("✅ [testt] 任务开始成功")
	else:
		print("❌ [testt] 任务开始失败")

# ========== 资源面板 ==========

func refresh_resource_panel() -> void:
	# 清除现有资源列（保留标题列）
	var children = resource_container.get_children()
	for i in range(children.size()):
		if i > 0:  # 跳过第一个（标题列）
			children[i].queue_free()
	resource_columns.clear()

	# 创建资源列
	var resources = game_manager.get_all_resources()
	for resource_name in resources:
		var amount = resources[resource_name]
		var column = _create_resource_column(resource_name, amount)
		resource_container.add_child(column)
		resource_columns.append(column)

	print("✅ 资源面板刷新: ", resources.size(), " 种资源")

func _create_resource_column(resource_name: String, amount: int) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.custom_minimum_size = Vector2(200, 0)

	# 资源编号
	var label_id = Label.new()
	label_id.text = "R" + str(resource_columns.size() + 1)
	label_id.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(label_id)

	# 资源名称
	var label_name = Label.new()
	label_name.text = resource_name
	label_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(label_name)

	# 资源数量
	var label_amount = Label.new()
	label_amount.text = str(amount)
	label_amount.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label_amount.name = "AmountLabel"
	column.add_child(label_amount)

	# 资源描述
	var label_desc = Label.new()
	label_desc.text = _get_resource_description(resource_name)
	label_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(label_desc)

	# 用途
	var label_use = Label.new()
	label_use.text = _get_resource_use(resource_name)
	label_use.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(label_use)

	return column

func _get_resource_description(resource_name: String) -> String:
	match resource_name:
		"能量硬币": return "通用货币"
		"木材": return "建筑材料"
		"石料": return "建筑材料"
		"铁矿": return "金属矿物"
		_: return "未知资源"

func _get_resource_use(resource_name: String) -> String:
	match resource_name:
		"能量硬币": return "招募、升级"
		"木材": return "招募、升级"
		"石料": return "升级协会"
		"铁矿": return "高级升级"
		_: return "未知"

func _update_resource_display() -> void:
	var resources = game_manager.get_all_resources()
	var idx = 0
	for resource_name in resources:
		if idx < resource_columns.size():
			var column = resource_columns[idx]
			var amount_label = column.get_node_or_null("AmountLabel")
			if amount_label:
				amount_label.text = str(resources[resource_name])
		idx += 1

# ========== 冒险家面板 ==========

func refresh_adventurer_panel() -> void:
	# 清除现有行（保留表头）
	_clear_rows(adventurer_container, adventurer_rows)

	# 创建冒险家行
	var adventurers = game_manager.get_all_adventurers()
	for adv_data in adventurers:
		var row = _create_adventurer_row(adv_data)
		adventurer_container.add_child(row)
		adventurer_rows.append(row)

	# 如果没有冒险家，显示提示
	if adventurers.size() == 0:
		var hint_row = _create_hint_row("暂无冒险家，请在协会招募")
		adventurer_container.add_child(hint_row)
		adventurer_rows.append(hint_row)

	print("✅ 冒险家面板刷新: ", adventurers.size(), " 个冒险家")

func _create_adventurer_row(adv_data: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()

	# 编号
	var label_id = Label.new()
	label_id.text = adv_data.get("id", "")
	label_id.custom_minimum_size = Vector2(200, 0)
	label_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_id)

	# 名称
	var label_name = Label.new()
	label_name.text = adv_data.get("name", "")
	label_name.custom_minimum_size = Vector2(200, 0)
	label_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 如果是玩家，添加视觉区分
	if adv_data.get("is_player", false):
		label_name.text = "[玩家] " + adv_data.get("name", "")
		label_name.modulate = Color(1.0, 0.8, 0.2)  # 金色

	row.add_child(label_name)

	# 势力
	var label_faction = Label.new()
	label_faction.text = adv_data.get("faction", "")
	label_faction.custom_minimum_size = Vector2(200, 0)
	label_faction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_faction)

	# 职业
	var label_class = Label.new()
	label_class.text = adv_data.get("class", "")
	label_class.custom_minimum_size = Vector2(200, 0)
	label_class.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_class)

	# 能力值
	var stats = adv_data.get("stats", {})
	var label_stats = Label.new()
	label_stats.text = "攻%d 防%d 速%d" % [
		stats.get("攻击", 0),
		stats.get("防御", 0),
		stats.get("速度", 0)
	]
	label_stats.custom_minimum_size = Vector2(200, 0)
	label_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_stats)

	# 状态
	var label_status = Label.new()
	label_status.text = adv_data.get("status", "待命")
	label_status.custom_minimum_size = Vector2(200, 0)
	label_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_status.name = "StatusLabel"
	row.add_child(label_status)

	# 存储冒险家ID用于后续查找
	row.set_meta("adventurer_id", adv_data.get("id", ""))

	return row

func _create_hint_row(hint_text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = hint_text
	label.modulate = Color(0.6, 0.6, 0.6)
	row.add_child(label)
	return row

# ========== 协会面板 ==========

func refresh_guild_panel() -> void:
	# 更新协会等级和费用显示
	var guild = game_manager.get_guild()

	if guild_level_label:
		guild_level_label.text = "Lv." + str(guild.get("level", 1)) + " " + guild.get("name", "协会")

	if guild_cost_label:
		var cost = guild.get("upgrade_cost", {})
		var cost_text = ""
		for res_name in cost:
			if cost_text != "":
				cost_text += ", "
			cost_text += res_name + ": " + str(cost[res_name])
		guild_cost_label.text = cost_text

	# 更新升级按钮状态
	if guild_upgrade_button:
		var can_upgrade = game_manager.can_afford(guild.get("upgrade_cost", {}))
		guild_upgrade_button.disabled = not can_upgrade

	# 刷新可招募冒险家列表
	_refresh_recruitable_adventurers()

func _refresh_recruitable_adventurers() -> void:
	# 清除现有招募行（保留协会信息行）
	var children = guild_container.get_children()
	for i in range(children.size()):
		if i > 0:  # 跳过第一个（协会信息行）
			children[i].queue_free()
	guild_recruit_rows.clear()

	# 创建可招募冒险家行
	var recruitables = game_manager.get_recruitable_adventurers()
	for adv_data in recruitables:
		var row = _create_recruit_row(adv_data)
		guild_container.add_child(row)
		guild_recruit_rows.append(row)

	if recruitables.size() == 0:
		var hint_row = _create_hint_row("暂无可招募冒险家")
		guild_container.add_child(hint_row)
		guild_recruit_rows.append(hint_row)

	print("✅ 协会面板刷新: ", recruitables.size(), " 个可招募冒险家")

func _create_recruit_row(adv_data: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()

	# 名称
	var label_name = Label.new()
	label_name.text = adv_data.get("name", "")
	label_name.custom_minimum_size = Vector2(150, 0)
	label_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_name)

	# 职业
	var label_class = Label.new()
	label_class.text = adv_data.get("class", "")
	label_class.custom_minimum_size = Vector2(100, 0)
	label_class.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_class)

	# 能力值
	var stats = adv_data.get("stats", {})
	var label_stats = Label.new()
	label_stats.text = "攻%d 防%d 速%d" % [
		stats.get("攻击", 0),
		stats.get("防御", 0),
		stats.get("速度", 0)
	]
	label_stats.custom_minimum_size = Vector2(150, 0)
	label_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_stats)

	# 招募费用
	var cost = adv_data.get("recruitment_cost", {})
	var cost_text = ""
	for res_name in cost:
		if cost_text != "":
			cost_text += " "
		cost_text += res_name + ":" + str(cost[res_name])
	var label_cost = Label.new()
	label_cost.text = cost_text
	label_cost.custom_minimum_size = Vector2(200, 0)
	label_cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_cost)

	# 招募按钮
	var recruit_button = Button.new()
	recruit_button.text = "招募"
	recruit_button.custom_minimum_size = Vector2(80, 0)

	var adv_id = adv_data.get("id", "")
	recruit_button.pressed.connect(_on_recruit_button_pressed.bind(adv_id))

	# 检查是否能负担
	if not game_manager.can_afford(cost):
		recruit_button.disabled = true

	row.add_child(recruit_button)

	return row

func _on_recruit_button_pressed(adventurer_id: String) -> void:
	if game_manager.recruit_adventurer(adventurer_id):
		refresh_adventurer_panel()
		refresh_guild_panel()
		refresh_resource_panel()

func _on_guild_upgrade_pressed() -> void:
	if game_manager.upgrade_guild():
		refresh_guild_panel()
		refresh_resource_panel()

# ========== 信号处理 ==========

func _on_game_loaded() -> void:
	print("🎮 游戏加载完成")
	_init_all_panels()

func _on_resources_changed(_resources: Dictionary) -> void:
	_update_resource_display()
	# 更新招募按钮状态
	refresh_guild_panel()

func _on_task_started(_task_id: String, _adventurer_id: String) -> void:
	refresh_task_panel()
	refresh_adventurer_panel()

func _on_task_completed(_task_id: String, _rewards: Dictionary) -> void:
	refresh_task_panel()
	refresh_adventurer_panel()
	refresh_resource_panel()

func _on_adventurer_recruited(_adventurer_id: String) -> void:
	refresh_adventurer_panel()
	refresh_guild_panel()

func _on_adventurer_status_changed(_adventurer_id: String, _new_status: String) -> void:
	refresh_adventurer_panel()

func _on_guild_upgraded(_new_level: int) -> void:
	refresh_guild_panel()

func _on_game_saved() -> void:
	pass  # 可以显示保存提示

# ========== 键盘输入 ==========

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Ctrl+S 强制保存
		if event.keycode == KEY_S and event.ctrl_pressed:
			game_manager.save_game()
			print("💾 手动保存完成")
		# Ctrl+E 导出存档
		elif event.keycode == KEY_E and event.ctrl_pressed:
			_show_export_dialog()
		# Ctrl+I 导入存档
		elif event.keycode == KEY_I and event.ctrl_pressed:
			_show_import_dialog()

# ========== 存档导入/导出 ==========

func _show_export_dialog() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.json", "JSON存档文件")
	dialog.current_file = "game_save_export.json"
	dialog.title = "导出存档"
	dialog.file_selected.connect(_on_export_path_selected)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_export_path_selected(path: String) -> void:
	if game_manager.export_save(path):
		print("📤 存档已导出到: ", path)
	else:
		print("❌ 导出失败")
	# 清理对话框
	for child in get_children():
		if child is FileDialog:
			child.queue_free()

func _show_import_dialog() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.json", "JSON存档文件")
	dialog.title = "导入存档"
	dialog.file_selected.connect(_on_import_path_selected)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_import_path_selected(path: String) -> void:
	if game_manager.import_save(path):
		print("📥 存档已导入: ", path)
		_init_all_panels()
	else:
		print("❌ 导入失败")
	# 清理对话框
	for child in get_children():
		if child is FileDialog:
			child.queue_free()

# ========== 工具方法 ==========

func _clear_rows(container: VBoxContainer, rows_array: Array) -> void:
	# 清除行（保留表头）
	var children = container.get_children()
	for i in range(children.size()):
		if i > 0:  # 跳过第一个（表头）
			children[i].queue_free()
	rows_array.clear()
