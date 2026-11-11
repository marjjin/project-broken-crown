extends SceneTree
## Headless integration tests for the first level, "El Despertar" (phase 4):
##   godot --headless --path . --script res://tests/level_tests.gd
## Exit code is the number of failed checks (0 = all passed).
##
## Note: with --script, this file is compiled before autoloads are registered.
## Gameplay code now reaches the session through GameSessionState.instance(),
## so this is no longer required, but the untyped access below is harmless.
## Gameplay scripts that use the GameSession autoload (Door, Checkpoint, ...)
## must therefore not be referenced by class name here; they are accessed as
## plain nodes with dynamic calls instead.

const PHYSICS_HZ := 60.0
const LEVEL := "res://scenes/levels/the_awakening/the_awakening.tscn"

## Walkable points per sector, used for connectivity checks (y = floor).
const SECTOR_POINTS := {
	"A burial chamber": Vector3(0, 0, -3),
	"B crypt halls": Vector3(0, 0, -21),
	"C guard hall": Vector3(0, 0, -38),
	"D1 ossuary": Vector3(15, 0, -37),
	"D2 bone hall": Vector3(17, 0, -58),
	"E guardian chamber": Vector3(17, 0, -80),
}

var _failures := 0
var _checks := 0
var _level: Node
var _player: PlayerController
var _region: NavigationRegion3D
var _session: Node
var _interactor: PlayerInteractor
var _player_health: HealthComponent
var _player_actions: PlayerActionController
var _last_notification := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_session = root.get_node_or_null(^"GameSession")
	if _session == null:
		push_error("GameSession autoload missing")
		quit(1)
		return
	_session.reset()
	_level = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(_level)
	await _frames(30)
	_player = _level.get_node("Player") as PlayerController
	_region = _level.get_node("Crypt") as NavigationRegion3D

	_interactor = _player.get_node("Interactor") as PlayerInteractor
	_player_health = HealthComponent.find_in(_player)
	_player_actions = _player.get_node("ActionController") as PlayerActionController
	_session.notification_requested.connect(func(title: String, _body: String) -> void: _last_notification = title)

	# Stage 1: geometry and route (doors still closed).
	_test_level_loaded()
	_test_player_spawn()
	_test_no_navmesh_on_walls()
	await _test_ramp_climbable()
	await _test_camera_in_corridor()

	# Stage 2: interaction and doors.
	await _test_closed_door_blocks()
	await _test_prompt_and_range()
	await _test_inscription()
	await _test_door_opens_with_interaction()
	await _test_dead_player_cannot_interact()
	await _open_all_doors()
	await _test_sectors_connected()

	# Stage 3: checkpoint.
	await _test_checkpoint_rest()
	await _test_respawn_at_checkpoint()

	# Stage 4: enemies, exploration, level end, atmosphere.
	_test_enemy_distribution()
	await _test_enemy_patrols_in_level()
	await _test_enemy_chases_through_open_door()
	await _test_combat_in_level()
	await _test_secondary_route()
	await _test_collectible()
	await _test_weapon_altar()
	await _test_level_exit()
	_test_atmosphere_setup()

	# Stage 5: third-party CC0 assets.
	_test_pbr_materials()
	_test_models_in_level()
	_test_door_leaves_swing()
	await _test_ossuary_gate_blocks()

	print("\n%d/%d checks passed" % [_checks - _failures, _checks])
	quit(_failures)


# --- Stage 1 ------------------------------------------------------------------

func _test_level_loaded() -> void:
	print("\n[level]")
	_check(_level.is_inside_tree(), "level scene instantiated")
	var polygons := _region.navigation_mesh.get_polygon_count()
	_check(polygons > 50, "crypt navmesh baked (%d polygons)" % polygons)
	_check(_session.current_level == &"the_awakening", "GameSession knows the current level")


func _test_player_spawn() -> void:
	print("\n[spawn]")
	var p := _player.global_position
	_check(absf(p.x) < 6.0 and p.z > -6.0 and p.z < 6.0, "player starts inside the burial chamber (%s)" % p.snapped(Vector3.ONE * 0.1))
	_check(_player.get_facing_direction().dot(Vector3.FORWARD) > 0.95, "player faces the chamber exit (north)")


