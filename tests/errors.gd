extends SceneTree
const Responses = preload("res://responses.gd")
const Statistics = preload("res://statistics.gd")
var checks := 0
var failures := 0
var errors: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func prepare(game: Control) -> void:
	if game.phase == game.Phase.TRANSITION_DRAWING:
		game._on_frame_presented()
		game._advance(game.deadline_us)
	game._on_frame_presented()
	game._advance(game.deadline_us)
	for i in 3: game._advance(game.deadline_us)
	check(game.phase == game.Phase.GAP, "Preparation continues automatically")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	var path := "/tmp/abstract-errors-%d.json" % OS.get_process_id()
	game.history.path = path
	root.add_child(game)
	game.set_process(false)
	game.error_feedback.set_process(false)
	game.audio.muted = true
	game.rng.seed = 321
	await process_frame
	check(game.error_feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE and game.error_feedback.focus_mode == Control.FOCUS_NONE, "Indicator cannot capture input or focus")
	check(not game.error_feedback.visible, "Menu has no error feedback")
	game._start_session()
	game.responses.error_occurred.connect(func(kind: String): errors.append(kind))
	prepare(game)
	var reference := Responses.new()
	var interval_deadline: int = game.deadline_us
	game.responses.respond(Time.get_ticks_usec(), true)
	reference.respond(Time.get_ticks_usec(), true)
	check(game.error_feedback.visible and errors == ["premature"], "Premature response triggers feedback")
	check(game.deadline_us == interval_deadline and game.responses.premature == 1, "Premature feedback preserves gap and count")
	var first_expiry: int = game.error_feedback.until_us
	check(first_expiry - Time.get_ticks_usec() > 390000 and first_expiry - Time.get_ticks_usec() <= 400000, "Feedback lasts 400 milliseconds")
	game.error_feedback.advance(first_expiry - 1)
	check(game.error_feedback.visible, "Feedback does not expire early")
	game.error_feedback.advance(first_expiry)
	check(not game.error_feedback.visible and game.deadline_us == interval_deadline, "Expiry leaves stimulus deadline unchanged")
	game.responses.respond(Time.get_ticks_usec(), true)
	reference.respond(Time.get_ticks_usec(), true)
	var previous_expiry: int = game.error_feedback.until_us
	game.error_feedback.flash(previous_expiry - 200000)
	check(game.error_feedback.until_us == previous_expiry + 200000, "Repeated error renews one indicator")
	game.error_feedback.advance(previous_expiry)
	check(game.error_feedback.visible, "Old expiry cannot hide renewed feedback")
	for i in 40:
		# Exercise an omission on the final stimulus as well as block boundaries.
		if i == 39: game.sequence[i] = game.active_targets[0].duplicate()
		game._advance(game.deadline_us)
		check(not game.error_feedback.visible, "New stimulus clears interval feedback")
		game._on_frame_presented()
		var onset: int = game.responses.onset_us
		var deadline: int = game.deadline_us
		var count_before := errors.size()
		var target: bool = game.responses.current.target
		reference.begin(game.sequence[i], onset, game.presentation_seconds, game.active_targets)
		var respond: bool = i != 39 and ((target and i % 3 != 0) or (not target and i % 2 == 0))
		if respond:
			game.responses.respond(onset + 250123)
			reference.respond(onset + 250123)
			check(game.error_feedback.visible == (not target), "Only false alarms flash; correct hits stay clean")
			check(errors.size() == count_before + (0 if target else 1), "Exactly one error signal for first response")
			var feedback_deadline: int = game.error_feedback.until_us
			game.responses.respond(onset + 350456)
			reference.respond(onset + 350456)
			check(game.error_feedback.until_us == feedback_deadline, "Duplicate response cannot renew feedback")
			check(game.deadline_us == deadline and game.responses.deadline_us == deadline and game.responses.onset_us == onset, "Feedback never alters stimulus or reaction clocks")
			if target: check(is_equal_approx(game.responses.current.rt_ms, 250.123), "Exact first-response RT preserved")
		# Simulate independent feedback expiry before the stimulus deadline.
		game.error_feedback.advance(game.error_feedback.until_us)
		game._advance(deadline)
		reference.finish()
		check(game.error_feedback.visible == (target and not respond), "Omission flashes at disappearance; correct rejection stays clean")
		check(game.responses.trials == reference.trials, "Feedback leaves every trial identical to reference scoring")
		if i < 39:
			if (i+1) % 10 == 0: prepare(game)
			else: check(game.phase == game.Phase.GAP and game.deadline_us > deadline, "Session advances without waiting for feedback")
			game.error_feedback.advance(game.error_feedback.until_us)
	check(game.phase == game.Phase.RESULTS and game.latest.total == 40, "Mixed-error session completes automatically")
	check(game.error_feedback.visible, "Final omission remains visible after results appear")
	var expected := Statistics.calculate(reference.trials, reference.premature)
	for key in expected: check(game.latest[key] == expected[key], "Unchanged statistic: " + key)
	check(errors.count("false_alarm") == game.latest.false_alarms and errors.count("omission") == game.latest.omissions and errors.count("premature") == game.latest.premature, "All three feedback event counts match statistics")
	check(game.history.entries.size() == 1, "Only one completed session saved")
	game.error_feedback.advance(game.error_feedback.until_us)
	check(not game.error_feedback.visible, "Final error expires normally")
	game._start_session()
	game.responses.respond(Time.get_ticks_usec(), true)
	game._abort(false)
	check(not game.error_feedback.visible and game.error_feedback.until_us == 0, "Abort clears all feedback")
	game._start_session()
	check(not game.error_feedback.visible and game.responses.premature == 0, "Restart starts clean")
	game._abort(false)
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Error feedback: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
