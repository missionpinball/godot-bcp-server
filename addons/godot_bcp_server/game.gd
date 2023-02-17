# Godot BCP Server
# For use with the Mission Pinball Framework https://missionpinball.org
# Original code © 2021 Anthony van Winkle / Paradigm Tilt
# Released under the MIT License


extends Node
class_name MPFGame

# The list of modes currently active in MPF
var active_modes := []
# The full list of audit values
var audits := {}
# A list of player variables that are their own signal names
var auto_signal_vars := []
# All of the machine variables
var machine_vars := {}
# The number of players in the game
var num_players: int = 0
# The current player
var player: Dictionary = {}
# All of the players in the current game
var players := []
# A lookup for preloaded scenes
var preloaded_scenes: Dictionary
# Some scenes should always be preloaded
var persisted_scenes := []
# All of the machine settings
var settings: Dictionary = {}


signal player_update(variable_name, value)
signal player_added
signal credits
signal volume(track, value, change)


func _init() -> void:
  randomize()


func add_player(kwargs: Dictionary) -> void:
  players.append({
    "score": 0,
    "number": kwargs.player_num
  })
  num_players = players.size()
  emit_signal("player_added")

# Called with a dynamic path value, must use load()
func preload_scene(path: String, delay_secs: int = 0, persist: bool = false) -> void:
  if not preloaded_scenes.has(path):
    if delay_secs:
      await get_tree().create_timer(delay_secs).timeout
    preloaded_scenes[path] = load(path)
    if persist and not path in persisted_scenes:
      persisted_scenes.push_back(path)

# Called with a fixed value, can use preload()
func stash_preloaded_scene(path: String, scene: PackedScene):
  preloaded_scenes[path] = scene

func reset() -> void:
  players = []
  player = {}

func retrieve_preloaded_scene(path: String) -> PackedScene:
  var scene: PackedScene
  if preloaded_scenes.has(path):
    scene = preloaded_scenes[path]
  else:
    Log.warn("Preloaded scene MISS %s", path)
    scene = load(path)
  # Clear the reference to the scene so it can be garbage collected after the scene is done
  if not path in persisted_scenes:
    preloaded_scenes.erase(path)
  return scene


func start_player_turn(kwargs: Dictionary) -> void:
  # Player nums are 1-based, so subtract 1
  player = players[kwargs.player_num - 1]


func update_machine(kwargs: Dictionary) -> void:
  print("UPDATE MACHINE with kwargs: %s" % kwargs)
  var name = kwargs.get("name")
  var value = kwargs.get("value")
  if value is String:
    value = value.uri_decode()
  if name.begins_with("audit"):
    audits[name] = value
  else:
    machine_vars[name] = value
    if name.begins_with("credits"):
      emit_signal("credits", name, value)
    elif name.ends_with("_volume"):
      emit_signal("volume", name, value, kwargs.get("change", 0))
  # If this machine var is a setting, update the value of the setting
  if settings.has(name):
    settings[name].value = value

func update_modes(kwargs: Dictionary) -> void:
  active_modes = []
  while kwargs.get("running_modes"):
    active_modes.push_back(kwargs["running_modes"].pop_back()[0])


func update_player(kwargs: Dictionary) -> void:
  var target_player: Dictionary = players[kwargs.player_num - 1]
  # Ignore the initial values
  if not target_player.has(kwargs.name):
    target_player[kwargs.name] = kwargs.value
  else:
    target_player[kwargs.name] = kwargs.value
    if player == target_player:
      # Support specific events for designated listeners
      if kwargs.name in auto_signal_vars:
        emit_signal(kwargs.name, kwargs.value)
      # Also broadcast the general update for all subscribers
      emit_signal("player_update", kwargs.name, kwargs.value)


func update_settings(result: Dictionary) -> void:
  # TODO: Determine if settings changes are individual or the whole package
  settings = {}
  for option in result.get("settings", []):
    var s := {}
    # [name, label, sort, machine_var, default, values, settingType ]
    s.label = option[1]
    s.priority = option[2]
    s.variable = option[3]
    s.default = option[4]
    s.type = option[6]
    s.options = {}
    # By default, store the setting as the default value
    s.value = s.default
    # The default interpretation uses strings as keys, convert to ints
    for key in option[5].keys():
      s.options[int(key)] = option[5][key]
    # The default brightness settings include percent signs, update them for string printing
    if s.label == "brightness":
      for key in s.options.keys():
        s.options[key] = s.options[key].replace("%", "%%")
    settings[option[0]] = s


## Receive an integer value and return a comma-separated string
static func comma_sep(n: int) -> String:
  var result := ""
  var i: int = int(abs(n))

  while i > 999:
    result = ",%03d%s" % [i % 1000, result]
    i /= 1000

  return "%s%s%s" % ["-" if n < 0 else "", i, result]


## Receive a string template and an integer, return the string
## formatted with an "s" if the number is anything other than 1
static func pluralize(template: String, val: int) -> String:
  return template % ("" if val == 1 else "s")