func _test_sectors_connected() -> void:
	print("\n[navigation connectivity]")
	var map := _region.get_navigation_map()
	var names := SECTOR_POINTS.keys()
	for i in range(1, names.size()):
		var from: Vector3 = SECTOR_POINTS[names[i - 1]]
		var to: Vector3 = SECTOR_POINTS[names[i]]
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		var reached := not path.is_empty() and Vector2(path[-1].x - to.x, path[-1].z - to.z).length() < 0.8
		_check(reached, "%s -> %s is walkable for enemies" % [names[i - 1], names[i]])


func _test_no_navmesh_on_walls() -> void:
	print("\n[navmesh height]")
	var vertices := _region.navigation_mesh.get_vertices()
	var highest := -INF
	var high_spots := {}
	for v in vertices:
		if v.z < -93.5:
			continue # The exit ramp is a real walkable slope.
		highest = maxf(highest, v.y)
		if v.y > 1.0:
			high_spots[Vector3(roundf(v.x), roundf(v.y * 4.0) / 4.0, roundf(v.z))] = true
	if not high_spots.is_empty():
		print("    elevated navmesh near: ", high_spots.keys().slice(0, 12))
	_check(highest < 1.0, "no navmesh on top of walls, pillars or ceilings (highest vertex y = %.2f)" % highest)


func _test_ramp_climbable() -> void:
	print("\n[ramp to the exit]")
	await _place_player(Vector3(17, 0.1, -95))
	Input.action_press(InputActions.MOVE_FORWARD)
	# Stop on the terrace before the exit trigger (that one is tested later).
	await _seconds(3.7)
	Input.action_release(InputActions.MOVE_FORWARD)
	_check(_player.global_position.y > 2.8, "player walks up the ascending corridor (y = %.2f)" % _player.global_position.y)
	_check(_player.global_position.z < -108.0 and _player.global_position.z > -114.0, "and reaches the terrace (z = %.1f)" % _player.global_position.z)


func _test_camera_in_corridor() -> void:
	print("\n[camera in corridors]")
	await _place_player(Vector3(0, 0.1, -10.5))
	var rig := _player.get_node("CameraRig") as Node3D
	var camera := _player.get_viewport().get_camera_3d()
	# Look sideways: the spring arm would pass through the corridor wall.
	rig.global_rotation.y = deg_to_rad(90.0)
	await _frames(10)
	var cam_x := camera.global_position.x
	_check(absf(cam_x) < 1.5, "camera stays inside the 3 m corridor when looking at a wall (x = %.2f)" % cam_x)
	rig.global_rotation.y = 0.0
	await _frames(10)
	_check(camera.global_position.z > _player.global_position.z + 2.0, "camera has room behind the player along the corridor")


# --- Stage 2 ------------------------------------------------------------------

## Untyped on purpose: see the note at the top of this file.
func _door(path: String) -> Node:
	return _level.get_node("Crypt/" + path)


func _test_closed_door_blocks() -> void:
	print("\n[closed door]")
	var door = _door("SectorA/ChamberDoor")
	_check(not door.is_open(), "chamber door starts closed")
	await _place_player(Vector3(0, 0.1, -3.5))
	Input.action_press(InputActions.MOVE_FORWARD)
	await _seconds(1.5)
	Input.action_release(InputActions.MOVE_FORWARD)
	_check(_player.global_position.z > -6.2, "the closed door stops the player (z = %.2f)" % _player.global_position.z)
	var path := NavigationServer3D.map_get_path(_region.get_navigation_map(), Vector3(0, 0, -3), Vector3(0, 0, -10), true)
	var blocked := path.is_empty() or Vector2(path[-1].x, path[-1].z + 10.0).length() > 1.0
	_check(blocked, "and blocks enemy navigation through the doorway")


func _test_prompt_and_range() -> void:
	print("\n[interaction prompt]")
	await _place_player(Vector3(4.5, 0.1, 1.5))
	await _seconds(0.3)
	_check(_interactor.get_focus() == null, "nothing to interact with out of reach")
	await _place_player(Vector3(0, 0.1, -4.8))
	await _seconds(0.3)
	var focus := _interactor.get_focus()
	_check(focus != null and focus.get_parent() == _door("SectorA/ChamberDoor"), "standing at the door focuses it")
	var prompt := _level.get_node("LevelHUD/Prompt") as Label
	_check(prompt.visible and prompt.text.contains("Abrir"), "the HUD shows the contextual prompt ('%s')" % prompt.text)


