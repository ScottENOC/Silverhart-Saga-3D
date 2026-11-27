extends SceneTree

const PRESENTER = preload("res://scripts/presentation/campaign_ambient_dialogue_presenter.gd")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_duration_calculation()
	var presenter := PRESENTER.new()
	var actor := Node3D.new()
	root.add_child(presenter)
	root.add_child(actor)
	_test_rejected_inputs(presenter, actor)
	await _test_actor_attached_real_time_bubble(presenter, actor)
	actor.queue_free()
	presenter.queue_free()
	await process_frame
	if _failures > 0:
		push_error("%d ambient dialogue presenter assertion(s) failed." % _failures)
		quit(1)
		return
	print("Campaign ambient dialogue presenter tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _test_duration_calculation() -> void:
	_check(is_equal_approx(PRESENTER.duration_for_text("Hi."), 2.0), "Short lines use the minimum readable duration")
	_check(PRESENTER.duration_for_text("A much longer line of dialogue that needs time to read.") > 2.0)
	_check(is_equal_approx(PRESENTER.duration_for_text("x".repeat(400)), 7.0), "Long lines are capped")


func _test_rejected_inputs(presenter: CampaignAmbientDialoguePresenter, actor: Node3D) -> void:
	_check(not bool(presenter.present_line(null, "Hello").get("ok", true)), "A speaker actor is mandatory")
	_check(not bool(presenter.present_line(actor, "   ").get("ok", true)), "Empty ambient text is rejected")
	_check(not bool(presenter.present_line(actor, "Hello", 0.0).get("ok", true)), "A zero-duration bubble is rejected")
	var detached := Node3D.new()
	_check(String(presenter.present_line(detached, "Hello").get("reason", "")) == "speaker_actor_not_in_scene_tree")
	detached.free()


func _test_actor_attached_real_time_bubble(presenter: CampaignAmbientDialoguePresenter, actor: Node3D) -> void:
	var result := presenter.present_line(actor, "The road is clear.", 0.15, 2.4)
	_check(bool(result.get("ok", false)), "A valid ambient line should be presented")
	var bubble: Label3D = result.get("bubble") as Label3D
	_check(bubble != null and is_instance_valid(bubble))
	if bubble == null:
		return
	_check(bubble.get_parent() == actor, "Ambient speech must be attached to its speaker")
	_check(bubble.is_in_group("campaign_ambient_dialogue_bubble"))
	_check(bubble.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	_check(is_equal_approx(bubble.position.y, 2.4))
	var expiry := bubble.get_node_or_null("RealTimeExpiry") as Timer
	_check(expiry != null, "Every bubble owns its expiry timer")
	if expiry == null:
		return
	_check(expiry.one_shot)
	_check(expiry.ignore_time_scale, "Ambient text must expire in real time, independent of game time scale")
	await create_timer(0.25).timeout
	await process_frame
	_check(not is_instance_valid(bubble), "The bubble should remove itself when its real-time timer expires")
