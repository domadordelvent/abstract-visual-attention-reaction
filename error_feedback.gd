extends Control
## Presentation-only clock. Never changes a trial, response or phase deadline.
const DURATION_US := 400000
const INK := Color("eb7373")
var until_us := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(24, 24)
	size = Vector2(24, 24)
	z_index = 10
	hide()

func flash(now_us: int) -> void:
	# Repeated errors renew one indicator; no queued flashes or delayed callbacks.
	until_us = now_us + DURATION_US
	show()
	queue_redraw()

func clear() -> void:
	until_us = 0
	hide()

func advance(now_us: int) -> void:
	if visible and now_us >= until_us: clear()

func _process(_delta: float) -> void:
	advance(Time.get_ticks_usec())

func _draw() -> void:
	draw_line(Vector2(6, 6), Vector2(18, 18), INK, 3.0, true)
	draw_line(Vector2(18, 6), Vector2(6, 18), INK, 3.0, true)