func _test_inscription() -> void:
	print("\n[inscription]")
	_last_notification = ""
	await _place_player(Vector3(0, 0.1, 2.6))
	_player.face_toward(Vector3.FORWARD)
	await _seconds(0.3)
	await _press_interact()
	_check(_last_notification == "Lápida", "reading the tombstone shows its text ('%s')" % _last_notification)


func _test_door_opens_with_interaction() -> void:
	print("\n[open door]")
	var door = _door("SectorA/ChamberDoor")
	await _place_player(Vector3(0, 0.1, -4.8))
	_player.face_toward(Vector3.FORWARD)
	await _seconds(0.3)
	await _press_interact()
	_check(door.is_open(), "pressing E opens the door")
	await _seconds(door.open_duration + 0.2)
	_check(door.navigation_link.enabled, "the doorway navigation link is enabled once open")
	await _seconds(0.3)
	_check(_interactor.get_focus() == null, "an open door no longer offers interaction")
	Input.action_press(InputActions.MOVE_FORWARD)
	await _seconds(1.5)
	Input.action_release(InputActions.MOVE_FORWARD)
	_check(_player.global_position.z < -8.0, "the player walks through the open doorway (z = %.2f)" % _player.global_position.z)


func _test_dead_player_cannot_interact() -> void:
	print("\n[dead player]")
	var door = _door("SectorC/HallEntranceDoor")
	await _place_player(Vector3(0, 0.1, -30.5))
	_player.face_toward(Vector3.FORWARD)
	await _seconds(0.3)
	_check(_interactor.get_focus() != null, "alive: the guard hall door is interactable")
	_player_health.apply_damage(DamageInfo.new(1000.0))
	await _seconds(0.3)
	await _press_interact()
	_check(not door.is_open(), "a dead player cannot open doors")
	_check(_interactor.get_focus() == null, "and gets no prompt")
	await _wait_player_locomotion(_player_actions.settings.respawn_delay + 1.0)


func _open_all_doors() -> void:
	for path in ["SectorA/ChamberDoor", "SectorC/HallEntranceDoor", "SectorC/CatacombDoor"]:
		_door(path).open()
	await _seconds(1.5)


# --- Stage 3 ------------------------------------------------------------------

const STATUE_SPAWN := Vector3(0, 0.1, -42.8)


func _test_checkpoint_rest() -> void:
	print("\n[checkpoint]")
	var statue = _level.get_node("Crypt/SectorC/GuardStatue")
	var stamina := StaminaComponent.find_in(_player)
	_check(_session.active_checkpoint == &"", "no checkpoint active at the start")
	_check(not statue.is_active(), "the statue starts dormant")
	await _place_player(Vector3(0, 0.1, -42.3))
	_player.face_toward(Vector3.FORWARD)
	_player_health.apply_damage(DamageInfo.new(40.0))
	await _wait_player_locomotion() # Taking damage staggers briefly.
	stamina.try_consume(60.0)
	await _seconds(0.3)
	_last_notification = ""
	await _press_interact()
	_check(_session.active_checkpoint == &"guard_hall", "resting registers the active checkpoint")
	_check(statue.is_active(), "the statue lights up")
	_check(is_equal_approx(_player_health.get_current(), _player_health.max_health), "health restored (%.0f)" % _player_health.get_current())
	_check(is_equal_approx(stamina.get_current(), stamina.max_stamina), "stamina restored (%.0f)" % stamina.get_current())
	_check(_last_notification == "Punto de descanso", "a confirmation banner is shown ('%s')" % _last_notification)
	_check(_player.get_spawn_position().distance_to(STATUE_SPAWN) < 0.05, "the respawn point moved to the statue")


func _test_respawn_at_checkpoint() -> void:
	print("\n[respawn at checkpoint]")
	# Die far away from the statue, in the catacombs.
	await _place_player(Vector3(17, 0.1, -58))
	_player_health.apply_damage(DamageInfo.new(1000.0))
	_check(_player_actions.get_state() == PlayerActionController.State.DEAD, "the existing death flow runs")
	await _seconds(_player_actions.settings.respawn_delay * 0.5)
	_check(_player.global_position.distance_to(Vector3(17, 0.1, -58)) < 1.0, "the body stays put while dead")
	await _wait_player_locomotion(_player_actions.settings.respawn_delay + 1.0)
	_check(_player.global_position.distance_to(STATUE_SPAWN) < 0.5, "player reappears at the statue (%s)" % _player.global_position.snapped(Vector3.ONE * 0.1))
	_check(not _player_health.is_dead() and is_equal_approx(_player_health.get_current(), _player_health.max_health), "with full health")
	_check(_player.get_facing_direction().dot(Vector3.BACK) > 0.95, "facing away from the statue, toward the hall")
	var start := _player.global_position
	Input.action_press(InputActions.MOVE_FORWARD)
	await _seconds(0.5)
	Input.action_release(InputActions.MOVE_FORWARD)
	_check(_player.global_position.z - start.z > 1.0, "movement and camera work again: W walks toward the camera's forward (+Z)")
	_check(_player_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK), "combat actions work again")
	await _wait_player_locomotion()


