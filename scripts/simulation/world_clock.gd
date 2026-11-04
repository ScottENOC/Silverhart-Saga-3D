class_name WorldClock
extends RefCounted

signal ticked(tick_index: int, world_seconds: float)
signal time_advanced(world_seconds: float)

## The source game advances world time in 0.4-second simulation quanta.
## Exploration runs at 5 game-seconds per real second; combat waiting runs
## at 40, matching the source engine's 0.4-second update per 10ms tick.
const SIMULATION_STEP_SECONDS: float = 0.4
const EXPLORATION_SECONDS_PER_REAL_SECOND: float = 5.0
const COMBAT_SECONDS_PER_REAL_SECOND: float = 40.0
const SECONDS_PER_MINUTE: int = 60
const SECONDS_PER_HOUR: int = 3600
const SECONDS_PER_DAY: int = 86400
const DAYS_PER_MONTH: int = 30
const MONTHS_PER_YEAR: int = 12
const DAYS_PER_YEAR: int = DAYS_PER_MONTH * MONTHS_PER_YEAR
const MONTH_NAMES: Array[String] = [
    "Dawnfrost", "Brightsun", "Highbloom", "Goldfield",
    "Harvest", "Redleaf", "Rainfall", "Shadowfell",
    "Deepwinter", "Starrynight", "Frostmelt", "Greenbud",
]

var world_seconds: float = 0.0
var tick_index: int = 0
var paused: bool = false
var time_speed_multiplier: float = 1.0
var accumulator: float = 0.0

func advance_real_time(real_delta: float, in_combat: bool = false) -> int:
    if paused or real_delta <= 0.0:
        return 0
    var base_rate := COMBAT_SECONDS_PER_REAL_SECOND if in_combat else EXPLORATION_SECONDS_PER_REAL_SECOND
    return advance_world_seconds(real_delta * base_rate * maxf(0.0, time_speed_multiplier))

## Explicit advancement is useful for deterministic tests, sleep/rest and saves.
## Returns the number of fixed simulation ticks processed.
func advance_world_seconds(delta_seconds: float) -> int:
    if paused or delta_seconds <= 0.0:
        return 0
    accumulator += delta_seconds
    var ticks_processed := 0
    while accumulator + 0.0000001 >= SIMULATION_STEP_SECONDS:
        accumulator -= SIMULATION_STEP_SECONDS
        if accumulator < 0.0:
            accumulator = 0.0
        world_seconds += SIMULATION_STEP_SECONDS
        tick_index += 1
        ticks_processed += 1
        ticked.emit(tick_index, world_seconds)
    if ticks_processed > 0:
        time_advanced.emit(world_seconds)
    return ticks_processed

func set_world_seconds(value: float) -> void:
    world_seconds = maxf(0.0, value)
    accumulator = 0.0

## Calendar mirrors the source game's 12 x 30-day year.
func calendar_date() -> Dictionary:
    var total_days := floori(world_seconds / float(SECONDS_PER_DAY))
    var day_of_year := posmod(total_days, DAYS_PER_YEAR)
    var month_index := floori(day_of_year / float(DAYS_PER_MONTH))
    return {
        "year": floori(total_days / float(DAYS_PER_YEAR)) + 1,
        "month_index": month_index,
        "month_name": MONTH_NAMES[month_index],
        "day_of_month": posmod(day_of_year, DAYS_PER_MONTH) + 1,
    }

func time_of_day() -> Dictionary:
    var seconds_into_day := int(fposmod(world_seconds, float(SECONDS_PER_DAY)))
    var hour := floori(seconds_into_day / float(SECONDS_PER_HOUR))
    var minute := floori(posmod(seconds_into_day, SECONDS_PER_HOUR) / float(SECONDS_PER_MINUTE))
    return {
        "hour": hour,
        "minute": minute,
        "text": "%02d:%02d" % [hour, minute],
    }

func to_dict() -> Dictionary:
    return {
        "world_seconds": world_seconds,
        "tick_index": tick_index,
        "accumulator": accumulator,
        "time_speed_multiplier": time_speed_multiplier,
        "paused": paused,
    }

func load_dict(data: Dictionary) -> void:
    world_seconds = maxf(0.0, float(data.get("world_seconds", 0.0)))
    tick_index = maxi(0, int(data.get("tick_index", 0)))
    accumulator = clampf(float(data.get("accumulator", 0.0)), 0.0, SIMULATION_STEP_SECONDS - 0.000001)
    time_speed_multiplier = maxf(0.0, float(data.get("time_speed_multiplier", 1.0)))
    paused = bool(data.get("paused", false))
