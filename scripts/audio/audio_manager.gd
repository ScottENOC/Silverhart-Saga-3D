extends Node
const BUS_NAMES := ["Master", "Music", "Dialogue", "SFX", "Ambience", "UI"]
const SETTINGS_PATH := "user://audio_settings.cfg"
var _music: AudioStreamPlayer
var _dialogue: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _tween: Tween
var _levels := {"Master": 1.0, "Music": 0.75, "Dialogue": 1.0, "SFX": 0.85, "Ambience": 0.8, "UI": 0.8}
var current_mode := "menu"

func _ready() -> void:
    _ensure_buses()
    _load_settings()
    _music = _make_player("MusicPlayer", "Music")
    _dialogue = _make_player("DialoguePlayer", "Dialogue")
    _ui = _make_player("UIPlayer", "UI")
    _ambience = _make_player("AmbiencePlayer", "Ambience")
    for i in range(8):
        _sfx.append(_make_player("SFX_%d" % i, "SFX"))
    apply_settings()

func _ensure_buses() -> void:
    for name in BUS_NAMES:
        if AudioServer.get_bus_index(name) == -1:
            AudioServer.add_bus()
            var index := AudioServer.bus_count - 1
            AudioServer.set_bus_name(index, name)
            AudioServer.set_bus_send(index, "Master" if name != "Master" else "")

func _make_player(player_name: String, bus_name: String) -> AudioStreamPlayer:
    var player := AudioStreamPlayer.new()
    player.name = player_name
    player.bus = bus_name
    add_child(player)
    return player

func _load_settings() -> void:
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) != OK:
        return
    for name in BUS_NAMES:
        _levels[name] = clampf(float(config.get_value("audio", name, _levels[name])), 0.0, 1.0)

func save_settings() -> void:
    var config := ConfigFile.new()
    for name in BUS_NAMES:
        config.set_value("audio", name, _levels[name])
    config.save(SETTINGS_PATH)

func set_bus_level(name: String, value: float) -> void:
    if not BUS_NAMES.has(name): return
    _levels[name] = clampf(value, 0.0, 1.0)
    _apply_bus(name)
    save_settings()

func get_bus_level(name: String) -> float:
    return float(_levels.get(name, 1.0))

func apply_settings() -> void:
    for name in BUS_NAMES: _apply_bus(name)

func _apply_bus(name: String) -> void:
    var index := AudioServer.get_bus_index(name)
    if index < 0: return
    var level: float = _levels[name]
    AudioServer.set_bus_mute(index, level <= 0.001)
    AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))

func play_music(path: String, fade := 1.0, loop := true) -> void:
    if not ResourceLoader.exists(path):
        push_warning("Music asset not imported yet: " + path)
        return
    var stream := load(path) as AudioStream
    if stream == null: return
    if _music.stream == stream and _music.playing: return
    if _tween and _tween.is_running(): _tween.kill()
    _music.stream = stream
    if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = loop
    if stream is AudioStreamMP3: (stream as AudioStreamMP3).loop = loop
    _music.volume_db = -36.0
    _music.play()
    _tween = create_tween()
    _tween.tween_property(_music, "volume_db", 0.0, maxf(0.05, fade))

func stop_music(fade := 0.8) -> void:
    if not is_instance_valid(_music) or not _music.playing: return
    if _tween and _tween.is_running(): _tween.kill()
    _tween = create_tween()
    _tween.tween_property(_music, "volume_db", -40.0, maxf(0.05, fade))
    _tween.tween_callback(_music.stop)

func play_dialogue(path: String) -> void: _play_one_shot(_dialogue, path)
func play_ui(path: String) -> void: _play_one_shot(_ui, path)

func play_sfx(path: String) -> void:
    if not ResourceLoader.exists(path): return
    for player in _sfx:
        if not player.playing:
            _play_one_shot(player, path)
            return
    _play_one_shot(_sfx[0], path)

func _play_one_shot(player: AudioStreamPlayer, path: String) -> void:
    if not ResourceLoader.exists(path):
        push_warning("Audio asset not imported yet: " + path)
        return
    var stream := load(path) as AudioStream
    if stream == null: return
    player.stream = stream
    player.play()

func enter_mode(mode: String) -> void:
    current_mode = mode
    match mode:
        "arena": play_music("res://audio/legacy/arena_lobby.ogg", 1.2, true)
        "campaign": stop_music(1.0)
        _: play_music("res://audio/legacy/title.ogg", 1.0, true)

const ARENA_MUSIC := {
    "lobby": "res://audio/legacy/arena_lobby.ogg",
    "pre_battle": "res://audio/legacy/arena_pre_battle.ogg",
    "battle": "res://audio/legacy/arena_battle.ogg",
    "death": "res://audio/legacy/arena_death.ogg"
}
const ARENA_DIALOGUE := [
    "arena_entrance", "arena_fight_mid", "arena_fight_start", "arena_indoor",
    "arena_lobby_1", "arena_lobby_2", "arena_lobby_3", "arena_lobby_4",
    "arena_outdoor_day", "arena_outdoor_night", "arena_victory"
]
const CAMPAIGN_DIALOGUE := ["goblin_1_enemy_seen", "grishnak_entry", "pc_1_enemy_seen"]

func play_arena_music(track_name: String, fade := 0.8) -> void:
    if current_mode != "arena" or not ARENA_MUSIC.has(track_name):
        return
    play_music(ARENA_MUSIC[track_name], fade, track_name != "death")

func play_arena_transition() -> void:
    if current_mode != "arena": return
    play_sfx("res://audio/legacy/arena_transition.ogg")

func play_arena_sting(kind := "battle") -> void:
    if current_mode != "arena": return
    var path := "res://audio/legacy/arena_battle_sting.ogg"
    if kind == "death": path = "res://audio/legacy/arena_death_sting.ogg"
    play_sfx(path)

func play_arena_dialogue(key: String) -> void:
    if current_mode != "arena" or not ARENA_DIALOGUE.has(key): return
    play_dialogue("res://audio/legacy/dialogue/" + key + ".ogg")

func play_campaign_dialogue(key: String) -> void:
    if current_mode != "campaign" or not CAMPAIGN_DIALOGUE.has(key): return
    play_dialogue("res://audio/legacy/dialogue/" + key + ".ogg")

func play_parry() -> void:
    if current_mode == "arena" or current_mode == "campaign":
        play_sfx("res://audio/legacy/effects/parry.ogg")

func play_ambience(path: String, loop := true) -> void:
    if not ResourceLoader.exists(path): return
    var stream := load(path) as AudioStream
    if stream == null: return
    _ambience.stream = stream
    if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = loop
    if stream is AudioStreamMP3: (stream as AudioStreamMP3).loop = loop
    _ambience.play()

func stop_ambience() -> void:
    _ambience.stop()

func play_3d(path: String, world_position: Vector3, bus := "SFX", max_distance := 24.0) -> void:
    if not ResourceLoader.exists(path): return
    var stream := load(path) as AudioStream
    if stream == null: return
    var player := AudioStreamPlayer3D.new()
    player.stream = stream
    player.bus = bus
    player.max_distance = max_distance
    var scene := get_tree().current_scene
    if scene == null: return
    scene.add_child(player)
    player.global_position = world_position
    player.finished.connect(player.queue_free)
    player.play()

func play_dialogue_3d(path: String, world_position: Vector3, max_distance := 18.0) -> void:
    play_3d(path, world_position, "Dialogue", max_distance)
