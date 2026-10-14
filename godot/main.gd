extends Node3D

# Starter 3D scene: geometry is generated in-engine, so no unlicensed assets are needed.
const ROAD_WIDTH := 14.0
const LANE_WIDTH := 3.5
const ROAD_LENGTH := 180.0
const PLAYER_Z := 5.0
const MAX_SPEED := 48.0
const MIN_SPEED := 8.0

var speed := 26.0
var distance := 0.0
var coins := 0
var steering := 0.0
var gas_pressed := false
var brake_pressed := false
var crashed := false
var paused := false
var tilt_mode := false
var traffic: Array[Node3D] = []
var coin_nodes: Array[Node3D] = []
var road_marks: Array[MeshInstance3D] = []
var hud: Label
var speed_label: Label
var coin_label: Label
var message_label: Label
var gas_button: Button
var brake_button: Button
var left_button: Button
var right_button: Button
var pause_button: Button
var player: Node3D
var camera: Camera3D
var spawn_timer := 0.0
var coin_timer := 0.0
var touch_steer := 0.0
var menu_active := true
var menu_panel: Control
var control_mode_button: Button
var car_color_button: Button
var selected_car_color := Color(0.08, 0.32, 0.95)
var car_color_index := 0
var car_colors: Array[Color] = [Color(0.08, 0.32, 0.95), Color(0.82, 0.08, 0.06), Color(0.86, 0.88, 0.90)]
var car_names: Array[String] = ["SPORT BLUE", "MUSTANG RED", "BMW WHITE"]
var pause_panel: Control
var crash_panel: Control

func _ready() -> void:
    _make_world()
    _make_road()
    player = _make_car(selected_car_color, true)
    player.position = Vector3(0, 0.0, PLAYER_Z)
    add_child(player)
    _make_camera()
    _make_ui()
    _make_menu()
    for i in range(5):
        _spawn_traffic(-25.0 - float(i) * 24.0)
    set_process(true)

func _make_world() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_SKY
    e.sky = Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.12, 0.42, 0.76)
    sky_mat.sky_horizon_color = Color(0.65, 0.82, 0.92)
    sky_mat.ground_bottom_color = Color(0.12, 0.22, 0.12)
    sky_mat.ground_horizon_color = Color(0.28, 0.42, 0.25)
    e.sky.sky_material = sky_mat
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.7, 0.76, 0.85)
    e.ambient_light_energy = 0.8
    env.environment = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -25, 0)
    sun.light_energy = 1.4
    add_child(sun)
    var ground := _box(Vector3(250, 0.3, 260), Color(0.17, 0.42, 0.20))
    ground.position = Vector3(0, -0.35, -65)
    add_child(ground)

func _make_road() -> void:
    var road := _box(Vector3(ROAD_WIDTH, 0.18, ROAD_LENGTH), Color(0.12, 0.13, 0.15))
    road.position = Vector3(0, -0.12, -70)
    add_child(road)
    for side in [-1.0, 1.0]:
        var edge := _box(Vector3(0.22, 0.08, ROAD_LENGTH), Color(0.92, 0.92, 0.88))
        edge.position = Vector3(side * ROAD_WIDTH * 0.47, 0.0, -70)
        add_child(edge)
        var rail := _box(Vector3(0.16, 0.65, ROAD_LENGTH), Color(0.58, 0.62, 0.65))
        rail.position = Vector3(side * (ROAD_WIDTH * 0.5 + 0.8), 0.45, -70)
        add_child(rail)
    for lane in [-1.0, 1.0]:
        for i in range(24):
            var mark := _box(Vector3(0.10, 0.025, 3.0), Color(0.92, 0.92, 0.86))
            mark.position = Vector3(lane * LANE_WIDTH, 0.015, 12.0 - float(i) * 7.5)
            add_child(mark)
            road_marks.append(mark)
    var center := _box(Vector3(0.13, 0.03, ROAD_LENGTH), Color(0.98, 0.75, 0.12))
    center.position = Vector3(0, 0.02, -70)
    add_child(center)
    # Simple low-poly roadside trees create real depth/parallax in the 3D camera.
    for i in range(26):
        var z := 10.0 - float(i) * 7.0
        for side in [-1.0, 1.0]:
            var trunk := _box(Vector3(0.45, 2.2, 0.45), Color(0.30, 0.19, 0.10))
            trunk.position = Vector3(side * 10.0, 1.0, z)
            add_child(trunk)
            var foliage := MeshInstance3D.new()
            var cone := CylinderMesh.new()
            cone.top_radius = 0.0
            cone.bottom_radius = 1.5
            cone.height = 3.2
            foliage.mesh = cone
            foliage.material_override = _mat(Color(0.10, 0.34 + float(i % 3) * 0.04, 0.16))
            foliage.position = Vector3(side * 10.0, 3.6, z)
            add_child(foliage)

    # Add distant low-poly buildings and lit windows for a fuller roadside scene.
    var building_colors: Array[Color] = [Color(0.68, 0.70, 0.73), Color(0.78, 0.65, 0.48), Color(0.46, 0.55, 0.62)]
    for i in range(10):
        var building_z := 2.0 - float(i) * 22.0
        for side in [-1.0, 1.0]:
            var h := 4.5 + float(i % 3) * 1.8
            var building := _box(Vector3(3.8, h, 4.8), building_colors[i % building_colors.size()])
            building.position = Vector3(side * (17.0 + float(i % 2) * 2.0), h * 0.5 - 0.1, building_z)
            add_child(building)
            for floor_index in range(2):
                for window_side in [-1.0, 1.0]:
                    var window := _box(Vector3(0.62, 0.72, 0.06), Color(0.22, 0.48, 0.66))
                    window.position = Vector3(building.position.x + window_side * 0.9, 1.0 + float(floor_index) * 1.35, building_z - 2.44)
                    add_child(window)


