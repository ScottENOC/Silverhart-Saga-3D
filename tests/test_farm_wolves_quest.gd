extends SceneTree

const FARM_QUEST = preload("res://scripts/simulation/farm_wolves_quest.gd")

func _initialize() -> void:
	_test_source_backed_quest_flow()
	_test_creature_assets_exist()
	print("Farm and wildlife tests passed.")
	quit()

func _test_source_backed_quest_flow() -> void:
	var journal := CampaignJournal.new()
	assert(journal.register_quest_definition(FARM_QUEST.definition()).ok)
	var initial := FARM_QUEST.greeting(journal, -1)
	assert(String(initial.text).contains("cattle"))
	assert(not String(initial.text).to_lower().contains("sheep"))
	assert(initial.choices.size() == 2)

	var accepted := FARM_QUEST.accept(journal)
	assert(accepted.ok)
	assert(String(journal.quest_state(FARM_QUEST.QUEST_ID).status) == "active")

	var progress := FARM_QUEST.record_wolf_defeat(journal, 3)
	assert(progress.ok and progress.completed)
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	player.gold = 10
	player.experience = 0
	var reward := FARM_QUEST.turn_in(journal, player)
	assert(reward.ok)
	assert(player.gold == 35)
	assert(player.experience == 150)
	assert(String(journal.quest_state(FARM_QUEST.QUEST_ID).status) == "completed")
	assert(is_equal_approx(journal.npc_standing("old_mac"), 15.0))

func _test_creature_assets_exist() -> void:
	for filename in ["Cow.gltf", "Horse.gltf", "Horse_White.gltf", "ShibaInu.gltf", "Wolf.gltf", "Fox.gltf", "Deer.gltf", "Stag.gltf"]:
		var path: String = "res://art/creatures/quaternius/" + filename
		assert(FileAccess.file_exists(path), "Missing creature asset: " + path)
