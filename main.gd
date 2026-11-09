extends Control
const Visuals = preload("res://visuals.gd")
const Stimuli = preload("res://stimuli.gd")
const Targets = preload("res://targets.gd")
const Responses = preload("res://responses.gd")
const Statistics = preload("res://statistics.gd")
const History = preload("res://history.gd")
const Figure = preload("res://figure.gd")
const ErrorFeedback = preload("res://error_feedback.gd")
const MenuAudio = preload("res://menu_audio.gd")

enum Phase { MENU, TRANSITION_DRAWING, TRANSITION, DRAWING, PREVIEW, COUNTDOWN, GAP, STIMULUS, RESULTS, HISTORY }
var stimulus_count := Stimuli.SESSION_COUNT
var presentation_seconds := 1.0
var interval_min := 1.0
var interval_max := 4.0
var phase := Phase.MENU
var deadline_us := 0
var drawing_preview := false
var transition_tween: Tween
var countdown_number := 3
var sequence: Array[Dictionary] = []
var cursor := 0
var current_block := 0
var blocks: Array[Dictionary] = []
var active_targets: Array = []
var rng := RandomNumberGenerator.new()
var responses := Responses.new()
var history := History.new()
var audio := MenuAudio.new()
var latest: Dictionary = {}
var scroll: ScrollContainer
var page_margin: MarginContainer
var title_label: Label
var footer: Label
var content: VBoxContainer
var status: Label
var instructions: Label
var arena: PanelContainer
var figure: Control
var overlay: Label
var progress: ProgressBar
var progress_label: Label
var preview_row: HBoxContainer
var target_previews: Array[Control] = []
var shape_gallery: VBoxContainer
var gallery_grid: GridContainer
var start: Button
var history_button: Button
var back: Button
var abort_button: Button
var mute: Button
var results_panel: PanelContainer
var results_text: Label
var history_panel: VBoxContainer
var notice: Label
var error_feedback: Control

func label(value: String, font_size: int = 18) -> Label:
	var node := Label.new()
	node.text = value
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func button(value: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size.y = 46
	node.pressed.connect(action)
	return node

func panel() -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", Visuals.box("1c2a36", "334657"))
	return node

func _ready() -> void:
	rng.randomize()
	history.load_sessions()
	Visuals.apply(self)
	add_child(audio)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	page_margin = margin
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	scroll.add_child(margin)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 12)
	content.add_child(toolbar)
	var brand := label("ATTENTION • REACTION", 13)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(brand)
	abort_button = button("End test", _abort)
	toolbar.add_child(abort_button)
	mute = button("Mute", _toggle_mute)
	toolbar.add_child(mute)
	title_label = label("Abstract Visual Attention & Reaction", 30)
	content.add_child(title_label)
	status = label("", 14)
	status.add_theme_color_override("font_color", Color("9cb5c9"))
	content.add_child(status)
	instructions = label("")
	content.add_child(instructions)
	progress_label = label("", 14)
	content.add_child(progress_label)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 6
	for key in ["background", "fill"]:
		var bar_style := StyleBoxFlat.new()
		bar_style.bg_color = Color("334657" if key == "background" else "9cb5c9")
		bar_style.set_corner_radius_all(3)
		progress.add_theme_stylebox_override(key, bar_style)
	content.add_child(progress)
	arena = panel()
	arena.custom_minimum_size.y = 280
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(arena)
	figure = Control.new()
	figure.set_script(Figure)
	arena.add_child(figure)
	preview_row = HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 24)
	arena.add_child(preview_row)
	for i in 1:
		var preview := Control.new()
		preview.set_script(Figure)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_row.add_child(preview)
		target_previews.append(preview)
	preview_row.hide()
	overlay = label("Ready", 38)
	arena.add_child(overlay)
	shape_gallery = VBoxContainer.new()
	shape_gallery.add_theme_constant_override("separation", 8)
	content.add_child(shape_gallery)
	shape_gallery.add_child(label("Shapes used in this test", 14))
	gallery_grid = GridContainer.new()
	gallery_grid.columns = 4
	gallery_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gallery_grid.add_theme_constant_override("h_separation", 12)
	gallery_grid.add_theme_constant_override("v_separation", 6)
	shape_gallery.add_child(gallery_grid)
	for shape_name in Targets.SHAPES:
		var thumbnail := Control.new()
		thumbnail.set_script(Figure)
		thumbnail.color_override = Color("e4ebf3")
		thumbnail.custom_minimum_size = Vector2(48, 48)
		gallery_grid.add_child(thumbnail)
		thumbnail.display({"shape": shape_name, "color": 0})
	start = button("Start Game", _start_session)
	content.add_child(start)
	history_button = button("Session history", _show_history)
	content.add_child(history_button)
	back = button("Back to instructions", _back)
	content.add_child(back)
	results_panel = panel()
	results_text = label("", 18)
	results_panel.add_child(results_text)
	content.add_child(results_panel)
	content.move_child(results_panel, start.get_index())
	history_panel = VBoxContainer.new()
	history_panel.add_theme_constant_override("separation", 12)
	content.add_child(history_panel)
	notice = label("", 14)
	content.add_child(notice)
	footer = label("Local & offline • Cognitive practice, not a medical diagnosis or standardized clinical assessment.", 13)
	content.add_child(footer)
	error_feedback = Control.new()
	error_feedback.set_script(ErrorFeedback)
	add_child(error_feedback)
	resized.connect(_responsive)
	_menu()

