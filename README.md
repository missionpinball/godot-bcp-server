# Godot BCP Server

![Godot BCP Logo](https://github.com/missionpinball/godot-bcp-server/blob/main/icon.png?raw=true)

The Godot BCP Server is a plugin for connecting Godot to the Mission Pinball Framework (MPF) using the Backbox Control Protocol (BCP).

With this plugin, pinball creators using MPF can choose Godot as their display engine and drive all screen slides, videos, animations, and sounds via a Godot project.

## Features
* Direct socket connection between MPF and Godot for high-speed synchronization
* Fully extensible base classes allow customization and overrides
* Direct access to player variables, machine variables, and settings
* Built-in signals for core events, extensible to add any signals you need
* Easily subscribe to MPF events and send events to MPF
* Support for keyboard input bindings to aid in development

## Installation

Create a new Godot project and find Godot BCP Server in the Asset Library. Add this plugin to your project and save.

_Note: Godot BCP Server uses custom class names for extending support to your project. It is recommended to exit and restart Godot after adding the plugin, to ensure that the class names are recognized and available._


# Usage

Godot BCP Server provides base classes for two Autoload instances: **BCPServer** for the socket connection to MPF, and **MPFGame** for game, player, machine, and setting values.

## BCPServer Class
_This class manages the connection to MPF and all data coming in and out. For optimal performance, it runs
in a separate thread from the main Godot instance._

Create a new autoload script (e.g. _/autoloads/server.gd_) and add `extends BCPServer` to the top of the file. You can then set class variables and override
class methods. In your Project Settings > AutoLoad, add your script as an autoload with the name "Server".

**Note:** The Game autoload script (see MPFGame below) must be listed _before_ the Server autoload
script, because the Server is dependent on the Game.

### Method `_init() -> void`
The init method allows you to configure the base setup of the server. There are
two properties you can set here.

#### self.auto_signals
The `auto_signals` property is a list of MPF events that have Godot signals of the
same name. This is a very fast and easy way to setup signals if you want to
re-broadcast an MPF event to listeners in Godot.

```
extends BCPServer


signal bonus(payload)
signal hurryup_started(payload)
signal options(payload)

func _init() -> void:
  self.auto_signals = ['options', 'bonus', 'hurryup_started']
```

#### self.registered_events
The `registered_events` property is a list of MPF events that Godot should
subscribe to. By default only the basic player, mode, and game events are sent
via BCP. With `registered` events you can specify any events you want to receive.

```
func _init() -> void:
  self.registered_events = [
      "jackpot_lit",
      "jackpot_collected",
      "mystery_lit",
      "skillshot_hit",
      "timer_boss_mode_tick",
  ]
```

### Method `listen() -> void:`
At some point in your game's startup sequence you need to call `Server.listen()`
on your server to open a port and begin listening for an MPF connection. The name
of the server instance will be based on your autoload's name.

`listen()` should be called from your active scene when the Godot MC is ready to
connect to MPF, or in your main scene's `_ready()` method if you want to connect
immediately.

### Method `on_message(message):`
The on_method event allows you to define custom callback methods for events
received by MPF. This list is evaluated before the default event handlers, and
if this method returns a falsey value the default behavior will be skipped.
Return the original message to proceed to the default handlers.

_Note: The BCP Server runs on a separate thread, so all callbacks should be
wrapped in `call_deferred(method_name, *args)` to ensure that the callback
is thread-safe (i.e. handled on the main thread)._

```
func on_message(message):
  match message.cmd:
    "high_score_enter_initials":
      call_deferred("deferred_scene", "res://modes/HighScore.tscn")
    "quest_shot_jackpot":
      call_deferred("emit_signal", "popup", message)
    _:
      return message
```

### Method `on_mode_start(mode_name: String) -> void:`
The on_mode_start method is called whenever a mode starts in MPF. This is the
place where you can load scenes, play music, or do any other mode-specific behavior.

```
func on_mode_start(mode_name: String) -> void:
  if mode_name.substr(0,6) == "quest_":
    self._deferred_scene_top(self._next_quest)
    return

  if mode_name.substr(0,7) == "threat_":
    call_deferred("start_threat", mode_name)
    return

  match mode_name:
    "attract":
      self.deferred_scene("res://modes/AttractMode.tscn")
    "bonus":
      self.deferred_scene("res://modes/BonusMode.tscn")
    "game":
      MusicPlayer.play_sfx("game_started.wav")
```

### Other Overridable Methods
There are other methods that can be defined in server for custom behavior.

```

func on_ball_start() -> void:
  # Called when a player's ball starts
  pass

func on_ball_end() -> void:
  # Called when a player's ball ends
  pass

func on_connect() -> void:
  # Called when a BCP connection is established with MPF
  pass

func on_disconnect() -> void:
  # Called when the BCP connection to MPF is ended
  pass

func on_input(event_payload: PoolStringArray) -> void:
  # Called when an input event key is pressed
  pass
```

### Built-In Methods
There are some built-in methods that are convenient.

#### self.send_event(event_name: String) -> void:
You can call `self.send_event` to send an event to MPF!

#### self.deferred_game(method: String, result=null) -> void:
You can call `self.deferred_game` to schedule a method to be called in the Game
autoload singleton. This is a thread-safe way to trigger game callbacks from events.

#### self.deferred_game_player(result) -> void:
You can call `self.deferred_game_player` to schedule an update to a player variable
using the properties `result.name` and `result.value`.

#### self.deferred_scene(scene_res: String) -> void:
You can call `self.deferred_scene` to change the main scene tree to the resource
path specified (i.e. call `get_tree().change_scene(scene_res)` on the main thread).

#### self.deferred_scene_to(scene_pck: Resource) -> void:
You can call `self.deferred_scene_to` to change the main scene tree to the resource
pack specified (i.e. call `get_tree().change_scene_to(scene_pck)` on the main thread).


## MPFGame Class
_The Game class provides access to player variables, machine variables, settings, and active modes._

Create a new autoload script (e.g. _/autoloads/game.gd_) and add `tool` and
`extends MPFGame` to the top of the file. You can customize the class variables
and override class methods as described below. In your Project Settings > AutoLoad add your script with the name "Game".

**Note:** The Game autoload script must be listed _before_ the Server autoload
script (see BCPServer above), because the Server is dependent on the Game.

### Method `_init() -> void:`
You can initialize anything you need here.

#### self.player
The MPFGame class will automatically create player objects to mirror MPF, but one
helpful approach is to mock out a player object so that you can run scenes in Godot
without starting an MPF game. This can save time when you need to quickly debug things.

#### self.auto_signal_vars
You can specify certain player variables to have corresponding `signal` events so
that whenever the player variable changes, a signal with the same name is broadcast
in Godot.

```
tool
extends MPFGame


signal atomic_blaster(payload)
signal extra_balls

func _init()
  self.auto_signal_vars = ['atomic_blaster', 'extra_balls']
```

### Property `Game.player` and `Game.players`
The Game autoload has a `self.player` property that is a dictionary with all the
values of the current player. The `self.players` property is an array with all
the players of the current game.

Because the Game is an autoload, you can access the player variables anywhere in
your codebase, e.g. `Game.player.score`.

### Property `Game.machine_vars` and `Game.settings`
The Game autoload has `self.machine_vars` and `self.settings` properties which are
dictionaries with all the values of the MPF machine and settings values.

### Property `Game.active_modes`
The Game autoload has `self.active_modes` which is a list of the names of all of
the currently active modes that MPF is running.

### Signal `player_update(variable_name: String, value)`
The Game has a signal `player_update` that will emit whenever a player variable
changes value. You can subscribe to player changes anywhere in your Godot project
using this signal.

```
# Any scene in your game, e.g. ShipBattle
Game.connect("player_update", self, "_on_player_update")

func _on_player_update(variable_name: String, value):
  if variable_name == "ships_destroyed":
    self.destroy_ship(value)
```

### Signal `player_added`
The Game has a signal `player_added` that will emit whenever a new player is
added to the game.

### Signal `credits`
The Game has a signal `credits` that will emit whenever the machine's credits
change.

### Method `comma_sep(value: int) -> String`
The Game class has a static method to format integers as strings with comma-separation
at every thousand. Just pass in a number and get a string back!

```
Game.comma_sep(5432198)
# returns "5,432,198"
```

### Method `pluralize(template: String, value: int) -> String`
The Game class has a static method to return a string with an optional `"s"` character
added based on whether a value is not equal to the integer `1`.

```
Game.pluralize("New Reward%s Available", 2)
# returns "New Rewards Available"
Game.pluralize("New Mission%s Unlocked", 1)
# returns "New Mission Unlocked"
```

Note that you can include both the value and the pluralization in one call, but
you must escape the pluralization template string by using `%%s`.

```
Game.pluralize("%s Hit%%s Remaining", 5)
# returns "5 Hits Remaining"
Game.pluralize("Hit %s Target%%s to Complete", 1)
# returns "Hit 1 Target to Complete"
```


## Log Autoload
_The Log autoload scripts provides a convenient, MPF-style logging interface with
matching levels and output formatting._

### Option 1: No Logging
You can choose not to incorporate the included log script in your project. The
BCP Server module requires logging, so it will instantiate its own logger instance.

### Option 2: Autoload Logging
In your Godot project settings, you can include _addons/godot_bcp_server/log.gd_
to gain access to a global Log instance with methods for logging to the console
and files.

The default levels are VERBOSE (0), DEBUG (10), INFO (20), and WARN (30). Messages
at the error and fail level will always be logged. You can specify the level
at any time by calling the `setLevel` method. By default, the log logs at level INFO.

```
Log.setLevel(10)
```

Like MPF, the logger uses levels to determine the output. It includes methods
`verbose`, `debug`, `info`, `warn`, `error`, and `fail`, each accepting parameters for
the message and values. It is recommended to pass the message string and values
separately rather than combining the string when you call it—this way, calls
below the output level won't waste time on the string formatting.

```
Log.info("Player var %s updated, new value %s", [var_name, value])
```

### Option 3: Extend a Custom Log

If you prefer to customize your logger, you can implement your own script with
`extends Logger`. Any of the above methods can be overridden, and you can also
change the output of the log messages by overriding the log output method.

```
func log(level_name: String, message: String, args=null) -> void:
  print(...)  # Output whatever string you like
```

To enable global access to your custom logger, save your script and add it to
your project as an autoload. If your autoload has the global variable name `Log`,
the BCP Server will detect and use your logger instead of the built-in one.

If you do not wish to name your autoload `Log`, you can still instruct the BCP
Server to use it by assigning your logger as `self.logger` in your custom Server
class `_init()` method.

# Contributing

User contributions are welcome!

https://github.com/missionpinball/godot-bcp-server

For questions and support, please open an issue in the above GitHub repository or visit the MPF forums at https://groups.google.com/g/mpf-users

## License
[MIT](https://choosealicense.com/licenses/mit/)