func _make_car(color: Color, is_player: bool) -> Node3D:
    var root := Node3D.new()
    var body := _box(Vector3(1.72, 0.42, 3.25), color)
    body.position.y = 0.59
    root.add_child(body)
    var lower_skirt := _box(Vector3(1.78, 0.16, 2.55), color.darkened(0.22))
    lower_skirt.position = Vector3(0, 0.38, 0.02)
    root.add_child(lower_skirt)
    var grille := _box(Vector3(0.62, 0.15, 0.035), Color(0.018, 0.022, 0.025))
    grille.position = Vector3(0, 0.49, -1.66)
    root.add_child(grille)
    for x in [-0.64, 0.64]:
        var intake := _box(Vector3(0.30, 0.19, 0.04), Color(0.025, 0.03, 0.035))
        intake.position = Vector3(x, 0.46, -1.65)
        root.add_child(intake)
    var hood := _box(Vector3(1.42, 0.22, 0.95), color.lightened(0.12))
    hood.position = Vector3(0, 0.84, -0.82)
    root.add_child(hood)
    var roof := _box(Vector3(1.10, 0.43, 1.30), Color(0.055, 0.085, 0.10))
    roof.position = Vector3(0, 1.04, 0.18)
    root.add_child(roof)
    var rear_glass := _box(Vector3(0.92, 0.25, 0.06), Color(0.20, 0.36, 0.42))
    rear_glass.position = Vector3(0, 1.08, 0.86)
    rear_glass.rotation.x = deg_to_rad(18)
    root.add_child(rear_glass)
    for x in [-0.98, 0.98]:
        var mirror := _box(Vector3(0.25, 0.13, 0.18), color)
        mirror.position = Vector3(x * 1.08, 0.91, -0.45)
        root.add_child(mirror)
    var spoiler := _box(Vector3(1.55, 0.08, 0.26), color.darkened(0.05))
    spoiler.position = Vector3(0, 1.03, 1.42)
    root.add_child(spoiler)
    var windshield := _box(Vector3(0.95, 0.30, 0.07), Color(0.30, 0.55, 0.67))
    windshield.position = Vector3(0, 1.12, -0.48)
    windshield.rotation.x = deg_to_rad(-20)
    root.add_child(windshield)
    for x in [-0.86, 0.86]:
        for z in [-1.02, 1.02]:
            var wheel := _cylinder(0.31, 0.20, Color(0.025, 0.028, 0.032))
            wheel.rotation.z = PI / 2.0
            wheel.position = Vector3(x, 0.34, z)
            root.add_child(wheel)
            var rim := _cylinder(0.19, 0.215, Color(0.60, 0.63, 0.66))
            rim.rotation.z = PI / 2.0
            rim.position = Vector3(x * 1.01, 0.34, z)
            root.add_child(rim)
    var front_light := _box(Vector3(0.42, 0.12, 0.07), Color(0.94, 0.98, 1.0))
    front_light.position = Vector3(-0.52, 0.70, -1.61)
    root.add_child(front_light)
    var front_light2 := front_light.duplicate() as MeshInstance3D
    front_light2.position.x = 0.52
    root.add_child(front_light2)
    var tail := _box(Vector3(0.32, 0.11, 0.05), Color(0.95, 0.04, 0.035))
    tail.position = Vector3(-0.43, 0.68, 1.51)
    root.add_child(tail)
    var tail2 := tail.duplicate() as MeshInstance3D
    tail2.position.x = 0.43
    root.add_child(tail2)
    if is_player:
        root.name = "PlayerCar"
    return root