func _menu(message: String = "") -> void:
	phase = Phase.MENU
	error_feedback.clear()
	shape_gallery.show()
	_reset_transition_visual()
	notice.show()
	_responsive()
	figure.display({})
	preview_row.hide()
	overlay.text = "Ready"
	arena.hide()
	instructions.text = "Memorize the abstract shape and its color. Click anywhere when both match; ignore other figures.\nA new target appears every 10 stimuli: announcement, 3-second preview, then 3–2–1.\n40 stimuli · 1 second each · random 1–4 second gaps."
	status.text = "40 STIMULI · 4 BLOCKS · ABSTRACT SHAPES"
	notice.text = history.error
	start.show()
	start.text = "Start Game"
	history_button.show()
	back.hide()
	abort_button.hide()
	progress.hide()
	progress_label.hide()
	results_panel.hide()
	history_panel.hide()
	if not message.is_empty(): notice.text = message
	scroll.scroll_vertical = 0

func is_testing() -> bool:
	return phase in [Phase.TRANSITION_DRAWING, Phase.TRANSITION, Phase.DRAWING, Phase.PREVIEW, Phase.COUNTDOWN, Phase.GAP, Phase.STIMULUS]

func _start_session() -> void:
	shape_gallery.hide()
	audio.start_session()
	stimulus_count = Stimuli.SESSION_COUNT
	error_feedback.clear()
	responses = Responses.new()
	responses.error_occurred.connect(_show_error_feedback)
	blocks = Stimuli.generate_session(rng, interval_min, interval_max)
	sequence.clear()
	for block in blocks: sequence.append_array(block.stimuli)
	cursor = 0
	current_block = 0
	start.hide()
	history_button.hide()
	back.hide()
	results_panel.hide()
	history_panel.hide()
	abort_button.show()
	progress.show()
	progress_label.show()
	progress.max_value = stimulus_count
	progress.value = 0
	progress_label.text = "0 / %d stimuli" % stimulus_count
	notice.text = "Click anywhere except the menu controls. Only the first response to each figure counts."
	overlay.text = ""
	arena.show()
	scroll.scroll_vertical = 0
	get_viewport().gui_release_focus()
	_start_block()
	notice.hide()
	_responsive()

func _update_block_label() -> void:
	progress_label.text = "Block %d/4 · %d/%d stimuli" % [current_block + 1, cursor, stimulus_count]

func _start_block() -> void:
	current_block = int(cursor / float(Stimuli.BLOCK_SIZE))
	active_targets = blocks[current_block].targets
	_update_block_label()
	if current_block > 0: _show_target_change()
	else: _show_target_preview()

func _reset_transition_visual() -> void:
	if transition_tween != null:
		transition_tween.kill()
		transition_tween = null
	if overlay != null: overlay.modulate = Color.WHITE

func _show_target_change() -> void:
	_reset_transition_visual()
	figure.display({})
	preview_row.hide()
	for preview in target_previews: preview.display({})
	overlay.text = "NEW TARGET"
	overlay.modulate = Color("a8c8df")
	overlay.modulate.a = 0.65
	status.text = "TARGET CHANGE"
	instructions.text = "The next block uses a new target."
	phase = Phase.TRANSITION_DRAWING
	_arm_render_callback()

