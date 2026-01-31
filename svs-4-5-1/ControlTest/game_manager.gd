extends Node
class_name GameManager

## 全局游戏管理器
## 管理所有游戏数据：任务、资源、冒险家、协会
## 提供自动保存和存档导入/导出功能

# ========== 信号 ==========
signal resources_changed(resources: Dictionary)
signal task_started(task_id: String, adventurer_id: String)
signal task_completed(task_id: String, rewards: Dictionary)
signal adventurer_recruited(adventurer_id: String)
signal adventurer_status_changed(adventurer_id: String, new_status: String)
signal guild_upgraded(new_level: int)
signal game_saved()
signal game_loaded()

# ========== 常量 ==========
const BUILTIN_SAVE_PATH: String = "res://data/game_save.json"
const EXTERNAL_SAVE_RELATIVE_PATH: String = "data/game_save.json"
const AUTO_SAVE_INTERVAL: float = 10.0  # 秒

# ========== 游戏数据 ==========
var game_data: Dictionary = {}
var save_timer: float = 0.0
var active_save_path: String = ""

# ========== 生命周期 ==========

func _ready() -> void:
	load_game()

func _process(delta: float) -> void:
	# 自动保存
	save_timer += delta
	if save_timer >= AUTO_SAVE_INTERVAL:
		save_timer = 0.0
		save_game()

	# 更新运行中的任务倒计时
	update_running_tasks(delta)

# ========== 存档管理 ==========

## 获取外部存档路径（exe同目录）
func get_external_save_path() -> String:
	var exe_path = OS.get_executable_path()
	var exe_dir = exe_path.get_base_dir()
	return exe_dir.path_join(EXTERNAL_SAVE_RELATIVE_PATH)

## 确保外部存档目录存在
func ensure_external_save_dir() -> void:
	var external_path = get_external_save_path()
	var external_dir = external_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(external_dir):
		DirAccess.make_dir_recursive_absolute(external_dir)

## 加载游戏存档
func load_game() -> void:
	var external_path = get_external_save_path()

	# 优先从外部存档加载
	if FileAccess.file_exists(external_path):
		active_save_path = external_path
		print("📂 从外部存档加载: ", external_path)
	elif FileAccess.file_exists(BUILTIN_SAVE_PATH):
		active_save_path = BUILTIN_SAVE_PATH
		print("📦 从内置存档加载: ", BUILTIN_SAVE_PATH)
	else:
		# 没有存档，创建默认数据
		print("🆕 创建新存档")
		_create_default_game_data()
		save_game()
		game_loaded.emit()
		return

	# 读取存档文件
	var file = FileAccess.open(active_save_path, FileAccess.READ)
	if file == null:
		push_error("无法打开存档: " + active_save_path)
		_create_default_game_data()
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("存档解析失败: " + json.get_error_message())
		_create_default_game_data()
		return

	game_data = json.get_data()
	print("✅ 存档加载成功")
	game_loaded.emit()

## 保存游戏存档
func save_game() -> void:
	ensure_external_save_dir()
	var save_path = get_external_save_path()

	# 更新保存时间
	game_data["save_time"] = Time.get_datetime_string_from_system()

	var json_string = JSON.stringify(game_data, "\t")
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		game_saved.emit()
	else:
		push_error("保存失败: " + save_path)

