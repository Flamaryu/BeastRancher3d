extends Node

## Centralized game clock and simulation pacing engine.
## Drives hour and day ticks, supporting dynamic time acceleration and pausing.

const EventBusScript = preload("res://scripts/core/EventBus.gd")

@export var tick_speed_multiplier: float = 1.0
@export var real_seconds_per_game_hour: float = 2.5
@export var hours_per_day: int = 24

var current_hour: int = 0
var current_day: int = 1
var is_paused: bool = false

var _accumulator: float = 0.0

static var instance: Node = null

func _init() -> void:
	if instance == null:
		instance = self

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			instance = null

func _process(delta: float) -> void:
	if is_paused or tick_speed_multiplier <= 0.0:
		return

	_accumulator += delta * tick_speed_multiplier
	while _accumulator >= real_seconds_per_game_hour:
		_accumulator -= real_seconds_per_game_hour
		advance_hour()

## Advances the clock by a single in-game hour, rolling over into days as needed.
func advance_hour() -> void:
	current_hour += 1
	var rolled_over: bool = false

	if current_hour >= hours_per_day:
		current_hour = 0
		current_day += 1
		rolled_over = true

	_notify_hour(current_hour)

	if rolled_over:
		_notify_day(current_day)

## Fast-forwards multiple hours consecutively.
func advance_hours(hours: int) -> void:
	for i in range(maxi(0, hours)):
		advance_hour()

## Advances the clock by a single in-game day (advances through full remaining cycle or 24 hours).
func advance_day() -> void:
	var hours_to_advance: int = hours_per_day - current_hour
	if hours_to_advance == 0:
		hours_to_advance = hours_per_day
	advance_hours(hours_to_advance)

## Simulates multiple full days for fast simulation and testing.
func advance_days(days: int) -> void:
	for i in range(maxi(0, days)):
		advance_day()

## Adjusts the tick speed acceleration multiplier.
func set_tick_speed_multiplier(multiplier: float) -> void:
	tick_speed_multiplier = maxf(0.0, multiplier)
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("tick_speed_changed"):
		bus.tick_speed_changed.emit(tick_speed_multiplier)

## Pauses simulation progression.
func pause() -> void:
	is_paused = true

## Resumes simulation progression.
func resume() -> void:
	is_paused = false

## Resets time counters to initial or specified state.
func reset(day: int = 1, hour: int = 0) -> void:
	current_day = maxi(1, day)
	current_hour = clampi(hour, 0, hours_per_day - 1)
	_accumulator = 0.0

func _notify_hour(hour: int) -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("hour_ticked"):
		bus.hour_ticked.emit(hour)

func _notify_day(day: int) -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("day_ticked"):
		bus.day_ticked.emit(day)

func _get_event_bus() -> Node:
	if is_instance_valid(EventBusScript.instance):
		return EventBusScript.instance
	if is_inside_tree() and has_node("/root/EventBus"):
		return get_node("/root/EventBus")
	return null
