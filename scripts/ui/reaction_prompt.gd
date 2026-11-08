extends CanvasLayer
## Modal reaction chooser shared by combat and movement reactions.
## The simulation owns eligibility, TP costs and outcomes; this node only
## presents the supplied options and returns the selected option ID.

signal choice_selected(choice_id: String, request_id: int)

var _request_id: int = 0
var _root: Control
var _buttons: Array[Button] = []

func _ready() -> void:
    layer = 150
    _root = Control.new()
    _root.name = "ReactionOverlay"
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.visible = false
    add_child(_root)

func present(reactor_id: String, options: Array[Dictionary], request_id: int) -> void:
    _request_id = request_id
    _buttons.clear()
    for child in _root.get_children():
        child.queue_free()

    var backdrop := ColorRect.new()
    backdrop.color = Color(0.015, 0.02, 0.03, 0.72)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.add_child(backdrop)

    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.add_child(centre)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(360.0, 0.0)
    centre.add_child(panel)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 10)
    panel.add_child(stack)

    var heading := Label.new()
    heading.text = "REACTION"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 22)
    stack.add_child(heading)

    var description := Label.new()
    description.text = "%s must respond." % reactor_id
    description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(description)

    for option in options:
        var option_id := String(option.get("id", ""))
        if option_id.is_empty():
            continue
        var cost := float(option.get("tp_cost", option.get("tpCost", 0.0)))
        var button := Button.new()
        button.text = "%s  ·  %g TP" % [String(option.get("name", option_id)), cost]
        button.custom_minimum_size = Vector2(320.0, 46.0)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_choose.bind(option_id))
        stack.add_child(button)
        _buttons.append(button)

    var decline := Button.new()
    decline.text = "Decline reaction"
    decline.custom_minimum_size = Vector2(320.0, 42.0)
    decline.pressed.connect(_choose.bind(""))
    stack.add_child(decline)
    _buttons.append(decline)

    _root.visible = true
    if not _buttons.is_empty():
        _buttons[0].grab_focus()

func _choose(choice_id: String) -> void:
    if not _root.visible:
        return
    for button in _buttons:
        button.disabled = true
    _root.visible = false
    choice_selected.emit(choice_id, _request_id)

func dismiss() -> void:
    _root.visible = false
    for button in _buttons:
        button.disabled = true