## 导出存档到指定路径
func export_save(export_path: String) -> bool:
	var json_string = JSON.stringify(game_data, "\t")
	var file = FileAccess.open(export_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("📤 存档已导出到: ", export_path)
		return true
	push_error("导出失败: " + export_path)
	return false

## 从指定路径导入存档
func import_save(import_path: String) -> bool:
	if not FileAccess.file_exists(import_path):
		push_error("导入文件不存在: " + import_path)
		return false

	var file = FileAccess.open(import_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("导入文件格式错误: " + json.get_error_message())
		return false

	game_data = json.get_data()
	save_game()
	print("📥 存档已导入")
	game_loaded.emit()
	return true

## 创建默认游戏数据
func _create_default_game_data() -> void:
	game_data = {
		"version": "1.0",
		"save_time": Time.get_datetime_string_from_system(),
		"auto_save_interval": AUTO_SAVE_INTERVAL,

		"player": {
			"max_concurrent_tasks": 1
		},

		"resources": {
			"能量硬币": 500,
			"木材": 20,
			"石料": 10,
			"铁矿": 0
		},

		"tasks": [
			{
				"id": "001",
				"name": "巡逻边境",
				"faction": "帝国",
				"type": "护送",
				"difficulty": "简单",
				"rewards": {"能量硬币": 100, "木材": 5},
				"duration": "1分钟",
				"status": "可接取",
				"assigned_adventurer": null,
				"start_time": null,
				"remaining_seconds": 60
			},
			{
				"id": "002",
				"name": "矿物采集",
				"faction": "联邦",
				"type": "收集",
				"difficulty": "中等",
				"rewards": {"能量硬币": 200, "石料": 10},
				"duration": "2分钟",
				"status": "可接取",
				"assigned_adventurer": null,
				"start_time": null,
				"remaining_seconds": 120
			},
			{
				"id": "003",
				"name": "剿灭海盗",
				"faction": "独立",
				"type": "战斗",
				"difficulty": "困难",
				"rewards": {"能量硬币": 500, "铁矿": 15},
				"duration": "3分钟",
				"status": "可接取",
				"assigned_adventurer": null,
				"start_time": null,
				"remaining_seconds": 180
			}
		],

		"adventurers": [],

		"guild": {
			"level": 1,
			"name": "初级协会",
			"recruitable_adventurers": [
				{
					"id": "adv_001",
					"name": "艾丽娅",
					"faction": "帝国",
					"class": "剑士",
					"stats": {"攻击": 8, "防御": 6, "速度": 7},
					"recruitment_cost": {"能量硬币": 300, "木材": 10}
				},
				{
					"id": "adv_002",
					"name": "莱恩",
					"faction": "联邦",
					"class": "弓箭手",
					"stats": {"攻击": 7, "防御": 4, "速度": 9},
					"recruitment_cost": {"能量硬币": 400, "木材": 15}
				}
			],
			"upgrade_cost": {"能量硬币": 1000, "木材": 50, "石料": 30},
			"next_level_bonus": "解锁稀有冒险家"
		}
	}

# ========== 资源管理 ==========

## 获取资源数量
func get_resource(resource_name: String) -> int:
	return game_data.get("resources", {}).get(resource_name, 0)

## 获取所有资源
func get_all_resources() -> Dictionary:
	return game_data.get("resources", {})

## 增加资源
func add_resource(resource_name: String, amount: int) -> void:
	if not game_data.has("resources"):
		game_data["resources"] = {}
	var current = game_data["resources"].get(resource_name, 0)
	game_data["resources"][resource_name] = current + amount
	resources_changed.emit(game_data["resources"])

## 消耗资源（返回是否成功）
func consume_resource(resource_name: String, amount: int) -> bool:
	var current = get_resource(resource_name)
	if current >= amount:
		game_data["resources"][resource_name] = current - amount
		resources_changed.emit(game_data["resources"])
		return true
	return false

## 检查是否能支付费用
func can_afford(costs: Dictionary) -> bool:
	for resource_name in costs:
		if get_resource(resource_name) < costs[resource_name]:
			return false
	return true

## 支付费用（返回是否成功）
func pay_costs(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for resource_name in costs:
		consume_resource(resource_name, costs[resource_name])
	return true

# ========== 任务管理 ==========

## 获取所有任务
func get_all_tasks() -> Array:
	return game_data.get("tasks", [])

## 获取任务（通过ID）
func get_task(task_id: String) -> Dictionary:
	for task in get_all_tasks():
		if task.get("id") == task_id:
			return task
	return {}

## 获取当前进行中的任务数量
func get_running_tasks_count() -> int:
	var count = 0
	for task in get_all_tasks():
		if task.get("status") == "进行中":
			count += 1
	return count

## 获取最大同时任务数（1 + 冒险家数量）
func get_max_concurrent_tasks() -> int:
	return 1 + get_all_adventurers().size()

## 是否可以接受新任务
func can_accept_new_task() -> bool:
	return get_running_tasks_count() < get_max_concurrent_tasks()

## 获取可用冒险家（待命状态）
func get_available_adventurers() -> Array:
	var available = []
	for adv in get_all_adventurers():
		if adv.get("status") == "待命":
			available.append(adv)
	return available

## 开始任务
func start_task(task_id: String, adventurer_id: String = "") -> bool:
	if not can_accept_new_task():
		print("❌ 无法接受更多任务")
		return false

	var task = get_task(task_id)
	if task.is_empty() or task.get("status") != "可接取":
		return false

	# 如果有冒险家，分配冒险家
	var assigned_adv_id = ""
	if adventurer_id != "":
		var adv = get_adventurer(adventurer_id)
		if adv.is_empty() or adv.get("status") != "待命":
			print("❌ 冒险家不可用")
			return false
		assigned_adv_id = adventurer_id
		adv["status"] = "执行中"
		adv["current_task_id"] = task_id
		adventurer_status_changed.emit(adventurer_id, "执行中")
	else:
		# 自动分配第一个可用冒险家
		var available = get_available_adventurers()
		if available.size() > 0:
			var adv = available[0]
			assigned_adv_id = adv.get("id", "")
			adv["status"] = "执行中"
			adv["current_task_id"] = task_id
			adventurer_status_changed.emit(assigned_adv_id, "执行中")

	# 更新任务状态
	task["status"] = "进行中"
	task["assigned_adventurer"] = assigned_adv_id
	task["start_time"] = Time.get_unix_time_from_system()

	# 解析时长
	var duration_str = task.get("duration", "1分钟")
	task["remaining_seconds"] = _parse_duration_to_seconds(duration_str)

	task_started.emit(task_id, assigned_adv_id)
	print("✅ 任务开始: ", task.get("name"), " 冒险家: ", assigned_adv_id)
	return true

## 更新运行中的任务
func update_running_tasks(delta: float) -> void:
	for task in get_all_tasks():
		if task.get("status") == "进行中":
			var remaining = task.get("remaining_seconds", 0)
			remaining -= delta
			if remaining <= 0:
				remaining = 0
				complete_task(task.get("id"))
			task["remaining_seconds"] = remaining

## 完成任务
func complete_task(task_id: String) -> void:
	var task = get_task(task_id)
	if task.is_empty():
		return

	# 发放奖励
	var rewards = task.get("rewards", {})
	for resource_name in rewards:
		add_resource(resource_name, rewards[resource_name])

	# 释放冒险家
	var adv_id = task.get("assigned_adventurer")
	if adv_id is String and adv_id != "":
		var adv = get_adventurer(adv_id)
		if not adv.is_empty():
			adv["status"] = "待命"
			adv["current_task_id"] = null
			adventurer_status_changed.emit(adv_id, "待命")

	# 更新任务状态
	task["status"] = "已完成"
	task["assigned_adventurer"] = null
	task["remaining_seconds"] = 0

	task_completed.emit(task_id, rewards)
	print("🎉 任务完成: ", task.get("name"), " 奖励: ", rewards)

## 解析时长字符串为秒数
func _parse_duration_to_seconds(duration_str: String) -> float:
	if duration_str.ends_with("分钟"):
		var num_str = duration_str.replace("分钟", "").strip_edges()
		return float(num_str) * 60.0
	elif duration_str.ends_with("秒"):
		var num_str = duration_str.replace("秒", "").strip_edges()
		return float(num_str)
	return 60.0  # 默认1分钟

# ========== 冒险家管理 ==========

## 获取所有冒险家
func get_all_adventurers() -> Array:
	return game_data.get("adventurers", [])

## 获取冒险家（通过ID）
func get_adventurer(adventurer_id: String) -> Dictionary:
	for adv in get_all_adventurers():
		if adv.get("id") == adventurer_id:
			return adv
	return {}

## 招募冒险家
func recruit_adventurer(adventurer_id: String) -> bool:
	var guild = game_data.get("guild", {})
	var recruitable = guild.get("recruitable_adventurers", [])

	# 查找可招募冒险家
	var target_adv = null
	var target_idx = -1
	for i in range(recruitable.size()):
		if recruitable[i].get("id") == adventurer_id:
			target_adv = recruitable[i]
			target_idx = i
			break

	if target_adv == null:
		print("❌ 未找到可招募冒险家: ", adventurer_id)
		return false

	# 检查并支付费用
	var cost = target_adv.get("recruitment_cost", {})
	if not pay_costs(cost):
		print("❌ 资源不足，无法招募")
		return false

	# 从协会移除
	recruitable.remove_at(target_idx)

	# 添加到冒险家列表
	var new_adventurer = {
		"id": target_adv.get("id"),
		"name": target_adv.get("name"),
		"faction": target_adv.get("faction"),
		"class": target_adv.get("class"),
		"stats": target_adv.get("stats", {}),
		"status": "待命",
		"current_task_id": null
	}
	game_data["adventurers"].append(new_adventurer)

	adventurer_recruited.emit(adventurer_id)
	print("✅ 招募成功: ", target_adv.get("name"))
	return true

# ========== 协会管理 ==========

## 获取协会数据
func get_guild() -> Dictionary:
	return game_data.get("guild", {})

## 获取协会等级
func get_guild_level() -> int:
	return get_guild().get("level", 1)

## 获取可招募冒险家列表
func get_recruitable_adventurers() -> Array:
	return get_guild().get("recruitable_adventurers", [])

## 升级协会
func upgrade_guild() -> bool:
	var guild = get_guild()
	var cost = guild.get("upgrade_cost", {})

	if not pay_costs(cost):
		print("❌ 资源不足，无法升级协会")
		return false

	# 升级
	guild["level"] = guild.get("level", 1) + 1

	# 更新协会名称
	var level = guild["level"]
	match level:
		2: guild["name"] = "中级协会"
		3: guild["name"] = "高级协会"
		_: guild["name"] = "Lv." + str(level) + " 协会"

	# 更新升级费用（每级递增）
	var base_coin = 1000
	var base_wood = 50
	var base_stone = 30
	guild["upgrade_cost"] = {
		"能量硬币": base_coin * level,
		"木材": base_wood * level,
		"石料": base_stone * level
	}

	# 可以在这里添加新的可招募冒险家
	if level == 2:
		guild["recruitable_adventurers"].append({
			"id": "adv_003",
			"name": "卡尔",
			"faction": "独立",
			"class": "法师",
			"stats": {"攻击": 10, "防御": 3, "速度": 6},
			"recruitment_cost": {"能量硬币": 600, "木材": 20, "石料": 10}
		})
		guild["next_level_bonus"] = "解锁传说冒险家"

	guild_upgraded.emit(level)
	print("🏰 协会升级到 Lv.", level)
	return true
