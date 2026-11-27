extends SceneTree

const RELATIONSHIP_STORE = preload("res://scripts/simulation/persistent_character_relationship_store.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_authored_roster_and_initial_state()
	_test_approval_bridge_and_independent_axes()
	_test_campaign_journal_synchronisation()
	_test_idempotent_conversations_and_events()
	_test_friendship_only_profiles()
	_test_save_load_and_history_bounds()
	_test_world_simulation_save_bridge()
	if _failures > 0:
		push_error("%d persistent NPC relationship assertion(s) failed." % _failures)
		quit(1)
		return
	print("Persistent NPC relationship tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_authored_roster_and_initial_state() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	_check(relationships.roster().size() == 16, "All source-authored persistent NPCs are registered")
	var seraphine := relationships.snapshot("seraphine_corrin")
	_check(String(seraphine.get("name", "")) == "Queen Seraphine Corrin")
	_check(String(seraphine.get("affinity_mode", "")) == "full")
	_check(int(seraphine.get("familiarity", -1)) == 5)
	_check(int(seraphine.get("trust", -1)) == 10)
	var skarnub := relationships.snapshot("chief_skarnub")
	_check(str(skarnub.get("name", "")) == "Chief Skarnub")
	_check(int(skarnub.get("trust", -1)) == 0)
	var rowan := relationships.snapshot("rowan_fletcher")
	_check(String(rowan.get("name", "")) == "Rowan Fletcher")
	_check(String(rowan.get("affinity_mode", "")) == "full", "Rowan should have attraction and romantic-bond axes.")
	_check(int(rowan.get("attraction", -1)) == 0 and int(rowan.get("romantic_bond", -1)) == 0, "Rowan should begin without an assumed romantic relationship.")
	var nessa := relationships.snapshot("nessa_wren")
	_check(int(nessa.get("familiarity", -1)) == 4)
	_check(int(nessa.get("trust", -1)) == 7)
	_check(int(nessa.get("friendship", -1)) == 2)
	var hollowmere_profiles := {
		"garrick_holt":"Garrick Holt",
		"mira_ashbrook":"Mira Ashbrook",
		"oskar_vinn":"Oskar Vinn",
		"elder_marta":"Elder Marta Wynfield",
		"old_mac":"Old Mac"
	}
	for character_id in hollowmere_profiles:
		var profile := relationships.profile_for(character_id)
		var snapshot := relationships.snapshot(character_id)
		_check(String(profile.get("name", "")) == String(hollowmere_profiles[character_id]), "%s has its authored profile" % character_id)
		_check(String(snapshot.get("affinity_mode", "")) == "friendship", "%s must not gain unauthored romance axes" % character_id)
		_check(int(snapshot.get("romantic_bond", -1)) == 0 and int(snapshot.get("attraction", -1)) == 0)


func _test_approval_bridge_and_independent_axes() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var initial := relationships.snapshot("petra_voss", -40.0)
	_check(int(initial.get("approval", -1)) == 30, "NPC standing -40 maps to approval 30")
	var adjusted := relationships.adjust_relationship("petra_voss", {"trust":12,"friendship":8}, "negotiated honestly")
	_check(int(adjusted.get("trust", -1)) == 16)
	_check(int(adjusted.get("friendship", -1)) == 8)
	_check(int(adjusted.get("approval", -1)) == 30, "Trust and friendship do not change approval")
	var approval := relationships.adjust_relationship("petra_voss", {"approval":20}, "earned confidence")
	_check(int(approval.get("approval", -1)) == 50)
	var pending := relationships.pending_npc_standing_sync("petra_voss")
	_check(bool(pending.get("pending", false)))
	_check(int(pending.get("standing", 999)) == 0, "Approval 50 maps back to journal standing 0")
	_check(relationships.confirm_npc_standing_sync("petra_voss"))
	_check(not bool(relationships.pending_npc_standing_sync("petra_voss").get("pending", true)))
	var refreshed := relationships.snapshot("petra_voss", 80.0)
	_check(int(refreshed.get("approval", -1)) == 90, "A later journal standing refreshes approval when no local write is pending")


func _test_campaign_journal_synchronisation() -> void:
	var journal := CampaignJournal.new()
	journal.seed_npc_reputation("petra_voss", -40.0)
	var relationships := PersistentCharacterRelationshipState.new()
	var initial := relationships.sync_with_journal("petra_voss", journal)
	_check(bool(initial.get("ok", false)))
	_check(int(initial.relationship.get("approval", -1)) == 30)
	relationships.adjust_relationship("petra_voss", {"approval":20}, "earned the factor's confidence")
	var pending := relationships.pending_npc_standing_sync("petra_voss")
	_check(bool(pending.get("pending", false)))
	var synced := relationships.sync_with_journal("petra_voss", journal)
	_check(bool(synced.get("ok", false)))
	_check(is_equal_approx(journal.npc_standing("petra_voss"), 0.0), "Approval changes update the authoritative campaign NPC standing")
	_check(int(synced.relationship.get("approval", -1)) == 50)
	_check(not bool(relationships.pending_npc_standing_sync("petra_voss").get("pending", true)))


func _test_idempotent_conversations_and_events() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var first := relationships.note_conversation("ilsa_rennick", "captain:opening", {"familiarity":2,"trust":1})
	var repeated := relationships.note_conversation("ilsa_rennick", "captain:opening", {"familiarity":2,"trust":1})
	_check(int(first.get("familiarity", -1)) == 6)
	_check(int(first.get("trust", -1)) == 9)
	_check(repeated == first, "A repeated conversation key has no additional effect")
	var event := relationships.record_event("thrain_emberhand", "runesmith:returned_ore", {"trust":8,"friendship":3})
	var repeated_event := relationships.record_event("thrain_emberhand", "runesmith:returned_ore", {"trust":8,"friendship":3})
	_check(int(event.get("trust", -1)) == 14)
	_check(int(event.get("friendship", -1)) == 4)
	_check(repeated_event == event, "A repeated authored event key has no additional effect")


func _test_friendship_only_profiles() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	var aelwen := relationships.adjust_relationship("aelwen_silthandriel", {"friendship":25,"romantic_bond":90,"attraction":90})
	_check(int(aelwen.get("friendship", -1)) == 25)
	_check(int(aelwen.get("romantic_bond", -1)) == 0, "Friendship-only profiles do not acquire unauthored romance")
	_check(int(aelwen.get("attraction", -1)) == 0)
	_check(relationships.snapshot("unknown_character").is_empty())


func _test_save_load_and_history_bounds() -> void:
	var relationships := PersistentCharacterRelationshipState.new()
	for index in range(150):
		relationships.note_conversation("seraphine_corrin", "audience:" + str(index), {"familiarity":1})
	var saved := relationships.to_dict()
	var restored := PersistentCharacterRelationshipState.new()
	restored.from_dict(saved)
	var state := restored.snapshot("seraphine_corrin")
	_check(int(state.get("familiarity", -1)) == 100, "Familiarity is clamped at 100")
	_check(restored.states["seraphine_corrin"].get("known_conversation_keys", []).size() == 120)
	_check(restored.states["seraphine_corrin"].get("history", []).size() <= 40)


func _test_world_simulation_save_bridge() -> void:
	var source := WorldSimulation.new()
	source.campaign_journal.seed_npc_reputation("seraphine_corrin", 20.0)
	var source_relationships := RELATIONSHIP_STORE.state_for(source)
	source_relationships.sync_all_with_journal(source.campaign_journal)
	source_relationships.adjust_relationship(
		"seraphine_corrin", {"trust": 27, "friendship": 11}, "test persistent NPC save bridge"
	)
	var saved := RELATIONSHIP_STORE.to_dict(source)

	var restored := WorldSimulation.new()
	restored.campaign_journal.seed_npc_reputation("seraphine_corrin", 20.0)
	_check(RELATIONSHIP_STORE.restore(restored, saved), "The campaign simulation should restore persistent NPC relationship state")
	var queen := RELATIONSHIP_STORE.state_for(restored).snapshot("seraphine_corrin", restored.campaign_journal.npc_standing("seraphine_corrin"))
	_check(int(queen.get("trust", -1)) == 37, "Queen's trust should survive the authoritative save/restore bridge")
	_check(int(queen.get("friendship", -1)) == 11, "Queen's friendship should survive the authoritative save/restore bridge")
	_check(int(queen.get("approval", -1)) == 60, "Queen's approval should remain synchronised with campaign NPC standing")
