extends Control
const Stimuli = preload("res://stimuli.gd")
const Shapes = preload("res://abstract_shapes.gd")
var item: Dictionary = {}
## Optional neutral ink for the menu gallery; gameplay uses the stimulus palette.
var color_override := Color.TRANSPARENT

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func display(value: Dictionary) -> void:
	item = value.duplicate()
	queue_redraw()

func _draw() -> void:
	if item.is_empty(): return
	var radius := minf(111.0, minf(size.x, size.y) * 0.45)
	var points := Shapes.vertices(Stimuli.SHAPES.find(item.shape))
	for i in points.size(): points[i] = size / 2.0 + points[i] * radius
	draw_colored_polygon(points, color_override if color_override.a > 0.0 else Stimuli.COLORS[item.color])
