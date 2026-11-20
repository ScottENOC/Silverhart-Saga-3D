class_name CharacterSurfaceRegionMaskLibrary
extends RefCounted
## Loads authored fine-region masks for an exact canonical body asset.

const MASK_DIRECTORY := "res://data/characters/anatomy_masks"


static func load_for_body(body_asset_path: String) -> Array[Resource]:
    var result: Array[Resource] = []
    if body_asset_path.is_empty():
        return result
    var directory := DirAccess.open(MASK_DIRECTORY)
    if directory == null:
        return result
    var filenames: Array[String] = []
    directory.list_dir_begin()
    var filename := directory.get_next()
    while not filename.is_empty():
        if not directory.current_is_dir() and filename.ends_with(".tres"):
            filenames.append(filename)
        filename = directory.get_next()
    directory.list_dir_end()
    filenames.sort()
    for filename in filenames:
        var path := MASK_DIRECTORY.path_join(filename)
        var resource := load(path)
        if resource is CharacterSurfaceRegionMask and resource.body_asset_path == body_asset_path:
            result.append(resource)
    return result
