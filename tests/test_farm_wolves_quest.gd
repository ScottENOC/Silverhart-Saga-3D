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

	var accepted_dialogue := FARM_QUEST.resolve_dialogue_choice(journal, null, "farm_wolves_accept")
	assert(accepted_dialogue.handled)
	assert(String(accepted_dialogue.dialogue.speaker) == "Old Mac")
	assert(String(accepted_dialogue.dialogue.text).contains("fence"))
	assert(String(journal.quest_state(FARM_QUEST.QUEST_ID).status) == "active")

	var progress := FARM_QUEST.record_wolf_defeat(journal, 3)
	assert(progress.ok and progress.completed)
	var player := CharacterState.new("player", "Adventurer", Vector2i.ZERO)
	player.gold = 10
	player.experience = 0
	var turn_in_dialogue := FARM_QUEST.resolve_dialogue_choice(journal, player, "farm_wolves_turn_in")
	assert(turn_in_dialogue.handled and turn_in_dialogue.quest_completed)
	assert(String(turn_in_dialogue.dialogue.text).contains("farm owes you"))
	var reward: Dictionary = turn_in_dialogue.reward
	assert(reward.ok)

	assert(player.gold == 35)
	assert(player.experience == 150)
	assert(String(journal.quest_state(FARM_QUEST.QUEST_ID).status) == "completed")
	assert(is_equal_approx(journal.npc_standing("old_mac"), 15.0))
	assert(is_equal_approx(float(journal.region_campaign_state("hollowmere").get("security", 0.0)), 56.0))
	assert(is_equal_approx(float(journal.region_campaign_state("aldervale").get("security", 0.0)), 51.8))
	assert(is_equal_approx(float(journal.region_campaign_state("silverhart_kingdom").get("security", 0.0)), 55.54))

func _test_creature_assets_exist() -> void:
	assert(AnimalCatalog.has_profile("sheep"), "Sheep must have a first-class animal gameplay profile")
	assert(FileAccess.file_exists("res://art/creatures/generated/Sheep.tscn"), "Generated sheep scene must exist")
	var sheep_state := AnimalCatalog.create_state("sheep", "test_sheep", "Test Sheep", Vector2i.ZERO, 123)
	assert(sheep_state != null and sheep_state.max_health <= 4, "Sheep must retain the source low-health profile")
	for filename in ["Cow.gltf", "Horse.gltf", "Horse_White.gltf", "ShibaInu.gltf", "Wolf.gltf", "Fox.gltf", "Deer.gltf", "Stag.gltf"]:
		var path: String = "res://art/creatures/quaternius/" + filename
		assert(FileAccess.file_exists(path), "Missing creature asset: " + path)
