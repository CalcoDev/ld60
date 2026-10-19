class_name MainScreenModule
extends ShipModule

const BOOT_SCREEN := preload(
    "res://Scenes/MainScreen/main_screen_boot_menu.tscn"
)
const IDLE_SCREEN := preload(
    "res://Scenes/MainScreen/main_screen_idle_menu.tscn"
)
const PAUSE_SCREEN := preload(
    "res://Scenes/MainScreen/main_screen_pause_menu.tscn"
)
const MOVEMENT_SCREEN := preload(
    "res://Scenes/MainScreen/main_screen_movement_menu.tscn"
)
const COMMS_SCREEN := preload(
    "res://Scenes/MainScreen/main_screen_comms_menu.tscn"
)

@export_range(0.1, 30.0, 0.1) var boot_duration := 3.0
@export_range(0.1, 5.0, 0.05) var transition_duration := 0.8
@export_range(0.0, 5.0, 0.05) var pause_fade_duration := 0.3

var _last_comms_output := ""
var _boot_complete := false
var _transitioning := false
var _resuming := false
var _current_screen: Control
var _current_screen_scene: PackedScene = BOOT_SCREEN
var _screen_before_pause: PackedScene = IDLE_SCREEN
var _transition_overlay: ColorRect
var _transition_material: ShaderMaterial
var _paused_modulates: Dictionary = {}
var _latest_comms: Dictionary = {}


func _init() -> void:
    module_name = "Main Screen"
    var input_port := add_input_port(&"data")
    add_output_port(&"power")
    input_port.on_connection_changed.connect(_on_screen_connection_changed)


func _ready() -> void:
    super._ready()
    process_mode = Node.PROCESS_MODE_ALWAYS
    _current_screen = get_parent().get_node_or_null(
        "MainScreenBootMenu"
    ) as Control
    if _current_screen == null:
        _replace_screen(BOOT_SCREEN)
    else:
        _connect_screen_signals(_current_screen)
    _transition_overlay = get_parent().get_node(
        "CrtTransition"
    ) as ColorRect
    _transition_material = _transition_overlay.material as ShaderMaterial


func _physics_process(delta: float) -> void:
    if get_tree().paused:
        return
    
    send_data(
        &"power",
        {
            "power": true,
            "delta": delta,
        }
    )


func process_input(_port_name: StringName, data: Dictionary) -> void:
    if not data.get("power", false):
        return
    
    var connected_port := get_input_port(&"data").connected_port
    var connected_module := connected_port.get_parent() as ShipModule
    
    if data.has("comms"):
        _latest_comms = data["comms"].duplicate(true)
        _process_comms(_latest_comms)
        _update_comms_screen()
    
    if connected_module is ThrusterModule or connected_module is RotatorModule:
        _last_comms_output = ""
        if Globals.ship_simulation != null:
            Globals.ship_simulation.set_controls(data)
        if (
            _boot_complete
            and not get_tree().paused
            and _current_screen_scene != MOVEMENT_SCREEN
        ):
            show_screen(MOVEMENT_SCREEN)
    elif (
        connected_module is CommsInModule
        or connected_module is DecoderModule
        or connected_module is TranslatorModule
    ):
        if (
            _boot_complete
            and not get_tree().paused
            and _current_screen_scene != COMMS_SCREEN
        ):
            show_screen(COMMS_SCREEN)


func show_screen(screen_scene: PackedScene) -> void:
    if screen_scene == null or _transitioning:
        return
    
    _transitioning = true
    _transition_overlay.visible = true
    _transition_overlay.move_to_front()
    _set_transition_progress(0.0)
    
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_method(
        _set_transition_progress,
        0.0,
        0.5,
        transition_duration * 0.5
    )
    tween.tween_callback(_replace_screen.bind(screen_scene))
    tween.tween_method(
        _set_transition_progress,
        0.5,
        1.0,
        transition_duration * 0.5
    )
    tween.tween_callback(_finish_transition)


