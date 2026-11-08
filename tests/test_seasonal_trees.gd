extends SceneTree

var failures: int = 0

func _initialize() -> void:
    _check(SeasonalTreeVisual.season_for_month(11) == SeasonalTreeVisual.SPRING, "Greenbud should be spring")
    _check(SeasonalTreeVisual.season_for_month(0) == SeasonalTreeVisual.SPRING, "Dawnfrost should be spring")
    _check(SeasonalTreeVisual.season_for_month(3) == SeasonalTreeVisual.SUMMER, "Goldfield should be summer")
    _check(SeasonalTreeVisual.season_for_month(6) == SeasonalTreeVisual.AUTUMN, "Rainfall should be autumn")
    _check(SeasonalTreeVisual.season_for_month(9) == SeasonalTreeVisual.WINTER, "Starrynight should be winter")

    var deciduous := SeasonalTreeVisual.new()
    root.add_child(deciduous)
    deciduous.refresh_month(6)
    _check(deciduous.current_season == SeasonalTreeVisual.AUTUMN, "Deciduous tree should update to autumn")
    var autumn_child_count := deciduous.get_child_count()
    deciduous.refresh_month(9)
    _check(deciduous.current_season == SeasonalTreeVisual.WINTER, "Deciduous tree should update to winter")
    _check(deciduous.get_child_count() > 0 and deciduous.get_child_count() != autumn_child_count, "Winter tree should rebuild as bare branches")
    deciduous.refresh_month(9)
    _check(deciduous.get_child_count() > 0, "Repeated updates within a season should preserve its meshes")

    var evergreen := SeasonalTreeVisual.new()
    evergreen.evergreen = true
    root.add_child(evergreen)
    evergreen.refresh_month(9)
    _check(evergreen.current_season == SeasonalTreeVisual.WINTER, "Evergreen should receive winter season state")
    _check(evergreen.get_child_count() >= 6, "Evergreen should retain its needles and show winter snow accents")

    if failures > 0:
        push_error("%d seasonal tree test(s) failed." % failures)
        quit(1)
        return
    print("Seasonal tree tests passed.")
    quit(0)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)
