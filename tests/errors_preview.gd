extends SceneTree
var checks := 0
var failures := 0
var game: Control
var sounds: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame

func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await frame()

func show_item(item: Dictionary) -> void:
	game.sequence[game.cursor] = item
	game._show_figure(item)
	await frame()
	check(game.phase == game.Phase.STIMULUS, "Actual renderer arms stimulus")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	var path := "/tmp/abstract-feedback-render-%d.json" % OS.get_process_id()
	game.history.path = path
	root.add_child(game)
	game.set_process(false)
	root.grab_focus()
	await create_timer(.2).timeout
	game.audio.muted = true
	game._start_session()
	game.audio.sound_started.connect(func(kind: String): sounds.append(kind))
	var target: Dictionary = game.active_targets[0]
	var distractor := target.duplicate()
	distractor.color = (int(target.color)+1)%4
	await show_item(distractor)
	var deadline: int = game.deadline_us
	await click(game.arena.get_global_rect().get_center())
	check(game.error_feedback.visible and game.responses.current.responded and not game.responses.current.target, "Actual distractor click triggers feedback")
	check(game.deadline_us == deadline, "False-alarm input keeps deadline")
	var feedback_expiry: int = game.error_feedback.until_us
	await click(game.error_feedback.get_global_rect().get_center())
	check(game.error_feedback.until_us == feedback_expiry, "Visible indicator does not swallow or duplicate stimulus response")
	await create_timer(.42).timeout
	check(not game.error_feedback.visible, "Real process clock expires feedback in about 400 ms")
	game._advance(game.deadline_us)
	check(game.phase == game.Phase.GAP, "False-alarm trial progresses automatically")
	for dimensions in [Vector2i(360,480), Vector2i(800,900), Vector2i(1280,720)]:
		root.size = dimensions
		await frame()
		var premature_before: int = game.responses.premature
		var gap_deadline: int = game.deadline_us
		await click(Vector2(8,8))
		check(game.error_feedback.visible and game.responses.premature == premature_before+1, "Real gap input triggers feedback")
		check(game.deadline_us == gap_deadline, "Premature input keeps gap deadline")
		var bounds: Rect2 = game.error_feedback.get_global_rect()
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(bounds), "Indicator fits resized viewport")
		check(game.arena.get_global_rect().encloses(bounds), "Indicator remains at arena corner")
		var pixels := root.get_texture().get_image()
		var filled := 0
		for y in range(int(bounds.position.y), int(bounds.end.y)):
			for x in range(int(bounds.position.x), int(bounds.end.x)):
				var color := pixels.get_pixel(x,y)
				if color.r > .65 and color.r > color.g*1.4 and color.r > color.b*1.4: filled += 1
		check(filled > 25 and filled < 200, "Small red X renders at every window size")
		pixels.save_png("/tmp/abstract-error-%d-%d.png" % [dimensions.x, dimensions.y])
		await click(game.error_feedback.get_global_rect().get_center())
		check(game.responses.premature == premature_before+2, "Input through visible indicator remains accepted")
	await show_item(target)
	check(not game.error_feedback.visible, "New target stimulus clears old gap indicator")
	await click(game.arena.get_global_rect().get_center())
	check(game.responses.current.responded and game.responses.current.rt_ms >= 0 and not game.error_feedback.visible, "Actual correct response has RT and no error feedback")
	game._advance(game.deadline_us)
	await show_item(target)
	game._advance(game.deadline_us)
	await frame()
	check(game.error_feedback.visible and game.phase == game.Phase.GAP, "Omission feedback renders while next gap runs")
	check(sounds.is_empty(), "All error feedback and responses are silent")
	game._abort(false)
	check(not game.error_feedback.visible, "End test clears indicator")
	game.queue_free()
	await frame()
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Rendered error feedback: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
