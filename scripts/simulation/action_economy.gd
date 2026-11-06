class_name ActionEconomy
extends RefCounted

## Shared rules for the original game's real-time Time Point economy.
## Simulation code owns these values; presentation only displays them.

const COMBAT_TURN_READY_TP: float = 100.0
const TURN_END_TP: int = 80
const MIN_TURN_END_TP: int = 60
const MAX_QUICK_RECOVERY_RANK: int = 20
const DEFAULT_MAX_TP: float = 150.0

static func can_start_combat_turn(
    time_points: float,
    alive: bool = true,
    unconscious: bool = false,
    is_rider: bool = false,
    combat_dormant: bool = false
) -> bool:
    return alive and not unconscious and not is_rider and not combat_dormant and time_points >= COMBAT_TURN_READY_TP

static func turn_end_threshold(quick_recovery_rank: int = 0) -> int:
    var rank := clampi(quick_recovery_rank, 0, MAX_QUICK_RECOVERY_RANK)
    return maxi(MIN_TURN_END_TP, TURN_END_TP - rank)

static func should_end_turn(time_points: float, quick_recovery_rank: int = 0, forced: bool = false) -> bool:
    return forced or floori(time_points) <= turn_end_threshold(quick_recovery_rank)

static func can_afford(time_points: float, cost: float) -> bool:
    return cost >= 0.0 and time_points >= cost

static func spend(time_points: float, cost: float) -> float:
    if cost < 0.0:
        return time_points
    return time_points - cost

static func regenerate(
    time_points: float,
    rate_per_tick: float = 1.0,
    tick_multiplier: float = 1.0,
    maximum: float = DEFAULT_MAX_TP
) -> float:
    if rate_per_tick <= 0.0 or tick_multiplier <= 0.0 or maximum <= 0.0:
        return time_points
    # Match the source engine: the cap is a gate on gaining TP, not a clamp
    # after every tick. A character just below 150 can therefore overshoot
    # by one tick's gain, but never regenerates again until below the cap. 
    if time_points >= maximum:
        return time_points
    return time_points + rate_per_tick * tick_multiplier