func _make_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 5.2, 12.5)
    camera.rotation_degrees = Vector3(-16, 0, 0)
    camera.fov = 72
    add_child(camera)
    camera.current = true

func _make_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(22, 18)
    hud.add_theme_font_size_override("font_size", 26)
    hud.add_theme_color_override("font_color", Color.WHITE)
    hud.add_theme_color_override("font_shadow_color", Color.BLACK)
    hud.add_theme_constant_override("shadow_offset_x", 2)
    hud.add_theme_constant_override("shadow_offset_y", 2)
    layer.add_child(hud)
    speed_label = Label.new()
    speed_label.position = Vector2(22, 52)
    speed_label.add_theme_font_size_override("font_size", 20)
    speed_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.18))
    layer.add_child(speed_label)
    coin_label = Label.new()
    coin_label.position = Vector2(22, 82)
    coin_label.add_theme_font_size_override("font_size", 20)
    coin_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.18))
    layer.add_child(coin_label)
    message_label = Label.new()
    message_label.anchor_left = 0.25
    message_label.anchor_right = 0.75
    message_label.anchor_top = 0.30
    message_label.anchor_bottom = 0.48
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size", 34)
    message_label.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(message_label)
    pause_button = _button(layer, "Ⅱ", Vector2(0.91, 0.02), Vector2(0.98, 0.12))
    pause_button.pressed.connect(_toggle_pause)
    _make_game_overlays(layer)
    left_button = _button(layer, "◀", Vector2(0.02, 0.72), Vector2(0.14, 0.94))
    left_button.button_down.connect(func(): touch_steer = -1.0)
    left_button.button_up.connect(func(): touch_steer = 0.0)
    right_button = _button(layer, "▶", Vector2(0.15, 0.72), Vector2(0.27, 0.94))
    right_button.button_down.connect(func(): touch_steer = 1.0)
    right_button.button_up.connect(func(): touch_steer = 0.0)
    brake_button = _button(layer, "BRAKE", Vector2(0.73, 0.76), Vector2(0.85, 0.95))
    brake_button.button_down.connect(func(): brake_pressed = true)
    brake_button.button_up.connect(func(): brake_pressed = false)
    gas_button = _button(layer, "GAS", Vector2(0.86, 0.76), Vector2(0.98, 0.95))
    gas_button.button_down.connect(func(): gas_pressed = true)
    gas_button.button_up.connect(func(): gas_pressed = false)


func _make_menu() -> void:
    menu_panel = Control.new()
    menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    menu_panel.z_index = 20
    add_child(menu_panel)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.015, 0.025, 0.045, 0.90)
    menu_panel.add_child(shade)

    var title := Label.new()
    title.text = "OLD RACING 3D"
    title.anchor_left = 0.20
    title.anchor_right = 0.80
    title.anchor_top = 0.13
    title.anchor_bottom = 0.25
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 44)
    title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
    menu_panel.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "CHOOSE YOUR CONTROL"
    subtitle.anchor_left = 0.25
    subtitle.anchor_right = 0.75
    subtitle.anchor_top = 0.31
    subtitle.anchor_bottom = 0.39
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 23)
    subtitle.add_theme_color_override("font_color", Color(0.72, 0.84, 0.98))
    menu_panel.add_child(subtitle)

    control_mode_button = Button.new()
    control_mode_button.text = "STEERING: BUTTONS"
    control_mode_button.anchor_left = 0.30
    control_mode_button.anchor_right = 0.70
    control_mode_button.anchor_top = 0.43
    control_mode_button.anchor_bottom = 0.56
    control_mode_button.add_theme_font_size_override("font_size", 22)
    control_mode_button.pressed.connect(_toggle_control_mode)
    menu_panel.add_child(control_mode_button)

    car_color_button = Button.new()
    car_color_button.text = "CAR: " + car_names[car_color_index]
    car_color_button.anchor_left = 0.30
    car_color_button.anchor_right = 0.70
    car_color_button.anchor_top = 0.57
    car_color_button.anchor_bottom = 0.67
    car_color_button.add_theme_font_size_override("font_size", 20)
    car_color_button.pressed.connect(_cycle_car_color)
    menu_panel.add_child(car_color_button)

    var start_button := Button.new()
    start_button.text = "PLAY"
    start_button.anchor_left = 0.36
    start_button.anchor_right = 0.64
    start_button.anchor_top = 0.73
    start_button.anchor_bottom = 0.88
    start_button.add_theme_font_size_override("font_size", 30)
    start_button.pressed.connect(_start_game)
    menu_panel.add_child(start_button)

