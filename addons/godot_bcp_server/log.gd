# Godot BCP Server
# For use with the Mission Pinball Framework https://missionpinball.org
# Original code © 2021 Anthony van Winkle / Paradigm Tilt
# Released under the MIT License

# Add this file as an Autoload in your Godot project for MPF-style logging.
# Override the log() method to change the output formatting.

extends Node

var VERBOSE := 0
var DEBUG := 10
var INFO := 20
var WARN := 30

var _level: int = INFO

func setLevel(level: int) -> void:
  _level = level

func verbose(message: String, args=null) -> void:
  if _level <= VERBOSE:
    self.log("VERBOSE", message, args)

func debug(message: String, args=null) -> void:
  if _level <= DEBUG:
    self.log("DEBUG", message, args)

func info(message: String, args=null) -> void:
  if _level <= INFO:
    self.log("INFO", message, args)

func warn(message: String, args=null) -> void:
  if _level <= WARN:
    self.log("WARN", message, args)

func error(message: String, args=null) -> void:
  self.log("ERROR", message, args)

func fail(message: String, args=null) -> void:
  self.error(message, args)
  assert(false, message % args)

func log(level: String, message: String, args=null) -> void:
  # TODO: Incorporate ProjectSettings.get_setting("logging/file_logging/enable_file_logging")
  # Get datetime to dictionary
  var dt=OS.get_datetime()
  # Format and print with message
  print("[%s] %02d:%02d:%02d " % [level, dt.hour,dt.minute,dt.second], message if args == null else (message % args))