# --- Stage 4 ------------------------------------------------------------------

func _soldier(path: String) -> EnemyCharacter:
	return _level.get_node("Crypt/" + path) as EnemyCharacter


func _brain_of(soldier: EnemyCharacter) -> EnemyBrain:
	return soldier.get_node("Brain") as EnemyBrain


func _test_enemy_distribution() -> void:
	print("\n[enemy distribution]")
	var enemies := _level.get_tree().get_nodes_in_group(&"enemies")
	var first := 0
	var catacombs := 0
	var arena := 0
	for e: Node3D in enemies:
		var p := e.global_position
		if p.z > -30.0:
			first += 1
		elif p.x > 8.0 and p.z > -66.0:
			catacombs += 1
		elif p.z < -70.0:
			arena += 1
	_check(first == 1, "first encounter (crypt halls): 1 enemy (%d)" % first)
	_check(catacombs >= 2 and catacombs <= 3, "catacombs: 2-3 enemies (%d)" % catacombs)
	_check(arena == 0, "Guardian chamber is empty for now (%d)" % arena)
	_check(_level.get_node_or_null("Crypt/SectorE/MinibossSpawn") != null, "a miniboss spawn point is reserved")
	_check(_brain_of(_soldier("SectorD/SoldierBoneHallGuard")).get_patrol_points().is_empty(), "the bone hall guard stands watch without a route")


func _test_enemy_patrols_in_level() -> void:
	print("\n[enemy patrol in the crypt]")
	await _place_player(STATUE_SPAWN) # Safe room, doors open but far away.
	var brain := _brain_of(_soldier("SectorB/CorruptedSoldier"))
	var reached := [0]
	var on_reached := func(_i: int) -> void: reached[0] += 1
	brain.patrol_point_reached.connect(on_reached)
	var frames := int(14.0 * PHYSICS_HZ)
	while reached[0] < 2 and frames > 0:
		await physics_frame
		frames -= 1
	brain.patrol_point_reached.disconnect(on_reached)
	_check(reached[0] >= 2, "the crypt-halls soldier patrols its route (%d points; %s at %s)" % [reached[0], brain.get_state_name(), _soldier("SectorB/CorruptedSoldier").global_position.snapped(Vector3.ONE * 0.1)])


func _test_enemy_chases_through_open_door() -> void:
	print("\n[enemy through doorway]")
	var soldier := _soldier("SectorB/CorruptedSoldier")
	var brain := _brain_of(soldier)
	# Soldier in corridor B1 looking south; player inside the burial chamber.
	_player.global_position = Vector3(0, 0.1, -1.0)
	_player.velocity = Vector3.ZERO
	soldier.global_position = Vector3(0, 0.1, -11.5)
	soldier.velocity = Vector3.ZERO
	soldier.snap_facing(Vector3.BACK)
	brain.reset_ai()
	var frames := int(6.0 * PHYSICS_HZ)
	var max_wall_overlap := false
	while soldier.flat_distance_to(_player.global_position) > soldier.data.attack_range + 0.3 and frames > 0:
		await physics_frame
		frames -= 1
		var p := soldier.global_position
		# Doorway is x -1.5..1.5 at z -6..-7; anything else at that depth is wall.
		max_wall_overlap = max_wall_overlap or (p.z < -6.0 and p.z > -7.0 and absf(p.x) > 1.5)
	_check(brain.get_state() in [EnemyBrain.State.CHASE, EnemyBrain.State.ATTACK], "soldier chases the player (%s)" % brain.get_state_name())
	_check(soldier.global_position.z > -6.0, "it follows through the open doorway into the chamber (z = %.1f)" % soldier.global_position.z)
	_check(not max_wall_overlap, "without clipping through the wall")