func _toggle_control_mode() -> void:
    tilt_mode = not tilt_mode
    control_mode_button.text = "STEERING: TILT" if tilt_mode else "STEERING: BUTTONS"
    touch_steer = 0.0

func _cycle_car_color() -> void:
    car_color_index = (car_color_index + 1) % car_colors.size()
    selected_car_color = car_colors[car_color_index]
    car_color_button.text = "CAR: " + car_names[car_color_index]
    if is_instance_valid(player):
        player.queue_free()
    player = _make_car(selected_car_color, true)
    player.position = Vector3(0, 0.0, PLAYER_Z)
    add_child(player)

func _start_game() -> void:
    menu_active = false
    menu_panel.hide()


func _make_game_overlays(layer: CanvasLayer) -> void:
    pause_panel = Control.new()
    pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_panel.visible = false
    pause_panel.z_index = 10
    layer.add_child(pause_panel)
    var pause_shade := ColorRect.new()
    pause_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_shade.color = Color(0.01, 0.02, 0.04, 0.82)
    pause_panel.add_child(pause_shade)
    var pause_title := Label.new()
    pause_title.text = "PAUSED"
    pause_title.anchor_left = 0.30
    pause_title.anchor_right = 0.70
    pause_title.anchor_top = 0.22
    pause_title.anchor_bottom = 0.36
    pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_title.add_theme_font_size_override("font_size", 42)
    pause_panel.add_child(pause_title)
    var resume_button := _overlay_button(pause_panel, "RESUME", 0.34, 0.43, 0.66, 0.56)
    resume_button.pressed.connect(_toggle_pause)
    var menu_button := _overlay_button(pause_panel, "MAIN MENU", 0.34, 0.61, 0.66, 0.74)
    menu_button.pressed.connect(_return_to_menu)

    crash_panel = Control.new()
    crash_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    crash_panel.visible = false
    crash_panel.z_index = 11
    layer.add_child(crash_panel)
    var crash_shade := ColorRect.new()
    crash_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    crash_shade.color = Color(0.10, 0.015, 0.015, 0.84)
    crash_panel.add_child(crash_shade)
    var crash_title := Label.new()
    crash_title.text = "CRASH!"
    crash_title.anchor_left = 0.30
    crash_title.anchor_right = 0.70
    crash_title.anchor_top = 0.22
    crash_title.anchor_bottom = 0.36
    crash_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    crash_title.add_theme_font_size_override("font_size", 42)
    crash_title.add_theme_color_override("font_color", Color(1.0, 0.30, 0.22))
    crash_panel.add_child(crash_title)
    var retry_button := _overlay_button(crash_panel, "TRY AGAIN", 0.34, 0.43, 0.66, 0.56)
    retry_button.pressed.connect(_restart_game)
    var crash_menu_button := _overlay_button(crash_panel, "MAIN MENU", 0.34, 0.61, 0.66, 0.74)
    crash_menu_button.pressed.connect(_return_to_menu)

func _overlay_button(parent: Control, label_text: String, left: float, top: float, right: float, bottom: float) -> Button:
    var b := Button.new()
    b.text = label_text
    b.anchor_left = left
    b.anchor_top = top
    b.anchor_right = right
    b.anchor_bottom = bottom
    b.add_theme_font_size_override("font_size", 24)
    parent.add_child(b)
    return b

func _restart_game() -> void:
    crashed = false
    paused = false
    distance = 0.0
    speed = 26.0
    steering = 0.0
    touch_steer = 0.0
    player.position = Vector3(0, 0, PLAYER_Z)
    message_label.text = ""
    crash_panel.hide()
    for car in traffic:
        car.queue_free()
    traffic.clear()
    for coin in coin_nodes:
        coin.queue_free()
    coin_nodes.clear()
    for i in range(5):
        _spawn_traffic(-25.0 - float(i) * 24.0)

