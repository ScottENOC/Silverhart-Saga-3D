class_name SimulationActionRequest
extends RefCounted

enum ActionType { MOVE, ATTACK, FEINT, CAST_SPELL }

var action_type: int
var actor_id: String
var target_id: String = ""
var destination: Vector2i = Vector2i.ZERO
var time_point_cost: float = 0.0
var options: Dictionary = {}

func _init(requested_type: int, requested_actor_id: String, requested_target_id: String = "", requested_destination: Vector2i = Vector2i.ZERO, requested_cost: float = 0.0, requested_options: Dictionary = {}) -> void:
	action_type = requested_type
	actor_id = requested_actor_id
	target_id = requested_target_id
	destination = requested_destination
	time_point_cost = requested_cost
	options = requested_options.duplicate(true)

static func move(actor_id: String, destination: Vector2i, time_point_cost: float) -> SimulationActionRequest:
	return SimulationActionRequest.new(ActionType.MOVE, actor_id, "", destination, time_point_cost)

static func attack(actor_id: String, target_id: String, options: Dictionary = {}) -> SimulationActionRequest:
	return SimulationActionRequest.new(ActionType.ATTACK, actor_id, target_id, Vector2i.ZERO, 0.0, options)

static func feint(actor_id: String, target_id: String) -> SimulationActionRequest:
	return SimulationActionRequest.new(ActionType.FEINT, actor_id, target_id, Vector2i.ZERO, 1.0, {"is_feint": true})

static func cast_spell(actor_id: String, target_id: String, prepared_spell: PreparedSpell) -> SimulationActionRequest:
	if prepared_spell == null:
		return null
	return SimulationActionRequest.new(
		ActionType.CAST_SPELL,
		actor_id,
		target_id,
		Vector2i.ZERO,
		0.0,
		{"prepared_spell": prepared_spell.to_dict()}
	)

static func cast_spell_at_hex(actor_id: String, target_hex: Vector2i, prepared_spell: PreparedSpell, target_id: String = "") -> SimulationActionRequest:
	if prepared_spell == null:
		return null
	return SimulationActionRequest.new(
		ActionType.CAST_SPELL,
		actor_id,
		target_id,
		target_hex,
		0.0,
		{"prepared_spell": prepared_spell.to_dict(), "target_hex": {"q": target_hex.x, "r": target_hex.y}}
	)