func _test_combat_in_level() -> void:
	print("\n[combat in the level]")
	var soldier := _soldier("SectorB/CorruptedSoldier")
	var health := soldier.get_node("HealthComponent") as HealthComponent
	var hp := _player_health.get_current()
	var frames := int(4.0 * PHYSICS_HZ)
	while _player_health.get_current() >= hp and frames > 0:
		await physics_frame
		frames -= 1
	_check(_player_health.get_current() < hp, "the soldier's attack hurts the player")
	await _wait_player_locomotion()
	_aim_at(soldier.global_position)
	var before := health.get_current()
	(soldier.get_node("Hurtbox") as Hurtbox).receive_hit(DamageInfo.new(before - 5.0, _player))
	await _frames(2)
	_aim_at(soldier.global_position)
	await _frames(10) # Let the character turn toward the camera aim.
	_player_actions.request_action(PlayerActionController.Action.LIGHT_ATTACK)
	await _wait_player_locomotion()
	_check(health.is_dead(), "player attacks finish it off")
	_check(_brain_of(soldier).get_state() == EnemyBrain.State.DEAD, "the soldier is dead and stops acting")
	_player_health.revive()


func _test_secondary_route() -> void:
	print("\n[secondary route]")
	var map := _region.get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, Vector3(17, 0, -37), Vector3(36, 0, -38), true)
	var enemy_can_enter := not path.is_empty() and Vector2(path[-1].x - 36.0, path[-1].z + 38.0).length() < 1.0
	_check(not enemy_can_enter, "enemies cannot cross the collapsed rubble")
	await _place_player(Vector3(23.6, 0.1, -40))
	Input.action_press(InputActions.MOVE_RIGHT)
	await _seconds(0.25)
	Input.action_press(InputActions.JUMP)
	await _frames(3)
	Input.action_release(InputActions.JUMP)
	await _seconds(1.5)
	Input.action_release(InputActions.MOVE_RIGHT)
	_check(_player.global_position.x > 28.0, "the player can jump the rubble into the side crypt (x = %.1f)" % _player.global_position.x)


func _test_collectible() -> void:
	print("\n[collectible]")
	var medallion := _level.get_node_or_null("Crypt/SectorD/GuardMedallion")
	_check(medallion != null, "the guard medallion waits in the hidden crypt")
	await _place_player(Vector3(36, 0.1, -41.2))
	_player.face_toward(Vector3.FORWARD)
	await _seconds(0.3)
	_last_notification = ""
	await _press_interact()
	await _frames(2)
	_check(_session.has_collected(&"guard_medallion"), "interacting collects it (session state)")
	_check(not is_instance_valid(medallion), "the pickup disappears")
	_check(_last_notification.begins_with("Obtenido"), "a pickup banner is shown ('%s')" % _last_notification)


func _test_weapon_altar() -> void:
	print("\n[weapon point of interest]")
	await _place_player(Vector3(37.5, 0.1, -40))
	_player.face_toward(Vector3.RIGHT)
	await _seconds(0.3)
	_last_notification = ""
	await _press_interact()
	_check(_last_notification == "Altar de armas", "the empty weapon altar can be examined ('%s')" % _last_notification)
	_check(_level.get_node_or_null("Crypt/SectorD/WeaponAltar/WeaponMount") != null, "it has a mount point for a future weapon")


func _test_level_exit() -> void:
	print("\n[level exit]")
	_check(not _session.is_level_completed(&"the_awakening"), "level not completed before reaching the exit")
	await _place_player(Vector3(17, 3.2, -110))
	Input.action_press(InputActions.MOVE_FORWARD)
	await _seconds(1.5)
	Input.action_release(InputActions.MOVE_FORWARD)
	_check(_session.is_level_completed(&"the_awakening"), "walking onto the terrace completes the level")
	_check(_last_notification.begins_with("El Despertar"), "the closing message is shown ('%s')" % _last_notification)
	Input.action_press(InputActions.MOVE_FORWARD)
	await _seconds(2.0)
	Input.action_release(InputActions.MOVE_FORWARD)
	_check(_player.global_position.z > -121.0 and _player.global_position.y > 2.5, "the player stays inside the level after the end")


func _test_atmosphere_setup() -> void:
	print("\n[atmosphere (configuration only, not a visual test)]")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus", "renderer is Forward+")
	var env := (_level.get_node("Environment/WorldEnvironment") as WorldEnvironment).environment
	_check(env.volumetric_fog_enabled and env.fog_enabled, "volumetric and distance fog enabled")
	var lights := _level.find_children("*", "OmniLight3D", true, false)
	var shadowed := lights.filter(func(l: OmniLight3D) -> bool: return l.shadow_enabled)
	_check(lights.size() >= 15, "torches and accent lights placed (%d omni lights)" % lights.size())
	_check(shadowed.size() <= 2, "few shadow-casting omni lights for performance (%d)" % shadowed.size())