func _show_target_preview() -> void:
	_reset_transition_visual()
	status.text = "LEARN TARGET"
	instructions.text = "Memorize this shape and color."
	figure.display({})
	overlay.text = ""
	preview_row.show()
	for i in target_previews.size():
		target_previews[i].visible = i < active_targets.size()
		target_previews[i].display(active_targets[i] if i < active_targets.size() else {})
	phase = Phase.DRAWING
	drawing_preview = true
	_arm_render_callback()

func _show_figure(item: Dictionary) -> void:
	# A new figure never inherits an interval error indicator.
	error_feedback.clear()
	phase = Phase.DRAWING
	drawing_preview = false
	preview_row.hide()
	figure.display(item)
	_arm_render_callback()

func _arm_render_callback() -> void:
	# Arm only after a rendered frame, rather than before queue_redraw().
	# Headless automated flow tests call this hook explicitly.
	if not RenderingServer.frame_post_draw.is_connected(_on_frame_presented):
		RenderingServer.frame_post_draw.connect(_on_frame_presented, CONNECT_ONE_SHOT)

func _on_frame_presented() -> void:
	if phase == Phase.TRANSITION_DRAWING:
		phase = Phase.TRANSITION
		deadline_us = Time.get_ticks_usec() + 1500000
		transition_tween = create_tween()
		transition_tween.tween_property(overlay, "modulate:a", 1.0, 0.18)
		return
	if phase != Phase.DRAWING: return
	var now := Time.get_ticks_usec()
	if drawing_preview:
		phase = Phase.PREVIEW
		deadline_us = now + 3000000
	else:
		responses.begin(sequence[cursor], now, presentation_seconds, active_targets)
		phase = Phase.STIMULUS
		deadline_us = responses.deadline_us

func _show_error_feedback(_kind: String) -> void:
	_position_error_feedback()
	error_feedback.flash(Time.get_ticks_usec())

func _position_error_feedback() -> void:
	var bounds := arena.get_global_rect()
	var viewport_size := get_viewport_rect().size
	error_feedback.position = Vector2(
		clampf(bounds.end.x - 32.0, 4.0, viewport_size.x - 28.0),
		clampf(bounds.position.y + 8.0, 4.0, viewport_size.y - 28.0))

func _process(_delta: float) -> void:
	if error_feedback.visible and arena.is_visible_in_tree(): _position_error_feedback()
	_advance(Time.get_ticks_usec())

func _advance(now: int) -> void:
	if now < deadline_us: return
	match phase:
		Phase.TRANSITION:
			_show_target_preview()
		Phase.PREVIEW:
			figure.display({})
			preview_row.hide()
			phase = Phase.COUNTDOWN
			countdown_number = 3
			overlay.text = "3"
			status.text = "GET READY"
			instructions.text = "Click only for the target shape and color."
			deadline_us = now + 1000000
		Phase.COUNTDOWN:
			countdown_number -= 1
			if countdown_number > 0:
				overlay.text = str(countdown_number)
				deadline_us = now + 1000000
			else:
				overlay.text = ""
				status.text = "TEST IN PROGRESS"
				_begin_gap(now)
		Phase.GAP:
			progress_label.text = "Block %d/4 · %d/%d stimuli" % [current_block + 1, cursor + 1, stimulus_count]
			_show_figure(sequence[cursor])
		Phase.STIMULUS:
			responses.finish()
			cursor += 1
			progress.value = cursor
			figure.display({})
			if cursor == sequence.size(): _complete()
			elif cursor % Stimuli.BLOCK_SIZE == 0: _start_block()
			else:
				_update_block_label()
				_begin_gap(now)

func _begin_gap(now: int) -> void:
	phase = Phase.GAP
	deadline_us = now + roundi(float(sequence[cursor].gap) * 1000000.0)

func _input(event: InputEvent) -> void:
	if not is_testing(): return
	var point: Vector2
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	else: return
	if not get_viewport_rect().has_point(point): return
	for control in [mute, abort_button, scroll.get_v_scroll_bar(), scroll.get_h_scroll_bar()]:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return
	if phase not in [Phase.STIMULUS, Phase.GAP]:
		get_viewport().set_input_as_handled()
		return
	var now := Time.get_ticks_usec()
	# Expire the response window before accepting input even on a slow frame.
	# A boundary click belongs to the following gap, never the old stimulus.
	_advance(now)
	if phase == Phase.STIMULUS: responses.respond(now)
	elif phase == Phase.GAP: responses.respond(now, true)
	get_viewport().set_input_as_handled()

