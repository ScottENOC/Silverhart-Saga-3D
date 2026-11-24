class_name WorldWeatherState
extends RefCounted
## Deterministic regional weather driven by the authoritative WorldClock.
## Weather is selected in three-hour periods; a saved campaign seed makes the
## same world time reproduce the same weather after save/load.

signal weather_changed(conditions: Dictionary)

const WEATHER_PERIOD_SECONDS := 10800.0
const SECONDS_PER_DAY := 86400.0

var seed: int = 1
var current_period_index: int = -1
var current_conditions: Dictionary = {}


func _init(seed_value: int = 0) -> void:
	if seed_value > 0:
		seed = seed_value
	else:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		seed = rng.randi_range(1, 2147483646)


func update_to(world_seconds: float) -> bool:
	var period_index := floori(maxf(0.0, world_seconds) / WEATHER_PERIOD_SECONDS)
	if period_index == current_period_index and not current_conditions.is_empty():
		return false
	current_period_index = period_index
	current_conditions = conditions_at(world_seconds)
	weather_changed.emit(current_conditions.duplicate(true))
	return true


func conditions_at(world_seconds: float, terrain_id: String = "") -> Dictionary:
	var safe_seconds := maxf(0.0, world_seconds)
	var day_index := floori(safe_seconds / SECONDS_PER_DAY)
	var seconds_into_day := fposmod(safe_seconds, SECONDS_PER_DAY)
	var hour := seconds_into_day / 3600.0
	var month_index := posmod(floori(day_index / 30.0), 12)
	var season := season_for_month(month_index)
	var period_index := floori(safe_seconds / WEATHER_PERIOD_SECONDS)
	var roll := _stable_roll(day_index, period_index, 1)
	var weather_type := _select_weather(season, roll)
	var daily_temperature := (_stable_roll(day_index, 0, 2) - 0.5) * 5.0
	var temperature := _season_temperature(season) + daily_temperature
	temperature += _diurnal_temperature(hour)
	match weather_type:
		"overcast":
			temperature -= 1.0
		"rain":
			temperature -= 2.5
		"heavy_rain":
			temperature -= 3.5
		"storm":
			temperature -= 4.0
		"fog":
			temperature -= 2.0
		"snow":
			temperature -= 5.0
	var wind_roll := _stable_roll(day_index, period_index, 3)
	var wind_speed := 5.0 + wind_roll * 12.0
	var rain_intensity := 0.0
	var is_storm := false
	var is_snow := false
	var is_fog := false
	match weather_type:
		"overcast":
			wind_speed = 8.0 + wind_roll * 14.0
		"rain":
			wind_speed = 12.0 + wind_roll * 18.0
			rain_intensity = 0.25 + wind_roll * 0.30
		"heavy_rain":
			wind_speed = 20.0 + wind_roll * 18.0
			rain_intensity = 0.72 + wind_roll * 0.25
		"storm":
			wind_speed = 45.0 + wind_roll * 35.0
			rain_intensity = 0.78 + wind_roll * 0.22
			is_storm = true
		"fog":
			wind_speed = 2.0 + wind_roll * 7.0
			is_fog = true
		"snow":
			wind_speed = 10.0 + wind_roll * 18.0
			is_snow = true
	if terrain_id == "forest":
		wind_speed *= 0.72
	elif terrain_id in ["mountain", "rocky_outcrop"]:
		wind_speed *= 1.15
	var night_temperature := temperature - 5.0
	var visibility_multiplier := 1.0
	if is_storm:
		visibility_multiplier = 0.45
	elif is_fog:
		visibility_multiplier = 0.55
	elif rain_intensity >= 0.7 or is_snow:
		visibility_multiplier = 0.72
	return {
		"weather_type": weather_type,
		"weather_label": _weather_label(weather_type),
		"season": season,
		"month_index": month_index,
		"temperature_c": snappedf(temperature, 0.1),
		"night_temperature_c": snappedf(night_temperature, 0.1),
		"wind_speed": snappedf(wind_speed, 0.1),
		"rain_intensity": snappedf(rain_intensity, 0.01),
		"storm": is_storm,
		"heavy_rain": rain_intensity >= 0.7,
		"snow": is_snow,
		"fog": is_fog,
		"visibility_multiplier": visibility_multiplier
	}


func season_for_month(month_index: int) -> String:
	var month := posmod(month_index, 12)
	if month == 11 or month <= 1:
		return "spring"
	if month <= 4:
		return "summer"
	if month <= 7:
		return "autumn"
	return "winter"


func _select_weather(season: String, roll: float) -> String:
	var options: Array[Dictionary] = []
	match season:
		"spring":
			options = [
				{"id": "clear", "weight": 0.40}, {"id": "overcast", "weight": 0.24},
				{"id": "rain", "weight": 0.22}, {"id": "storm", "weight": 0.05},
				{"id": "fog", "weight": 0.09}
			]
		"summer":
			options = [
				{"id": "clear", "weight": 0.54}, {"id": "overcast", "weight": 0.22},
				{"id": "rain", "weight": 0.13}, {"id": "storm", "weight": 0.08},
				{"id": "fog", "weight": 0.03}
			]
		"autumn":
			options = [
				{"id": "clear", "weight": 0.28}, {"id": "overcast", "weight": 0.28},
				{"id": "rain", "weight": 0.28}, {"id": "heavy_rain", "weight": 0.10},
				{"id": "fog", "weight": 0.06}
			]
		_:
			options = [
				{"id": "clear", "weight": 0.28}, {"id": "overcast", "weight": 0.34},
				{"id": "rain", "weight": 0.08}, {"id": "snow", "weight": 0.24},
				{"id": "fog", "weight": 0.06}
			]
	var cumulative := 0.0
	for option in options:
		cumulative += float(option.weight)
		if roll <= cumulative:
			return String(option.id)
	return String(options.back().id)


func _season_temperature(season: String) -> float:
	match season:
		"spring":
			return 12.0
		"summer":
			return 23.0
		"autumn":
			return 13.0
		_:
			return 4.0


func _diurnal_temperature(hour: float) -> float:
	if hour >= 12.0 and hour <= 16.0:
		return 3.0
	if hour >= 0.0 and hour <= 6.0:
		return -4.0
	if hour >= 20.0 or hour < 0.0:
		return -2.0
	return 0.0


func _weather_label(weather_type: String) -> String:
	match weather_type:
		"clear":
			return "Clear"
		"overcast":
			return "Overcast"
		"rain":
			return "Rain"
		"heavy_rain":
			return "Heavy rain"
		"storm":
			return "Storm"
		"fog":
			return "Fog"
		"snow":
			return "Snow"
	return "Clear"


func _stable_roll(day_index: int, period_index: int, channel: int) -> float:
	var value := float(seed) * 12.9898 + float(day_index) * 78.233
	value += float(period_index) * 37.719 + float(channel) * 19.913
	var sample := sin(value) * 43758.5453
	return sample - floorf(sample)


func to_dict() -> Dictionary:
	return {"seed": seed}


func load_dict(data: Dictionary) -> bool:
	var saved_seed := int(data.get("seed", 0))
	if saved_seed <= 0:
		return false
	seed = saved_seed
	current_period_index = -1
	current_conditions.clear()
	return true