# --- Stage 5 ------------------------------------------------------------------

func _test_pbr_materials() -> void:
	print("\n[PBR materials]")
	for path in ["res://resources/materials/crypt_wall.tres", "res://resources/materials/crypt_floor.tres", "res://resources/materials/crypt_ceiling.tres"]:
		var mat := load(path) as StandardMaterial3D
		var ok := mat != null and mat.albedo_texture != null and mat.normal_enabled and mat.normal_texture != null \
			and mat.roughness_texture != null and mat.ao_enabled and mat.ao_texture != null and mat.uv1_world_triplanar
		_check(ok, "%s uses albedo + normal + roughness + AO textures (world triplanar)" % path.get_file())
	var normal := load("res://assets/third_party/polyhaven/textures/castle_wall_slates/castle_wall_slates_nor_gl_1k.jpg") as Texture2D
	_check(normal != null and normal.get_width() == 1024, "1K textures imported (normal map %dpx)" % (normal.get_width() if normal else 0))


func _test_models_in_level() -> void:
	print("\n[3D models in the level]")
	var counts := {}
	for node in _level.find_children("*", "Node3D", true, false):
		var source: String = node.scene_file_path
		if source.begins_with("res://assets/third_party/polyhaven/models/"):
			var id := source.get_base_dir().get_file()
			counts[id] = counts.get(id, 0) + 1
	for id in ["large_castle_door", "large_iron_gate", "stone_fire_pit", "kite_shield", "antique_estoc", "rock_07"]:
		_check(counts.get(id, 0) > 0, "%s is placed in the level (%d instances)" % [id, counts.get(id, 0)])
	_check(FileAccess.file_exists("res://docs/ASSET_LICENSES.md"), "asset licenses are documented")


func _test_door_leaves_swing() -> void:
	print("\n[door model leaves]")
	var door = _door("SectorA/ChamberDoor")
	var leaves: Array = door._leaves
	_check(leaves.size() == 2, "the castle door model provides two leaves (%d)" % leaves.size())
	var all_open := leaves.size() == 2
	for leaf: Node3D in leaves:
		all_open = all_open and absf(rad_to_deg(absf(leaf.rotation.y)) - 90.0) < 1.0
	_check(all_open, "both leaves swing open around their own hinges")


func _test_ossuary_gate_blocks() -> void:
	print("\n[ossuary gate]")
	var map := _region.get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, Vector3(12, 0, -59), Vector3(8, 0, -59), true)
	var enters := not path.is_empty() and Vector2(path[-1].x - 8.0, path[-1].z + 59.0).length() < 0.8
	_check(not enters, "the iron gate seals the niche for navigation")
	await _place_player(Vector3(11.5, 0.1, -59))
	Input.action_press(InputActions.MOVE_LEFT)
	await _seconds(1.5)
	Input.action_release(InputActions.MOVE_LEFT)
	_check(_player.global_position.x > 9.5, "and stops the player (x = %.2f)" % _player.global_position.x)
	_last_notification = ""
	await _press_interact()
	_check(_last_notification == "Reja oxidada", "the gate can be examined ('%s')" % _last_notification)


func _press_interact() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	var release := key.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)


func _wait_player_locomotion(max_seconds: float = 3.0) -> void:
	var frames := int(max_seconds * PHYSICS_HZ)
	while _player_actions.get_state() != PlayerActionController.State.LOCOMOTION and frames > 0:
		await physics_frame
		frames -= 1


# --- Helpers ------------------------------------------------------------------

## Teleports the player and points the camera north (-Z), so tests can use
## absolute directions (W = north, D = east) regardless of earlier respawns.
func _place_player(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_set_camera_yaw(0.0)
	await _frames(5)


func _set_camera_yaw(yaw: float) -> void:
	(_player.get_node("CameraRig") as Node3D).global_rotation.y = yaw


## Points the camera (and therefore the camera-facing character) at `point`.
func _aim_at(point: Vector3) -> void:
	var d := point - _player.global_position
	_set_camera_yaw(atan2(-d.x, -d.z))


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(ceili(seconds * PHYSICS_HZ))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