func _on_screen_connection_changed(other_port: ModulePort) -> void:
    if Globals.ship_simulation != null:
        Globals.ship_simulation.clear_controls()
    _latest_comms.clear()
    
    if other_port == null:
        print("showing idle ui")
        if _boot_complete and not get_tree().paused:
            show_screen(IDLE_SCREEN)
        return
    
    var connected_module := other_port.get_parent() as ShipModule
    if connected_module != null:
        print("showing ui for %s" % connected_module.module_name)


func _replace_screen(screen_scene: PackedScene) -> void:
    if _current_screen != null:
        _current_screen.queue_free()
    
    _current_screen = screen_scene.instantiate() as Control
    _current_screen_scene = screen_scene
    if _current_screen is MainScreenCommsMenu:
        (_current_screen as MainScreenCommsMenu).set_comms(_latest_comms)
    get_parent().add_child.call_deferred(_current_screen)
    _connect_screen_signals(_current_screen)
    if _transition_overlay != null:
        _transition_overlay.move_to_front()


func _connect_screen_signals(screen: Control) -> void:
    if screen is MainScreenBootMenu:
        var boot_screen := screen as MainScreenBootMenu
        boot_screen.boot_duration = boot_duration
        boot_screen.boot_finished.connect(_on_boot_finished)
    elif screen is MainScreenIdleMenu:
        (screen as MainScreenIdleMenu).pause_requested.connect(
            _pause_game
        )
    elif screen is MainScreenPauseMenu:
        (screen as MainScreenPauseMenu).resume_requested.connect(
            _resume_game
        )


func _on_boot_finished() -> void:
    _boot_complete = true
    var input_port := get_input_port(&"data")
    _on_screen_connection_changed(input_port.connected_port)


func _pause_game() -> void:
    if _transitioning or get_tree().paused:
        return
    
    _screen_before_pause = _current_screen_scene
    get_tree().paused = true
    _dim_other_modules()
    show_screen(PAUSE_SCREEN)


func _resume_game() -> void:
    if _transitioning or _resuming or not get_tree().paused:
        return
    
    _resuming = true
    show_screen(_screen_before_pause)
    _restore_other_modules()


func _dim_other_modules() -> void:
    _paused_modulates.clear()
    var boxes := get_parent().get_parent()
    for child: Node in boxes.get_children():
        if child is ModuleVisual and child != get_parent():
            _paused_modulates[child] = child.modulate
    
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.set_parallel(true)
    for item: ModuleVisual in _paused_modulates:
        tween.tween_property(
            item,
            "modulate",
            item.unpowered_modulate,
            pause_fade_duration
        )


func _restore_other_modules() -> void:
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.set_parallel(true)
    tween.tween_interval(maxf(transition_duration, pause_fade_duration))
    for item: ModuleVisual in _paused_modulates:
        if is_instance_valid(item):
            tween.tween_property(
                item,
                "modulate",
                _paused_modulates[item],
                pause_fade_duration
            )
    tween.finished.connect(_finish_resume)


func _finish_resume() -> void:
    _paused_modulates.clear()
    _resuming = false
    get_tree().paused = false


func _set_transition_progress(value: float) -> void:
    _transition_material.set_shader_parameter("progress", value)


func _finish_transition() -> void:
    _transition_overlay.visible = false
    _transitioning = false


func _process_comms(comms: Dictionary) -> void:
    if float(comms.get("transmission_progress", 0.0)) < 1.0:
        return
    
    var stage: StringName = comms.get("stage", &"received")
    var output: String = comms.get("display_text", "")
    var printed_output := "[%s] %s" % [stage, output]
    
    if printed_output == _last_comms_output:
        return
    
    _last_comms_output = printed_output
    print(printed_output)


func _update_comms_screen() -> void:
    if _current_screen is MainScreenCommsMenu:
        (_current_screen as MainScreenCommsMenu).set_comms(_latest_comms)
