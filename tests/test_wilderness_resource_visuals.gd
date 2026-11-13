extends SceneTree

var failures: int = 0

func _initialize() -> void:
    var simulation := WorldSimulation.new()
    var fruit_hex := Vector2i(5, 4)
    simulation.set_authored_resource_at(fruit_hex, "forest", {
        "type": "fruit_tree", "available": true, "regrow_at": 0.0
    })
    var stored := simulation.ensure_resource_at(fruit_hex)
    _check(String(stored.get("type", "")) == "fruit_tree", "Authored fruit tree should be available through world simulation")

    var fruit_visual := WildernessResourceVisual.new()
    root.add_child(fruit_visual)
    fruit_visual.refresh(stored, 0)
    _check(fruit_visual.has_node("ResourceLabel"), "Fruit tree should have a visible label")
    _check(fruit_visual.get_child_count() > 1, "Fruit tree should render a tree and fruit")

    var empty_fruit := stored.duplicate(true)
    empty_fruit["available"] = false
    fruit_visual.refresh(empty_fruit, 0)
    _check(fruit_visual.get_child_count() < 12, "Harvested fruit tree should lose its fruit props")

    var ore_visual := WildernessResourceVisual.new()
    root.add_child(ore_visual)
    ore_visual.refresh({
        "type": "ore_node", "item_id": "ore_iron", "depleted": false, "regrow_at": 0.0
    }, 0)
    _check(ore_visual.has_node("ResourceLabel"), "Ore vein should have a visible label")
    _check(ore_visual.get_child_count() >= 4, "Ore vein should render a rock and mineral shards")

    var herb_visual := WildernessResourceVisual.new()
    root.add_child(herb_visual)
    herb_visual.refresh({"type": "herb_patch", "available": true, "regrow_at": 0.0}, 0)
    _check(herb_visual.has_node("ResourceLabel"), "Herb patch should have a visible label")
    _check(herb_visual.get_child_count() >= 2, "Herb patch should render plants")

    var stump_visual := WildernessResourceVisual.new()
    root.add_child(stump_visual)
    stump_visual.refresh({"type": "timber_tree", "available": false, "regrow_at": 100.0}, 0)
    _check(stump_visual.has_node("ResourceLabel"), "Depleted timber tree should retain its label")
    _check(stump_visual.get_child_count() >= 2, "Depleted timber tree should show a stump")

    if failures > 0:
        push_error("%d wilderness visual test(s) failed." % failures)
        quit(1)
        return
    print("Wilderness resource visual tests passed.")
    quit(0)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)
