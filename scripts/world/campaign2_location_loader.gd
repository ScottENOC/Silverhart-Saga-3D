class_name Campaign2LocationLoader
extends RefCounted
## Instantiates authored location components from data.
## Component scripts and roles are supplied by location definitions, not WorldRoot.

static func load_location(
	parent: Node,
	definition: Dictionary,
	simulation: WorldSimulation,
	profile: Dictionary,
	save_data: Dictionary
) -> Dictionary:
	if parent == null or definition.is_empty() or simulation == null:
		return {"ok": false, "reason": "invalid_parent_location_or_simulation"}
	var components: Variant = definition.get("components", [])
	if not components is Array or components.is_empty():
		return {"ok": false, "reason": "location_has_no_components"}
	var roles: Dictionary = {}
	for component in components:
		if not component is Dictionary:
			return {"ok": false, "reason": "invalid_location_component"}
		var script: Variant = component.get("script")
		var role := String(component.get("role", "")).strip_edges()
		var node_name := String(component.get("node_name", "")).strip_edges()
		if not script is Script or role.is_empty() or node_name.is_empty():
			return {"ok": false, "reason": "component_missing_script_role_or_name"}
		if not script.can_instantiate():
			return {"ok": false, "reason": "component_script_cannot_be_instantiated"}
		if roles.has(role):
			return {"ok": false, "reason": "duplicate_component_role_%s" % role}
		roles[role] = true

	var staged_nodes: Array[Node] = []
	var instances: Dictionary = {}
	for component in components:
		var role := String(component["role"])
		var node := (component["script"] as Script).new() as Node
		if node == null:
			for staged in staged_nodes:
				staged.free()
			return {"ok": false, "reason": "component_is_not_a_node_%s" % role}
		node.name = String(component["node_name"])
		if bool(component.get("configure_location", false)):
			if not node.has_method("configure_location"):
				node.free()
				for staged in staged_nodes:
					staged.free()
				return {"ok": false, "reason": "component_missing_location_configuration_%s" % role}
			var location_data: Variant = component.get("location_data", {})
			if not location_data is Dictionary:
				node.free()
				for staged in staged_nodes:
					staged.free()
				return {"ok": false, "reason": "invalid_location_component_data_%s" % role}
			node.call("configure_location", location_data)
		if bool(component.get("configure_campaign", false)):
			if not node.has_method("configure_campaign"):
				node.free()
				for staged in staged_nodes:
					staged.free()
				return {"ok": false, "reason": "component_missing_campaign_configuration_%s" % role}
			node.call("configure_campaign", simulation, profile, save_data)
		staged_nodes.append(node)
		instances[role] = node

	for node in staged_nodes:
		parent.add_child(node)
	return {
		"ok": true,
		"location_id": String(definition.get("id", "")),
		"components": instances
	}

## Load a multi-story site from the source-authored floor registry. The returned
## runtime can be parented alongside the active regional presentation; the host
## is responsible for placing its root at the site's world anchor.
static func load_multistory_location(
	parent: Node,
	location_id: String,
	simulation: WorldSimulation,
	save_data: Dictionary = {}
) -> Dictionary:
	if parent == null or simulation == null or location_id.strip_edges().is_empty():
		return {"ok": false, "reason": "invalid_parent_simulation_or_location_id"}
	var registry := Campaign2MultiStoryLocationRegistry.new()
	if not registry.validation_errors.is_empty():
		return {"ok": false, "reason": "invalid_multistory_registry", "errors": registry.validation_errors.duplicate()}
	var definition := registry.get_definition(location_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_multistory_location", "location_id": location_id}
	var runtime := Campaign2MultiStoryLocationRuntime.new()
	runtime.name = "MultiStory_" + location_id
	runtime.configure_location(definition)
	runtime.configure_campaign(simulation, {}, save_data)
	if runtime.location_state == null:
		runtime.free()
		return {"ok": false, "reason": "could_not_configure_multistory_runtime"}
	parent.add_child(runtime)
	return {"ok": true, "location_id": location_id, "runtime": runtime}
