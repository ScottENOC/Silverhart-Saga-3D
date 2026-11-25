extends SceneTree

const REGISTRY = preload("res://scripts/world/campaign2_multistory_location_registry.gd")
const LOCATION_STATE = preload("res://scripts/simulation/campaign2_multistory_location_state.gd")
var failures: int = 0

func _initialize() -> void:
	var registry = REGISTRY.new()
	var definition: Dictionary = registry.get_definition("kragmoor")
	var state = LOCATION_STATE.new()
	var configured: Dictionary = state.configure(definition)
	_check(bool(configured.get("ok", false)), "Kragmoor floor state must configure from the validated source definition")
	_check(state.current_floor == 0, "New location visits must begin in the Gate Hall")

	var wrong_stair: Dictionary = state.try_transition(-1, Vector2i(908, -609))
	_check(not bool(wrong_stair.get("ok", false)) and String(wrong_stair.get("reason", "")) == "no_stair_at_position", "Floor changes must require the exact source stair position")
	var down_to_hall: Dictionary = state.try_transition(-1, Vector2i(908, -610))
	_check(bool(down_to_hall.get("ok", false)) and state.current_floor == -1, "The Gate Hall stair must reach the Great Hall")
	_check(bool(state.try_transition(0, Vector2i(908, -610)).get("ok", false)), "The Great Hall stair must return to the Gate Hall")
	_check(bool(state.try_transition(-1, Vector2i(908, -610)).get("ok", false)), "The Gate Hall stair must permit a return descent")
	_check(bool(state.try_transition(-2, Vector2i(908, -626)).get("ok", false)), "The Great Hall stair must reach the Vault/Runeforge")
	_check(bool(state.try_transition(-3, Vector2i(890, -627)).get("ok", false)), "The Runeforge stair must reach the Deep Mine")
	_check(bool(state.try_transition(-4, Vector2i(890, -617)).get("ok", false)), "The mine stair must reach the Lower Tunnels")

	var sealed_result: Dictionary = state.try_transition(-5, Vector2i(890, -605))
	_check(not bool(sealed_result.get("ok", false)) and String(sealed_result.get("reason", "")) == "transition_locked", "The Sunken Deep must remain inaccessible before the source quest completes")
	_check(String(sealed_result.get("quest_id", "")) == "deepholds_infestation", "The locked stair must report the source quest ID")
	var reveal: Dictionary = state.complete_quest("deepholds_infestation")
	_check(bool(reveal.get("ok", false)) and reveal.get("revealed", []).size() == 1, "Completing What Nests Below must reveal the final stair")
	var repeated_reveal: Dictionary = state.complete_quest("deepholds_infestation")
	_check(bool(repeated_reveal.get("already_revealed", false)), "Revealing the final stair must be idempotent")
	_check(bool(state.try_transition(-5, Vector2i(890, -605)).get("ok", false)), "The revealed stair must permit entry to the Sunken Deep")

	var saved: Dictionary = state.to_dict()
	var restored = LOCATION_STATE.new()
	_check(bool(restored.configure(definition, saved).get("ok", false)), "Location floor state must restore from its save representation")
	_check(restored.current_floor == -5, "Save/load must preserve the current floor")
	_check(restored.is_transition_available(-4, -5, Vector2i(890, -605)), "Save/load must preserve the revealed Sunken Deep passage")

	var guild_definition: Dictionary = registry.get_definition("silverhart_thieves_guild")
	var guild_state = LOCATION_STATE.new()
	_check(bool(guild_state.configure(guild_definition).get("ok", false)), "Thieves' Guild state must configure its concealed vault")
	_check(not bool(guild_state.discover_secret("unknown_secret").get("ok", false)), "Unknown secret doors must not be discoverable")
	var secret_reveal: Dictionary = guild_state.discover_secret("guild_hidden_vault_door")
	_check(bool(secret_reveal.get("ok", false)) and not bool(secret_reveal.get("already_discovered", true)), "Source hidden vault door must be discoverable once")
	_check(bool(guild_state.discover_secret("guild_hidden_vault_door").get("already_discovered", false)), "Repeated secret discovery must be idempotent")
	var guild_saved: Dictionary = guild_state.to_dict()
	_check(guild_saved.get("discovered_secrets", []).has("guild_hidden_vault_door"), "Secret discovery must be included in the location save")
	var guild_restored = LOCATION_STATE.new()
	_check(bool(guild_restored.configure(guild_definition, guild_saved).get("ok", false)), "Guild secret state must restore from campaign save data")
	_check(guild_restored.is_secret_discovered("guild_hidden_vault_door"), "Save/load must preserve discovered secret doors")
	var invalid_secret_save := guild_saved.duplicate(true)
	invalid_secret_save["discovered_secrets"] = ["not_a_real_secret"]
	var invalid_secret_restore = LOCATION_STATE.new()
	_check(not bool(invalid_secret_restore.configure(guild_definition, invalid_secret_save).get("ok", false)), "Unknown discovered secret IDs must be rejected during restore")
	var invalid_save := saved.duplicate(true)
	invalid_save["current_floor"] = -99
	var rejected = LOCATION_STATE.new()
	_check(not bool(rejected.configure(definition, invalid_save).get("ok", false)), "Unknown saved floors must be rejected")
	var sealed_save := saved.duplicate(true)
	sealed_save["current_floor"] = -5
	sealed_save["unlocked_transitions"] = []
	var sealed_restore = LOCATION_STATE.new()
	_check(not bool(sealed_restore.configure(definition, sealed_save).get("ok", false)), "A save must not place the player in the Sunken Deep without its quest gate unlocked")

	if failures > 0:
		push_error("%d multi-story location state test(s) failed." % failures)
		quit(1)
		return
	print("Kragmoor multi-story traversal and persistence state validated.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