func _complete() -> void:
	phase = Phase.RESULTS
	audio.complete_session()
	notice.show()
	_responsive()
	latest = Statistics.calculate(responses.trials, responses.premature)
	latest["presentation_seconds"] = presentation_seconds
	latest["interval_min"] = interval_min
	latest["interval_max"] = interval_max
	history.record(latest)
	arena.hide()
	abort_button.hide()
	progress.hide()
	progress_label.hide()
	status.text = "SESSION COMPLETE"
	instructions.text = "Lower reaction times are better only when accuracy remains high.\nReaction times use correct target responses."
	results_text.text = format_results(latest)
	results_panel.show()
	start.text = "Repeat test"
	start.show()
	history_button.show()
	back.show()
	notice.text = "Accuracy = (hits + correct rejections) / all stimuli.\nPremature clicks are recorded separately. Reaction times use hits only."
	if not history.error.is_empty(): notice.text += "\n" + history.error
	scroll.scroll_vertical = 0

static func ms(value: Variant) -> String:
	return "—" if value == null else "%.1f ms" % float(value)

static func format_results(r: Dictionary) -> String:
	return ("ACCURACY  %.1f%%\n\n" % float(r.accuracy)
		+ "Stimuli  %d     •     Targets  %d\n" % [int(r.total), int(r.targets)]
		+ "Hits  %d     •     Omissions  %d\n" % [int(r.hits), int(r.omissions)]
		+ "False alarms  %d     •     Correct rejections  %d\n" % [int(r.false_alarms), int(r.correct_rejections)]
		+ "Premature responses  %d\n\n" % int(r.premature)
		+ "Mean  %s     •     Median  %s\n" % [ms(r.mean_ms), ms(r.median_ms)]
		+ "Fastest  %s     •     Slowest  %s" % [ms(r.fastest_ms), ms(r.slowest_ms)]
		+ ("\nNo valid target responses; reaction times are unavailable." if r.mean_ms == null else ""))

func _show_history() -> void:
	audio.click()
	phase = Phase.HISTORY
	shape_gallery.hide()
	notice.show()
	_responsive()
	arena.hide()
	results_panel.hide()
	start.hide()
	history_button.hide()
	abort_button.hide()
	progress.hide()
	progress_label.hide()
	back.show()
	status.text = "LAST 10 COMPLETED SESSIONS"
	instructions.text = "Your last 10 completed sessions.\nNewest first; dates use local time."
	history_panel.show()
	_render_history()
	notice.text = history.error + "\nSaved on this device only. No personal data is uploaded."
	scroll.scroll_vertical = 0

func _render_history() -> void:
	for child in history_panel.get_children():
		history_panel.remove_child(child)
		child.queue_free()
	var entries := history.entries
	if entries.is_empty(): history_panel.add_child(label("No completed sessions yet."))
	for entry in entries:
		var card := panel()
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 12)
		card.add_child(body)
		body.add_child(label(str(entry.date), 16))
		if entry.has_all(["presentation_seconds", "interval_min", "interval_max"]):
			body.add_child(label("%.1f s visible · %.2f–%.2f s gaps" % [float(entry.presentation_seconds), float(entry.interval_min), float(entry.interval_max)], 13))
		body.add_child(label(format_results(entry), 16))
		history_panel.add_child(card)

func _back() -> void:
	audio.click()
	_menu()

func _abort(play_sound: bool = true) -> void:
	if not is_testing(): return
	responses.active = false
	_menu("Test ended. Incomplete sessions are not saved. Start again when ready.")
	if play_sound: audio.click()

func _toggle_mute() -> void:
	audio.toggle()
	mute.text = "Unmute" if audio.muted else "Mute"
	# Remain silent throughout preparation and testing, including UI actions.
	if not is_testing() and not audio.muted: audio.click()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_testing():
		_abort(false)
		notice.text = "Test ended because the app lost focus. Start again when ready; incomplete sessions are not saved."

func _responsive() -> void:
	if page_margin == null: return
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 600 or viewport_size.y < 700
	for side in ["left", "right", "top", "bottom"]:
		page_margin.add_theme_constant_override("margin_" + side, 16 if compact else 24)
	content.add_theme_constant_override("separation", 12 if compact else 16)
	title_label.add_theme_font_size_override("font_size", 26 if compact else 30)
	title_label.visible = not (compact and is_testing())
	for thumbnail in gallery_grid.get_children():
		thumbnail.custom_minimum_size = Vector2.ONE * (40 if compact else 48)
	footer.visible = not is_testing()
	arena.custom_minimum_size.y = clampf(viewport_size.y * 0.35, 140, 280) if is_testing() else 120.0
