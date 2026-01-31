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
const AUTO_SAVE_INTERVAL: float = 10.0 # 秒

# ========== 游戏数据 ==========
var game_data: Dictionary = {}
var save_timer: float = 0.0
var active_save_path: String = ""

# 任务刷新系统变量
var task_id_counter: int = 1000 # 生成任务的ID计数器

# 冒险家生成系统变量
var adventurer_id_counter: int = 100
var used_names: Array = []

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

	# 执行迁移逻辑
	_ensure_config()
	_migrate_save_data()

	game_loaded.emit()

## 保存游戏存档
func save_game() -> void:
	ensure_external_save_dir()
	var save_path = get_external_save_path()

	# 更新保存时间和计数器
	game_data["save_time"] = Time.get_datetime_string_from_system()
	game_data["task_id_counter"] = task_id_counter
	game_data["adventurer_id_counter"] = adventurer_id_counter
	game_data["used_names"] = used_names

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

## 迁移存档数据（处理旧版本存档）
func _migrate_save_data() -> void:
	# 迁移1: 添加玩家冒险家（如果缺失）
	var has_player = false
	for adv in get_all_adventurers():
		if adv.get("is_player", false):
			has_player = true
			break

	if not has_player:
		print("📋 迁移: 添加玩家冒险家")
		var guild_level = get_guild_level()
		var base_stat = 5 + (guild_level - 1) * 2

		var player_adv = {
			"id": "player",
			"name": "玩家",
			"faction": "协会",
			"class": "会长",
			"stats": {"攻击": base_stat, "防御": base_stat, "速度": base_stat},
			"status": "待命",
			"current_task_id": null,
			"is_player": true
		}
		game_data["adventurers"].insert(0, player_adv)

	# 迁移2: 初始化任务计数器
	if not game_data.has("task_id_counter"):
		var max_id = 1000
		for task in get_all_tasks():
			var task_id = task.get("id", "")
			if task_id.begins_with("task_"):
				var id_num = int(task_id.replace("task_", ""))
				max_id = max(max_id, id_num)
		game_data["task_id_counter"] = max_id
		task_id_counter = max_id
	else:
		task_id_counter = game_data.get("task_id_counter", 1000)

	# 迁移3: 确保任务池健康
	maintain_task_pool()

	# 迁移4: 初始化冒险家计数器
	if not game_data.has("adventurer_id_counter"):
		var max_id = 100
		for adv in get_all_adventurers():
			var adv_id = adv.get("id", "")
			if adv_id.begins_with("adv_gen_"):
				var id_num = int(adv_id.replace("adv_gen_", ""))
				max_id = max(max_id, id_num)
		game_data["adventurer_id_counter"] = max_id
		adventurer_id_counter = max_id
	else:
		adventurer_id_counter = game_data.get("adventurer_id_counter", 100)

	# 迁移5: 初始化已用名字
	if not game_data.has("used_names"):
		game_data["used_names"] = []
	used_names = game_data.get("used_names", [])

	# 迁移6: 如果可招募冒险家是旧的硬编码数据，重新生成
	var recruitables = get_recruitable_adventurers()
	var has_generated = false
	for adv in recruitables:
		if adv.get("id", "").begins_with("adv_gen_"):
			has_generated = true
			break

	if not has_generated and recruitables.size() > 0:
		print("📋 迁移: 重新生成可招募冒险家")
		regenerate_recruitable_adventurers(get_guild_level())

	# 迁移7: 如果缺少协会等级配置，补齐默认配置
	_ensure_guild_level_config()

## 确保配置存在
func _ensure_config() -> void:
	if not game_data.has("config") or typeof(game_data["config"]) != TYPE_DICTIONARY:
		game_data["config"] = _get_default_config()
		return

	# 补齐缺失的配置项（浅合并）
	var defaults = _get_default_config()
	for key in defaults.keys():
		if not game_data["config"].has(key):
			game_data["config"][key] = defaults[key]

