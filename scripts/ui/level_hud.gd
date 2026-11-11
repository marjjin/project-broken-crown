class_name LevelHud
extends CanvasLayer
## Exploration UI: the contextual interaction prompt and a banner for
## GameSession notifications (checkpoints, pickups, inscriptions, level end).
## Entirely signal-driven.

const MIN_BANNER_TIME := 2.5
const SECONDS_PER_CHARACTER := 0.05
const FADE_TIME := 0.5

@export var interactor: PlayerInteractor
@export var prompt_label: Label
@export var banner: Control
@export var banner_title: Label
@export var banner_body: Label

var _banner_tween: Tween


func _ready() -> void:
	if prompt_label == null or banner == null or banner_title == null or banner_body == null:
		push_error("LevelHud: widget references are not assigned; HUD disabled.")
		return
	prompt_label.visible = false
	banner.modulate.a = 0.0
	if interactor != null:
		interactor.focus_changed.connect(_on_focus_changed)
	else:
		push_warning("LevelHud: no PlayerInteractor assigned; prompts will not show.")
	GameSessionState.instance().notification_requested.connect(show_banner)


func show_banner(title: String, body: String = "") -> void:
	banner_title.text = title
	banner_body.text = body
	banner_body.visible = not body.is_empty()
	if _banner_tween != null:
		_banner_tween.kill()
	banner.modulate.a = 1.0
	var hold := maxf(MIN_BANNER_TIME, (title.length() + body.length()) * SECONDS_PER_CHARACTER)
	_banner_tween = create_tween()
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, FADE_TIME)


func _on_focus_changed(target: Interactable) -> void:
	prompt_label.visible = target != null
	if target != null:
		prompt_label.text = "[E]  %s" % target.prompt
