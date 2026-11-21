class_name CharacterGarmentCoverageDefinition
extends Resource
## A garment's semantic coverage contract, separate from anatomy and mesh construction.
##
## coverage_parts is an Array[Dictionary]. Each entry contains:
## {
##   "part_id": String,
##   "region_ids": PackedStringArray,
##   "fit_mode": "drape" | "clearance" | "compression" | "support",
##   "normal_offset_m": float,
##   "clearance_m": float,
##   "compression": float [0, 1],
##   "support": float [0, 1]
## }
##
## Region channels may overlap. A panel's coverage is the union of its selected
## channels, never a partition that leaves ambiguous boundary vertices uncovered.

const REGION_MASK_SCRIPT = preload("res://scripts/characters/character_surface_region_mask.gd")
const FIT_MODES := ["drape", "clearance", "compression", "support"]

@export var garment_id: String = ""
@export var body_asset_path: String = ""
@export var coverage_parts: Array[Dictionary] = []


func validate_definition() -> String:
    if garment_id.strip_edges().is_empty():
        return "Garment coverage needs a stable garment_id"
    if body_asset_path.strip_edges().is_empty():
        return "Garment coverage must target an exact body asset path"
    if coverage_parts.is_empty():
        return "Garment coverage needs at least one named coverage part"
    var seen_parts := {}
    for part_index in range(coverage_parts.size()):
        var part: Dictionary = coverage_parts[part_index]
        var part_id := String(part.get("part_id", "")).strip_edges()
        if part_id.is_empty():
            return "Coverage part %d needs a part_id" % part_index
        if seen_parts.has(part_id):
            return "Duplicate coverage part_id: %s" % part_id
        seen_parts[part_id] = true
        var regions: Variant = part.get("region_ids")
        if not regions is PackedStringArray or regions.is_empty():
            return "Coverage part %s needs PackedStringArray region_ids" % part_id
        var seen_regions := {}
        for region_id in regions:
            if not REGION_MASK_SCRIPT.REGION_IDS.has(region_id):
                return "Coverage part %s references unknown anatomical region %s" % [part_id, region_id]
            if seen_regions.has(region_id):
                return "Coverage part %s repeats anatomical region %s" % [part_id, region_id]
            seen_regions[region_id] = true
        var fit_mode := String(part.get("fit_mode", "clearance"))
        if not FIT_MODES.has(fit_mode):
            return "Coverage part %s has unsupported fit_mode %s" % [part_id, fit_mode]
        for numeric_key in ["normal_offset_m", "clearance_m", "compression", "support"]:
            var value: Variant = part.get(numeric_key, 0.0)
            if not (value is float or value is int) or not is_finite(float(value)):
                return "Coverage part %s has invalid %s" % [part_id, numeric_key]
            if numeric_key in ["compression", "support"] and (float(value) < 0.0 or float(value) > 1.0):
                return "Coverage part %s %s must be between 0 and 1" % [part_id, numeric_key]
            if numeric_key in ["normal_offset_m", "clearance_m"] and float(value) < 0.0:
                return "Coverage part %s %s cannot be negative" % [part_id, numeric_key]
    return ""


## Validates that every requested anatomical channel has actually been authored
## on this exact character. It deliberately refuses to substitute rig weights.
func validate_for_character(surface_regions: CharacterSurfaceRegions) -> String:
    var definition_error := validate_definition()
    if not definition_error.is_empty():
        return definition_error
    if surface_regions == null or not surface_regions.is_configured():
        return "A configured CharacterSurfaceRegions instance is required"
    for part in coverage_parts:
        var part_id := String(part["part_id"])
        for region_id in part["region_ids"]:
            if not surface_regions.has_authored_region(region_id):
                return "Coverage part %s requires authored anatomy region %s on %s" % [
                    part_id, region_id, body_asset_path
                ]
    return ""


func get_part_region_union(surface_regions: CharacterSurfaceRegions, part_id: String) -> Array[Dictionary]:
    if not validate_for_character(surface_regions).is_empty():
        return []
    for part in coverage_parts:
        if String(part["part_id"]) == part_id:
            return surface_regions.get_authored_region_union_samples(part["region_ids"], 0.25, 0)
    return []