## 确保协会等级配置存在
func _ensure_guild_level_config() -> void:
	var config = game_data.get("config", {})
	var guild_cfg = config.get("guild", {})
	if not guild_cfg.has("levels"):
		guild_cfg["levels"] = _get_default_config().get("guild", {}).get("levels", {})
		config["guild"] = guild_cfg
		game_data["config"] = config

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

		"adventurers": [
			{
				"id": "player",
				"name": "玩家",
				"faction": "协会",
				"class": "会长",
				"stats": {"攻击": 5, "防御": 5, "速度": 5},
				"status": "待命",
				"current_task_id": null,
				"is_player": true
			}
		],

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
		},

		# 可调配置数据（策划可在存档中修改）
		"config": _get_default_config()
	}

## 默认配置（用于首次创建与缺失迁移）
func _get_default_config() -> Dictionary:
	return {
		"player": {
			"max_concurrent_tasks_base": 1,
			"max_concurrent_tasks_per_adventurer": 1
		},
		"tasks": {
			"id_prefix": "task_",
			"pool": {"min_available": 3, "max_available": 5},
			"factions": ["帝国", "联邦", "独立", "中立"],
			"types": ["护送", "收集", "战斗", "谈判", "救援", "探索"],
			"name_prefixes": {
				"护送": ["护送", "保护", "守卫"],
				"收集": ["采集", "收集", "搜寻"],
				"战斗": ["剿灭", "讨伐", "消灭"],
				"谈判": ["外交", "谈判", "调解"],
				"救援": ["救援", "营救", "紧急救援"],
				"探索": ["探索", "调查", "侦查"]
			},
			"name_targets": ["边境", "矿区", "海盗", "使节", "村民", "遗迹", "商队", "要塞", "森林", "山脉"],
			"guild_difficulty_offset": {"min_offset": 0, "max_offset": 1},
			"extra_reward": {
				"min_tier": 2,
				"resources": ["木材", "石料", "铁矿"],
				"base_amount_per_tier": 5,
				"variance_min": 0,
				"variance_max": 10
			},
			"difficulty_tiers": [
				{"tier": 1, "name": "简单", "coin_base": 50, "coin_variance_min": -20, "coin_variance_max": 50, "duration_min_s": 1, "duration_max_s": 5},
				{"tier": 2, "name": "中等", "coin_base": 100, "coin_variance_min": -20, "coin_variance_max": 50, "duration_min_s": 5, "duration_max_s": 15},
				{"tier": 3, "name": "困难", "coin_base": 150, "coin_variance_min": -20, "coin_variance_max": 50, "duration_min_s": 15, "duration_max_s": 30},
				{"tier": 4, "name": "精英", "coin_base": 200, "coin_variance_min": -20, "coin_variance_max": 50, "duration_min_s": 30, "duration_max_s": 60},
				{"tier": 5, "name": "传说", "coin_base": 250, "coin_variance_min": -20, "coin_variance_max": 50, "duration_min_s": 60, "duration_max_s": 120},
				{"tier": 6, "name": "史诗", "coin_base": 300, "coin_variance_min": -20, "coin_variance_max": 50, "duration_min_s": 120, "duration_max_s": 300}
			],
			"duration_display": {"ms_under_s": 3, "sec_under_s": 60},
			"catalog": [
				{"name": "巡逻边境", "faction": "帝国", "type": "护送"},
				{"name": "矿物采集", "faction": "联邦", "type": "收集"},
				{"name": "剿灭海盗", "faction": "独立", "type": "战斗"},
				{"name": "外交任务", "faction": "中立", "type": "谈判"},
				{"name": "紧急救援", "faction": "帝国", "type": "救援"}
			]
		},
		"adventurers": {
			"classes": [
				{"class": "剑士", "stat_profile": {"攻击": 1.2, "防御": 1.0, "速度": 0.8}},
				{"class": "弓箭手", "stat_profile": {"攻击": 1.0, "防御": 0.6, "速度": 1.4}},
				{"class": "法师", "stat_profile": {"攻击": 1.5, "防御": 0.5, "速度": 0.8}},
				{"class": "盾卫", "stat_profile": {"攻击": 0.7, "防御": 1.5, "速度": 0.6}},
				{"class": "刺客", "stat_profile": {"攻击": 1.3, "防御": 0.6, "速度": 1.5}},
				{"class": "游侠", "stat_profile": {"攻击": 1.0, "防御": 0.9, "速度": 1.2}}
			],
			"names": [
				"艾丽娅", "莱恩", "卡尔", "索菲娅", "泰勒", "玛莎",
				"杰克", "罗莎", "雷蒙德", "伊莎贝拉", "维克多", "娜塔莉",
				"亚历山大", "凯瑟琳", "塞巴斯蒂安", "奥利维亚"
			],
			"factions": ["帝国", "联邦", "独立", "中立"],
			"base_stat": {"min_base": 5, "max_base": 8, "min_per_level": 3, "max_per_level": 4},
			"cost": {
				"base_multiplier": 10,
				"variance_min": -50,
				"variance_max": 100,
				"wood_level": 2,
				"wood_divisor": 2,
				"wood_variance_max": 10,
				"stone_level": 3,
				"stone_divisor": 3,
				"stone_variance_max": 5
			},
			"recruitable_count": {"base": 2, "extra_per_level": 1, "max_extra": 2}
		},
		"guild": {
			"recruitable_cap": 4,
			"levels": {
				"1": {"name": "初级协会", "upgrade_cost": {"能量硬币": 1000, "木材": 50, "石料": 30}, "next_level_bonus": "解锁稀有冒险家"},
				"2": {"name": "中级协会", "upgrade_cost": {"能量硬币": 2000, "木材": 100, "石料": 60}, "next_level_bonus": "解锁稀有冒险家"},
				"3": {"name": "高级协会", "upgrade_cost": {"能量硬币": 3000, "木材": 150, "石料": 90}, "next_level_bonus": "解锁稀有冒险家"}
			}
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
	var cfg = game_data.get("config", {}).get("player", {})
	var base = int(cfg.get("max_concurrent_tasks_base", 1))
	var per_adv = int(cfg.get("max_concurrent_tasks_per_adventurer", 1))
	return base + (get_all_adventurers().size() * per_adv)

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
	print("🔍 [GameManager] start_task 被调用: task_id=", task_id, ", adventurer_id=", adventurer_id if adventurer_id != "" else "(空，将自动分配)")

	if not can_accept_new_task():
		print("❌ 无法接受更多任务")
		return false

	var task = get_task(task_id)
	if task.is_empty():
		print("❌ 任务不存在: ", task_id)
		return false
	if task.get("status") != "可接取":
		print("❌ 任务状态不是'可接取': ", task.get("status"))
		return false

	# 如果有冒险家，分配冒险家
	var assigned_adv_id = ""
	if adventurer_id != "":
		print("🔍 [GameManager] 尝试分配指定冒险家: ", adventurer_id)
		var adv_idx = _get_adventurer_index(adventurer_id)
		if adv_idx == -1:
			print("❌ 冒险家不存在: ", adventurer_id)
			return false
		if game_data["adventurers"][adv_idx].get("status") != "待命":
			print("❌ 冒险家状态不是'待命': ", game_data["adventurers"][adv_idx].get("status"))
			return false
		assigned_adv_id = adventurer_id
		game_data["adventurers"][adv_idx]["status"] = "执行中"
		game_data["adventurers"][adv_idx]["current_task_id"] = task_id
		print("✅ [GameManager] 冒险家分配成功: ", game_data["adventurers"][adv_idx].get("name"), " (", assigned_adv_id, ")")
		adventurer_status_changed.emit(adventurer_id, "执行中")
	else:
		# 自动分配第一个可用冒险家
		print("🔍 [GameManager] 自动分配冒险家...")
		var available = get_available_adventurers()
		print("🔍 [GameManager] 可用冒险家数量: ", available.size())
		if available.size() > 0:
			var adv = available[0]
			assigned_adv_id = adv.get("id", "")
			var adv_idx = _get_adventurer_index(assigned_adv_id)
			if adv_idx == -1:
				print("❌ [GameManager] 冒险家不存在: ", assigned_adv_id)
				return false
			game_data["adventurers"][adv_idx]["status"] = "执行中"
			game_data["adventurers"][adv_idx]["current_task_id"] = task_id
			print("✅ [GameManager] 自动分配冒险家: ", game_data["adventurers"][adv_idx].get("name"), " (", assigned_adv_id, ")")
			adventurer_status_changed.emit(assigned_adv_id, "执行中")
		else:
			print("❌ [GameManager] 没有可用冒险家，无法开始任务")
			return false # 没有冒险家时拒绝开始任务

	# 更新任务状态
	task["status"] = "进行中"
	task["assigned_adventurer"] = assigned_adv_id
	task["start_time"] = Time.get_unix_time_from_system()

	# 解析时长
	var duration_str = task.get("duration", "1分钟")
	task["remaining_seconds"] = _parse_duration_to_seconds(duration_str)
	print("🔍 [GameManager] 任务时长: ", duration_str, " (", task["remaining_seconds"], " 秒)")

	task_started.emit(task_id, assigned_adv_id)
	print("✅ 任务开始: ", task.get("name"), " 冒险家: ", assigned_adv_id if assigned_adv_id != "" else "(无)")
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
		var adv_idx = _get_adventurer_index(adv_id)
		if adv_idx != -1:
			var adv_data = game_data["adventurers"][adv_idx]
			# 一次性冒险家：任务完成后移除（玩家不移除）
			if adv_data.get("is_player", false):
				game_data["adventurers"][adv_idx]["status"] = "待命"
				game_data["adventurers"][adv_idx]["current_task_id"] = null
				adventurer_status_changed.emit(adv_id, "待命")
			else:
				game_data["adventurers"].remove_at(adv_idx)
				adventurer_status_changed.emit(adv_id, "移除")

	# 更新任务状态
	task["status"] = "已完成"
	task["assigned_adventurer"] = null
	task["remaining_seconds"] = 0

	task_completed.emit(task_id, rewards)
	print("🎉 任务完成: ", task.get("name"), " 奖励: ", rewards)

	# 立即刷新任务池
	maintain_task_pool()

## 解析时长字符串为秒数
func _parse_duration_to_seconds(duration_str: String) -> float:
	if duration_str.ends_with("毫秒"):
		var num_str = duration_str.replace("毫秒", "").strip_edges()
		return float(num_str) / 1000.0 # 毫秒转秒
	elif duration_str.ends_with("秒"):
		var num_str = duration_str.replace("秒", "").strip_edges()
		return float(num_str)
	elif duration_str.ends_with("分钟"):
		var num_str = duration_str.replace("分钟", "").strip_edges()
		return float(num_str) * 60.0
	return 60.0 # 默认1分钟

## 生成新任务（基于公会等级）
func generate_new_task(guild_level: int) -> Dictionary:
	var cfg = game_data.get("config", {}).get("tasks", {})

	task_id_counter += 1
	var task_id_prefix = str(cfg.get("id_prefix", "task_"))
	var task_id = task_id_prefix + str(task_id_counter)

	# 难度等级基于公会等级
	var difficulty_tier = _get_difficulty_tier(guild_level, cfg)
	var difficulty_name = _get_difficulty_name(difficulty_tier, cfg)

	# 随机任务类型和势力
	var task_types = cfg.get("types", ["护送", "收集", "战斗", "谈判", "救援", "探索"])
	var factions = cfg.get("factions", ["帝国", "联邦", "独立", "中立"])
	if task_types.size() == 0:
		task_types = _get_default_config().get("tasks", {}).get("types", [])
	if factions.size() == 0:
		factions = _get_default_config().get("tasks", {}).get("factions", [])

	var task_type = task_types[randi() % task_types.size()]
	var faction = factions[randi() % factions.size()]

	# 奖励基于难度
	var tier_cfg = _get_tier_config(difficulty_tier, cfg)
	var base_coins = int(tier_cfg.get("coin_base", 50 * difficulty_tier))
	var coin_variance = randi_range(int(tier_cfg.get("coin_variance_min", -20)), int(tier_cfg.get("coin_variance_max", 50)))
	var coins = base_coins + coin_variance

	var rewards = {"能量硬币": coins}

	# 难度2+添加额外资源奖励
	var extra_cfg = cfg.get("extra_reward", {})
	var extra_min_tier = int(extra_cfg.get("min_tier", 2))
	if difficulty_tier >= extra_min_tier:
		var resources = extra_cfg.get("resources", ["木材", "石料", "铁矿"])
		if resources.size() > 0:
			var res_type = resources[randi() % resources.size()]
			var base_amount = int(extra_cfg.get("base_amount_per_tier", 5)) * difficulty_tier
			var extra_amount = randi_range(int(extra_cfg.get("variance_min", 0)), int(extra_cfg.get("variance_max", 10)))
			rewards[res_type] = base_amount + extra_amount

	# 时长随难度增加，支持毫秒/秒/分钟
	var duration_str = _generate_task_duration(difficulty_tier, cfg)
	var duration_seconds = _parse_duration_to_seconds(duration_str)

	# 生成任务名称
	var task_name = _generate_task_name(task_type, faction, difficulty_tier, cfg)

	# 从候选列表里选取（如果有）
	var catalog = cfg.get("catalog", [])
	if typeof(catalog) == TYPE_ARRAY and catalog.size() > 0:
		var entry = catalog[randi() % catalog.size()]
		if typeof(entry) == TYPE_DICTIONARY:
			task_name = str(entry.get("name", task_name))
			task_type = str(entry.get("type", task_type))
			faction = str(entry.get("faction", faction))

	return {
		"id": task_id,
		"name": task_name,
		"faction": faction,
		"type": task_type,
		"difficulty": difficulty_name,
		"rewards": rewards,
		"duration": duration_str,
		"status": "可接取",
		"assigned_adventurer": null,
		"start_time": null,
		"remaining_seconds": duration_seconds
	}

## 获取难度等级
func _get_difficulty_tier(guild_level: int, cfg: Dictionary) -> int:
	# 公会1级: 难度1-2, 公会2级: 难度2-3, ...
	var offsets = cfg.get("guild_difficulty_offset", {})
	var min_offset = int(offsets.get("min_offset", 0))
	var max_offset = int(offsets.get("max_offset", 1))
	var min_tier = guild_level + min_offset
	var max_tier = guild_level + max_offset
	return randi_range(min_tier, max_tier)

## 获取难度名称
func _get_difficulty_name(tier: int, cfg: Dictionary) -> String:
	var tiers = cfg.get("difficulty_tiers", [])
	for entry in tiers:
		if typeof(entry) == TYPE_DICTIONARY and int(entry.get("tier", -1)) == tier:
			return str(entry.get("name", ""))
	match tier:
		1: return "简单"
		2: return "中等"
		3: return "困难"
		4: return "精英"
		5: return "传说"
		_: return "史诗"

## 生成任务名称
func _generate_task_name(task_type: String, _faction: String, tier: int, cfg: Dictionary) -> String:
	var prefixes = cfg.get("name_prefixes", {})
	var targets = cfg.get("name_targets", [])

	var prefix_list = prefixes.get(task_type, ["任务"])
	var prefix = prefix_list[randi() % prefix_list.size()]
	if targets.size() == 0:
		return prefix
	var target = targets[randi() % targets.size()]

	if tier >= 4:
		return prefix + "精英" + target
	elif tier >= 5:
		return prefix + "传说" + target
	else:
		return prefix + target

## 生成任务时长（基于难度等级）
func _generate_task_duration(difficulty_tier: int, cfg: Dictionary) -> String:
	# 根据配置决定时长范围
	var tier_cfg = _get_tier_config(difficulty_tier, cfg)
	var min_s = int(tier_cfg.get("duration_min_s", 60))
	var max_s = int(tier_cfg.get("duration_max_s", 60))
	if max_s < min_s:
		max_s = min_s
	var seconds = randi_range(min_s, max_s)

	var display = cfg.get("duration_display", {})
	var ms_under = float(display.get("ms_under_s", 3))
	var sec_under = float(display.get("sec_under_s", 60))

	if seconds < ms_under:
		return str(seconds * 1000) + "毫秒"
	elif seconds < sec_under:
		return str(seconds) + "秒"
	else:
		var minutes = int(ceil(seconds / 60.0))
		return str(minutes) + "分钟"

## 获取难度配置
func _get_tier_config(tier: int, cfg: Dictionary) -> Dictionary:
	var tiers = cfg.get("difficulty_tiers", [])
	for entry in tiers:
		if typeof(entry) == TYPE_DICTIONARY and int(entry.get("tier", -1)) == tier:
			return entry
	return {}

## 获取可用任务列表
func get_available_tasks() -> Array:
	var available = []
	for task in get_all_tasks():
		if task.get("status") == "可接取":
			available.append(task)
	return available

## 维护任务池（确保3-5个可用任务）
func maintain_task_pool() -> void:
	var cfg = game_data.get("config", {}).get("tasks", {})
	var pool_cfg = cfg.get("pool", {})
	var min_available = int(pool_cfg.get("min_available", 3))
	var max_available = int(pool_cfg.get("max_available", 5))

	var available_tasks = get_available_tasks()
	var available_count = available_tasks.size()

	# 移除已完成任务（立即刷新）
	var tasks = get_all_tasks()
	var i = tasks.size() - 1
	while i >= 0:
		if tasks[i].get("status") == "已完成":
			tasks.remove_at(i)
		i -= 1

	# 如果可用任务少于最小值，生成新任务
	while available_count < min_available:
		var new_task = generate_new_task(get_guild_level())
		tasks.append(new_task)
		available_count += 1

	# 限制最大可用任务数
	if available_count > max_available:
		var to_remove = available_count - max_available
		i = 0
		while i < tasks.size() and to_remove > 0:
			if tasks[i].get("status") == "可接取":
				tasks.remove_at(i)
				to_remove -= 1
			else:
				i += 1

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

## 获取冒险家索引（用于写回）
func _get_adventurer_index(adventurer_id: String) -> int:
	var adventurers = get_all_adventurers()
	for i in range(adventurers.size()):
		if adventurers[i].get("id") == adventurer_id:
			return i
	return -1

## 获取玩家冒险家
func get_player_adventurer() -> Dictionary:
	for adv in get_all_adventurers():
		if adv.get("is_player", false):
			return adv
	return {}

## 升级玩家属性（随协会等级）
func upgrade_player_stats(guild_level: int) -> void:
	var player = get_player_adventurer()
	if player.is_empty():
		return

	# 每级增加属性：基础5 + (等级-1)*2
	var base_stat = 5 + (guild_level - 1) * 2
	var idx = _get_adventurer_index(player.get("id", ""))
	if idx == -1:
		return
	game_data["adventurers"][idx]["stats"] = {
		"攻击": base_stat,
		"防御": base_stat,
		"速度": base_stat
	}
	print("📈 玩家属性提升到: ", base_stat)

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

	# 生成新的冒险家补充
	var guild_level = get_guild_level()
	var guild_cfg = game_data.get("config", {}).get("guild", {})
	var cap = int(guild_cfg.get("recruitable_cap", 999))
	if recruitable.size() < cap:
		var new_recruit = generate_recruitable_adventurer(guild_level)
		recruitable.append(new_recruit)

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

## 生成可招募冒险家
func generate_recruitable_adventurer(guild_level: int) -> Dictionary:
	var cfg = game_data.get("config", {}).get("adventurers", {})
	adventurer_id_counter += 1
	var adv_id = "adv_gen_" + str(adventurer_id_counter)

	# 随机职业
	var classes = cfg.get("classes", [])
	if classes.size() == 0:
		classes = _get_default_config().get("adventurers", {}).get("classes", [])
	var class_data = classes[randi() % classes.size()]
	var adv_class = class_data["class"]
	var stat_profile = class_data["stat_profile"]

	# 基础属性随公会等级提升
	# 1级: 5-8, 2级: 8-12, 3级: 12-18
	var base_cfg = cfg.get("base_stat", {})
	var base_min = int(base_cfg.get("min_base", 5)) + (guild_level - 1) * int(base_cfg.get("min_per_level", 3))
	var base_max = int(base_cfg.get("max_base", 8)) + (guild_level - 1) * int(base_cfg.get("max_per_level", 4))

	var base_attack = randi_range(base_min, base_max)
	var base_defense = randi_range(base_min, base_max)
	var base_speed = randi_range(base_min, base_max)

	# 应用职业系数
	var attack = int(base_attack * stat_profile["攻击"])
	var defense = int(base_defense * stat_profile["防御"])
	var speed = int(base_speed * stat_profile["速度"])

	var stats = {
		"攻击": attack,
		"防御": defense,
		"速度": speed
	}

	# 费用基于总属性
	var total_stats = attack + defense + speed
	var cost_cfg = cfg.get("cost", {})
	var base_cost = total_stats * int(cost_cfg.get("base_multiplier", 10))
	var cost_variance = randi_range(int(cost_cfg.get("variance_min", -50)), int(cost_cfg.get("variance_max", 100)))
	var coin_cost = base_cost + cost_variance

	var recruitment_cost = {"能量硬币": coin_cost}

	# 高等级冒险家需要额外资源
	if guild_level >= int(cost_cfg.get("wood_level", 2)):
		recruitment_cost["木材"] = total_stats / int(cost_cfg.get("wood_divisor", 2)) + randi_range(0, int(cost_cfg.get("wood_variance_max", 10)))
	if guild_level >= int(cost_cfg.get("stone_level", 3)):
		recruitment_cost["石料"] = total_stats / int(cost_cfg.get("stone_divisor", 3)) + randi_range(0, int(cost_cfg.get("stone_variance_max", 5)))

	# 唯一名字
	var adv_name = _get_unique_adventurer_name()
	var factions = cfg.get("factions", [])
	if factions.size() == 0:
		factions = _get_default_config().get("adventurers", {}).get("factions", [])
	var faction = factions[randi() % factions.size()]

	return {
		"id": adv_id,
		"name": adv_name,
		"faction": faction,
		"class": adv_class,
		"stats": stats,
		"recruitment_cost": recruitment_cost
	}

## 获取唯一的冒险家名字
func _get_unique_adventurer_name() -> String:
	var cfg = game_data.get("config", {}).get("adventurers", {})
	var name_pool = cfg.get("names", [])
	if name_pool.size() == 0:
		name_pool = _get_default_config().get("adventurers", {}).get("names", [])
	var available_names = []
	for adv_name in name_pool:
		if adv_name not in used_names:
			available_names.append(adv_name)

	if available_names.is_empty():
		# 所有名字用完，重置
		used_names.clear()
		available_names = name_pool.duplicate()

	var chosen_name = available_names[randi() % available_names.size()]
	used_names.append(chosen_name)
	return chosen_name

## 重新生成可招募冒险家列表
func regenerate_recruitable_adventurers(guild_level: int) -> void:
	var guild = get_guild()
	var cfg = game_data.get("config", {}).get("adventurers", {})
	var guild_cfg = game_data.get("config", {}).get("guild", {})

	# 清空当前可招募列表
	guild["recruitable_adventurers"] = []

	# 根据公会等级生成2-4个冒险家
	var count_cfg = cfg.get("recruitable_count", {})
	var base = int(count_cfg.get("base", 2))
	var extra_per_level = int(count_cfg.get("extra_per_level", 1))
	var max_extra = int(count_cfg.get("max_extra", 2))
	var count = base + min((guild_level - 1) * extra_per_level, max_extra)
	var cap = int(guild_cfg.get("recruitable_cap", count))
	count = min(count, cap)

	for i in range(count):
		var adv = generate_recruitable_adventurer(guild_level)
		guild["recruitable_adventurers"].append(adv)

	print("✨ 生成了 ", count, " 个可招募冒险家 (公会等级 ", guild_level, ")")

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
	var guild_cfg = game_data.get("config", {}).get("guild", {})
	var levels_cfg = guild_cfg.get("levels", {})
	var level_entry = levels_cfg.get(str(level), {})
	if not level_entry.is_empty():
		guild["name"] = level_entry.get("name", "Lv." + str(level) + " 协会")
	else:
		match level:
			2: guild["name"] = "中级协会"
			3: guild["name"] = "高级协会"
			_: guild["name"] = "Lv." + str(level) + " 协会"

	# 更新升级费用（每级递增）
	if not level_entry.is_empty() and level_entry.has("upgrade_cost"):
		guild["upgrade_cost"] = level_entry.get("upgrade_cost", {})
	else:
		var base_coin = 1000
		var base_wood = 50
		var base_stone = 30
		guild["upgrade_cost"] = {
			"能量硬币": base_coin * level,
			"木材": base_wood * level,
			"石料": base_stone * level
		}

	# 刷新可招募冒险家（属性更好）
	regenerate_recruitable_adventurers(level)

	# 升级玩家属性
	upgrade_player_stats(level)

	guild_upgraded.emit(level)
	print("🏰 协会升级到 Lv.", level)
	return true
