extends SceneTree
const ACTOR_SCRIPT = preload("res://scripts/presentation/ara_character_actor.gd")
const BODY_PATH := "res://art/characters/ara_runtime/ara_person_body.glb"
const MALE_BODY_PATH := "res://art/characters/ara_runtime/ara_person_male_body.glb"
const MODULAR_PATH := "res://art/characters/ara_runtime/ara_person_modular.glb"
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    assert(ResourceLoader.exists(BODY_PATH), "Missing female Ara base body")
    assert(ResourceLoader.exists(MALE_BODY_PATH), "Missing Workshop male anatomy-integrated body")
    assert(ResourceLoader.exists(MODULAR_PATH), "Missing Workshop modular clothing model")
    var actor := ACTOR_SCRIPT.new()
    root.add_child(actor)
    assert(actor.configure(BODY_PATH), "Could not configure Ara base body")
    assert(actor.configure_modular_garments(MODULAR_PATH), "Could not attach modular garments to the Ara rig")
    var male_actor := ACTOR_SCRIPT.new()
    root.add_child(male_actor)
    assert(male_actor.configure(MALE_BODY_PATH), "Could not configure Workshop male anatomy-integrated body")
    var props_available := ResourceLoader.exists("res://art/characters/ara_runtime/props/sword.glb") and ResourceLoader.exists("res://art/characters/ara_runtime/props/round_shield.glb")
    actor.apply_equipment_visuals({
        "armour": {"id": "reinforced_leather_armor"},
        "weapon": {"id": "sword"},
        "offhand": {"id": "wooden_shield"}
    })
    assert(bool(actor.get_meta("modular_garments_loaded", false)), "Modular garment layer was not retained")
    await process_frame
    if props_available:
        var attachments: Dictionary = actor.get("equipment_attachments")
        assert(attachments.has("weapon"), "Sword did not attach to WeaponR")
        assert(attachments.has("offhand"), "Shield did not attach to WeaponL")
        print("ARA_RUNTIME_EQUIPMENT_TEST: PASS (body, modular armour, sword and shield)")
    else:
        print("ARA_RUNTIME_EQUIPMENT_TEST: PARTIAL (modular armour passed; prop bundle not yet available)")
    actor.queue_free()
    male_actor.queue_free()
    quit(0)