func _return_to_menu() -> void:
    paused = false
    crashed = false
    menu_active = true
    pause_panel.hide()
    crash_panel.hide()
    menu_panel.show()
    message_label.text = ""
    touch_steer = 0.0

func _button(layer: CanvasLayer, text_value: String, top_left: Vector2, bottom_right: Vector2) -> Button:
    var b := Button.new()
    b.text = text_value
    b.anchor_left = top_left.x
    b.anchor_top = top_left.y
    b.anchor_right = bottom_right.x
    b.anchor_bottom = bottom_right.y
    b.offset_left = 0
    b.offset_top = 0
    b.offset_right = 0
    b.offset_bottom = 0
    b.add_theme_font_size_override("font_size", 22)
    layer.add_child(b)
    return b

func _process(delta: float) -> void:
    if menu_active or paused or crashed:
        return
    var steer := touch_steer
    if tilt_mode and OS.has_feature("mobile"):
        steer = clamp(-Input.get_accelerometer().x / 5.0, -1.0, 1.0)
        if abs(touch_steer) > 0.1:
            steer = touch_steer
    if Input.is_action_pressed("ui_left"):
        steer = -1.0
    elif Input.is_action_pressed("ui_right"):
        steer = 1.0
    steering = move_toward(steering, steer, delta * 2.5)
    player.position.x = clamp(player.position.x + steering * delta * 6.0, -5.1, 5.1)
    if gas_pressed:
        speed = min(MAX_SPEED, speed + delta * 17.0)
    elif brake_pressed:
        speed = max(MIN_SPEED, speed - delta * 28.0)
    else:
        speed = move_toward(speed, 26.0, delta * 2.0)
    distance += speed * delta * 0.5
    spawn_timer += delta
    coin_timer += delta
    for mark in road_marks:
        mark.position.z += speed * delta
        if mark.position.z > 16.0:
            mark.position.z -= 180.0
    for car in traffic.duplicate():
        car.position.z += speed * delta * 0.65
        if car.position.z > 15.0:
            traffic.erase(car)
            car.queue_free()
            _spawn_traffic(-150.0 - randf() * 55.0)
        elif abs(car.position.z - PLAYER_Z) < 2.2 and abs(car.position.x - player.position.x) < 1.35:
            crashed = true
            crash_panel.show()
    if spawn_timer > 1.7:
        spawn_timer = 0.0
        _spawn_traffic(-165.0 - randf() * 45.0)
    if coin_timer > 2.5:
        coin_timer = 0.0
        _spawn_coin()
    for coin in coin_nodes.duplicate():
        coin.position.z += speed * delta
        coin.rotation.y += delta * 2.5
        if coin.position.z > 14.0:
            coin_nodes.erase(coin)
            coin.queue_free()
        elif abs(coin.position.z - PLAYER_Z) < 1.8 and abs(coin.position.x - player.position.x) < 1.2:
            coins += 1
            coin_nodes.erase(coin)
            coin.queue_free()
    hud.text = "OLD RACING 3D     DISTANCE: %dm" % int(distance)
    speed_label.text = "%d KM/H" % int(speed * 4.0)
    coin_label.text = "●  %d" % coins

func _spawn_traffic(z: float) -> void:
    var colors := [Color(0.85, 0.08, 0.08), Color(0.10, 0.55, 0.30), Color(0.92, 0.72, 0.12), Color(0.78, 0.80, 0.84), Color(0.08, 0.10, 0.14)]
    var car := _make_car(colors[randi() % colors.size()], false)
    var lane_x: float = [-5.25, -1.75, 1.75, 5.25][randi() % 4]
    car.position = Vector3(lane_x, 0, z)
    add_child(car)
    traffic.append(car)

func _spawn_coin() -> void:
    var coin := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.55
    mesh.bottom_radius = 0.55
    mesh.height = 0.12
    coin.mesh = mesh
    coin.material_override = _mat(Color(1.0, 0.72, 0.08), 0.35, 0.2)
    coin.position = Vector3([-5.25, -1.75, 1.75, 5.25][randi() % 4], 1.0, -145.0)
    add_child(coin)
    coin_nodes.append(coin)

func _toggle_pause() -> void:
    if menu_active or crashed:
        return
    paused = not paused
    pause_panel.visible = paused
    if not paused:
        touch_steer = 0.0

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _toggle_pause()

func _box(size: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = _mat(color)
    return node

func _cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    node.mesh = mesh
    node.material_override = _mat(color)
    return node

func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.72) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m
