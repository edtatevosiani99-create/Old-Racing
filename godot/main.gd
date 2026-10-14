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
var ui_layer: CanvasLayer
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
var active_touches: Dictionary = {}
var menu_active := true
var menu_panel: Control
var control_mode_button: Button
var car_color_button: Button
var selected_car_color := Color(0.08, 0.32, 0.95)
var car_color_index := 2
var selected_car_index := 0
var paint_index := 1
var car_colors: Array[Color] = [Color(0.78, 0.025, 0.02), Color(0.82, 0.035, 0.025), Color(0.12, 0.13, 0.15)]
var car_names: Array[String] = ["FERRARI F40", "CAMARO ZL1", "DODGE CHARGER"]
var pause_panel: Control
var crash_panel: Control
var selector_panel: Control
var selector_active := false
var selector_viewport: SubViewport
var selector_preview: Node3D
var selector_car_label: Label
var selector_color_label: Label
var selector_bumper_label: Label
var selector_rims_label: Label
var selector_hood_label: Label
var selector_spoiler_label: Label
var selector_dragging := false
var selector_last_x := 0.0
var tuning_bumper := 0
var tuning_rims := 0
var tuning_hood := 0
var tuning_spoiler := 0
var tuning_colors: Array[Color] = [Color(0.82, 0.025, 0.02), Color(0.02, 0.28, 0.95), Color(0.02, 0.68, 0.28), Color(0.92, 0.82, 0.08), Color(0.88, 0.88, 0.90), Color(0.035, 0.04, 0.055)]
var tuning_color_names: Array[String] = ["RACING RED", "ELECTRIC BLUE", "RACING GREEN", "YELLOW", "PEARL WHITE", "MIDNIGHT BLACK"]

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
    e.ambient_light_color = Color(0.72, 0.78, 0.86)
    e.ambient_light_energy = 0.82
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    e.tonemap_exposure = 1.08
    e.tonemap_white = 5.0
    e.ssao_enabled = true
    e.ssao_radius = 1.4
    e.ssao_intensity = 1.1
    e.ssr_enabled = false
    env.environment = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -25, 0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 85.0
    sun.shadow_bias = 0.035
    add_child(sun)
    var ground := _box(Vector3(250, 0.3, 260), Color(0.17, 0.42, 0.20))
    ground.position = Vector3(0, -0.35, -65)
    add_child(ground)

func _make_road() -> void:
    # Asphalt base with a repeating procedural noise texture instead of a flat grey box.
    var road := _box(Vector3(ROAD_WIDTH, 0.18, ROAD_LENGTH), Color(0.13, 0.135, 0.14))
    road.position = Vector3(0, -0.12, -70)
    add_child(road)

    var asphalt := StandardMaterial3D.new()
    asphalt.albedo_color = Color(0.78, 0.79, 0.80)
    asphalt.roughness = 0.96
    var asphalt_noise := FastNoiseLite.new()
    asphalt_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    asphalt_noise.frequency = 0.075
    asphalt_noise.fractal_octaves = 4
    var asphalt_texture := NoiseTexture2D.new()
    asphalt_texture.width = 512
    asphalt_texture.height = 512
    asphalt_texture.seamless = true
    asphalt_texture.noise = asphalt_noise
    asphalt.albedo_texture = asphalt_texture
    asphalt.uv1_scale = Vector3(3.0, 22.0, 1.0)
    var road_surface := MeshInstance3D.new()
    var road_plane := PlaneMesh.new()
    road_plane.size = Vector2(ROAD_WIDTH, ROAD_LENGTH)
    road_surface.mesh = road_plane
    road_surface.material_override = asphalt
    road_surface.position = Vector3(0, -0.025, -70)
    add_child(road_surface)

    # Narrow textured shoulders, crisp edge paint, and metal barriers with visible supports.
    for side in [-1.0, 1.0]:
        var shoulder := _box(Vector3(1.05, 0.035, ROAD_LENGTH), Color(0.34, 0.35, 0.34))
        shoulder.position = Vector3(side * (ROAD_WIDTH * 0.5 + 0.52), -0.025, -70)
        add_child(shoulder)
        var edge := _box(Vector3(0.16, 0.035, ROAD_LENGTH), Color(0.94, 0.94, 0.88))
        edge.position = Vector3(side * ROAD_WIDTH * 0.465, 0.012, -70)
        add_child(edge)
        var rail := _box(Vector3(0.14, 0.22, ROAD_LENGTH), Color(0.53, 0.57, 0.60))
        rail.position = Vector3(side * (ROAD_WIDTH * 0.5 + 1.15), 0.62, -70)
        add_child(rail)
        for i in range(32):
            var post := _box(Vector3(0.12, 0.78, 0.18), Color(0.36, 0.39, 0.41))
            post.position = Vector3(side * (ROAD_WIDTH * 0.5 + 1.15), 0.24, 12.0 - float(i) * 5.7)
            add_child(post)
            if i % 2 == 0:
                var reflector := _box(Vector3(0.035, 0.10, 0.28), Color(0.95, 0.80, 0.28))
                reflector.position = Vector3(side * (ROAD_WIDTH * 0.5 + 1.07), 0.63, 12.0 - float(i) * 5.7)
                add_child(reflector)

    # Broken white lane dividers, cycling with the road to preserve the endless-runner effect.
    for lane in [-1.0, 1.0]:
        for i in range(24):
            var mark := _box(Vector3(0.11, 0.028, 3.4), Color(0.93, 0.94, 0.91))
            mark.position = Vector3(lane * LANE_WIDTH, 0.018, 12.0 - float(i) * 7.5)
            add_child(mark)
            road_marks.append(mark)

    var center := _box(Vector3(0.075, 0.025, ROAD_LENGTH), Color(0.98, 0.73, 0.13))
    center.position = Vector3(0, 0.012, -70)
    add_child(center)

    # Small asphalt repairs add texture and scale without expensive real-time effects.
    for i in range(16):
        var patch := _box(Vector3(0.45 + float(i % 3) * 0.25, 0.012, 0.7 + float(i % 4) * 0.18), Color(0.105, 0.11, 0.115))
        patch.position = Vector3(-4.7 + float((i * 7) % 10), 0.006, 8.0 - float(i) * 10.5)
        add_child(patch)

    # Varied roadside trees: cylindrical trunks and clustered broadleaf canopies.
    for i in range(21):
        var z := 12.0 - float(i) * 8.4
        for side in [-1.0, 1.0]:
            _make_roadside_tree(Vector3(side * (10.0 + float(i % 3) * 1.3), 0.0, z), i)

    # Roadside city blocks: use actual imported building meshes when available.
    var building_paths: Array[String] = [
        "res://assets/environment/city/building-type-a.glb",
        "res://assets/environment/city/building-type-d.glb",
        "res://assets/environment/city/building-type-g.glb",
        "res://assets/environment/city/building-type-k.glb",
        "res://assets/environment/city/building-type-n.glb"
    ]
    for i in range(10):
        var building_z := 2.0 - float(i) * 22.0
        for side in [-1.0, 1.0]:
            var building_path := building_paths[(i + int(side + 1.0)) % building_paths.size()]
            if ResourceLoader.exists(building_path):
                var building_scene := load(building_path) as PackedScene
                if building_scene != null:
                    var building_model := building_scene.instantiate() as Node3D
                    if building_model != null:
                        building_model.position = Vector3(side * (18.0 + float(i % 2) * 2.0), 0.0, building_z)
                        var building_scale := 2.8 + float(i % 3) * 0.25
                        building_model.scale = Vector3(building_scale, building_scale, building_scale)
                        add_child(building_model)
            else:
                var h := 4.5 + float(i % 3) * 1.8
                var building := _box(Vector3(3.8, h, 4.8), Color(0.55, 0.58, 0.60))
                building.position = Vector3(side * (18.0 + float(i % 2) * 2.0), h * 0.5 - 0.1, building_z)
                add_child(building)
            # Greenery and street furniture remain visible in either asset or fallback mode.
            for bush_index in range(3):
                var bush := MeshInstance3D.new()
                var bush_mesh := SphereMesh.new()
                bush_mesh.radius = 0.7
                bush_mesh.height = 1.1
                bush.mesh = bush_mesh
                bush.material_override = _mat(Color(0.12 + float(bush_index) * 0.025, 0.28 + float(i % 3) * 0.025, 0.13), 0.0, 0.94)
                bush.position = Vector3(side * (18.0 + float(i % 2) * 2.0) + float(bush_index - 1) * 1.25, 0.45, building_z + 3.3)
                bush.scale = Vector3(1.15, 0.8, 0.85)
                add_child(bush)

func _make_roadside_tree(base: Vector3, variant: int) -> void:
    # Import proper low-poly tree meshes from the CC0 environment kit when available.
    # Prefer the separate CC0 Nature Kit trees for more natural silhouettes; retain city-kit fallback.
    var tree_path := "res://assets/environment/nature/tree_oak.glb" if variant % 3 != 0 else "res://assets/environment/nature/tree_default.glb"
    if not ResourceLoader.exists(tree_path):
        tree_path = "res://assets/environment/city/tree-large.glb" if variant % 3 != 0 else "res://assets/environment/city/tree-small.glb"
    if ResourceLoader.exists(tree_path):
        var tree_scene := load(tree_path) as PackedScene
        if tree_scene != null:
            var tree_model := tree_scene.instantiate() as Node3D
            if tree_model != null:
                tree_model.position = base
                var tree_scale := 1.55 if variant % 3 != 0 else 1.9
                tree_model.scale = Vector3(tree_scale, tree_scale, tree_scale)
                add_child(tree_model)
                return
    var trunk_height := 2.2 + float(variant % 4) * 0.28
    var trunk := _cylinder(0.22, trunk_height, Color(0.27, 0.16, 0.09))
    trunk.position = base + Vector3(0, trunk_height * 0.5, 0)
    add_child(trunk)

    var greens: Array[Color] = [Color(0.08, 0.25, 0.10), Color(0.12, 0.34, 0.13), Color(0.17, 0.38, 0.16), Color(0.10, 0.29, 0.18)]
    for cluster in range(5):
        var crown := MeshInstance3D.new()
        var crown_mesh := SphereMesh.new()
        crown_mesh.radius = 1.05 if cluster == 0 else 0.72
        crown_mesh.height = 2.0 if cluster == 0 else 1.4
        crown.mesh = crown_mesh
        crown.material_override = _mat(greens[(variant + cluster) % greens.size()], 0.0, 0.92)
        var offset := Vector3(0, trunk_height + 0.65, 0) if cluster == 0 else Vector3(cos(float(cluster) * 1.25) * 0.7, trunk_height + 0.45 + float(cluster % 2) * 0.48, sin(float(cluster) * 1.25) * 0.62)
        crown.position = base + offset
        crown.scale = Vector3(1.0, 0.88, 0.92)
        add_child(crown)

    # Grass tufts break up the flat green verge.
    for tuft in range(3):
        var grass := _box(Vector3(0.10, 0.42, 0.08), Color(0.20, 0.39 + float(tuft) * 0.025, 0.13))
        grass.position = base + Vector3(-1.0 + float(tuft) * 0.85, 0.20, 1.0 + float(tuft % 2) * 0.4)
        grass.rotation.z = deg_to_rad(float(tuft - 1) * 16.0)
        add_child(grass)


func _car_display_name(index: int) -> String:
    var model_paths: Array[String] = [
        "res://assets/cars/ferrari_f40.glb",
        "res://assets/cars/camaro_zl1_2017.glb",
        "res://assets/cars/dodge_charger.gltf"
    ]
    if index >= 0 and index < model_paths.size() and ResourceLoader.exists(model_paths[index]):
        return car_names[index]
    var fallback_names: Array[String] = ["SPORTS CAR", "SPORT SEDAN", "LUXURY SUV"]
    return fallback_names[index % fallback_names.size()]


func _make_car(color: Color, is_player: bool) -> Node3D:
    var root := Node3D.new()
    # Prefer the selected Poly Pizza models; use the bundled Kenney cars until those files are added.
    # Imported Poly Pizza cars. Add the downloaded GLB files at these exact paths.
    # If an asset is absent, the safe procedural fallback below keeps the game playable.
    var vehicle_paths: Array[String] = [
        "res://assets/cars/ferrari_f40.glb",
        "res://assets/cars/camaro_zl1_2017.glb",
        "res://assets/cars/dodge_charger.gltf"
    ]
    var kenney_fallback_paths: Array[String] = [
        "res://assets/vehicles/race.glb",
        "res://assets/vehicles/sedan-sports.glb",
        "res://assets/vehicles/suv-luxury.glb"
    ]
    var selected_index := selected_car_index % vehicle_paths.size() if is_player else randi_range(0, vehicle_paths.size() - 1)
    var vehicle_path := vehicle_paths[selected_index]
    if not ResourceLoader.exists(vehicle_path):
        vehicle_path = kenney_fallback_paths[selected_index]
    if ResourceLoader.exists(vehicle_path):
        var vehicle_scene := load(vehicle_path) as PackedScene
        if vehicle_scene != null:
            var vehicle_model := vehicle_scene.instantiate() as Node3D
            if vehicle_model != null:
                vehicle_model.scale = Vector3(1.10, 1.10, 1.10)
                vehicle_model.position = Vector3(0, 0.02, 0)
                _tint_vehicle_paint(vehicle_model, color)
                root.add_child(vehicle_model)
                _add_tuning_parts(root, color)
                if is_player:
                    root.name = "PlayerCar"
                return root
    # Smooth, rounded shell gives the car a less toy-like silhouette than a plain box.
    var body := MeshInstance3D.new()
    var body_mesh := SphereMesh.new()
    body_mesh.radius = 1.0
    body_mesh.height = 2.0
    body.mesh = body_mesh
    body.material_override = _mat(color, 0.38, 0.27)
    body.position.y = 0.59
    body.scale = Vector3(0.88, 0.29, 1.62)
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
    var hood := MeshInstance3D.new()
    var hood_mesh := SphereMesh.new()
    hood_mesh.radius = 1.0
    hood_mesh.height = 2.0
    hood.mesh = hood_mesh
    hood.material_override = _mat(color.lightened(0.10), 0.42, 0.24)
    hood.position = Vector3(0, 0.82, -0.82)
    hood.scale = Vector3(0.72, 0.105, 0.52)
    root.add_child(hood)
    var roof := MeshInstance3D.new()
    var roof_mesh := SphereMesh.new()
    roof_mesh.radius = 1.0
    roof_mesh.height = 2.0
    roof.mesh = roof_mesh
    roof.material_override = _mat(Color(0.055, 0.085, 0.10), 0.18, 0.20)
    roof.position = Vector3(0, 1.04, 0.18)
    roof.scale = Vector3(0.56, 0.22, 0.66)
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
    # Side glass, door seams and sporty body accents.
    for side in [-1.0, 1.0]:
        var side_glass := _box(Vector3(0.045, 0.27, 0.78), Color(0.12, 0.27, 0.34))
        side_glass.position = Vector3(side * 0.565, 1.08, -0.02)
        root.add_child(side_glass)
        var door_line := _box(Vector3(0.035, 0.25, 0.78), color.darkened(0.30))
        door_line.position = Vector3(side * 0.866, 0.61, 0.10)
        root.add_child(door_line)
    var hood_line := _box(Vector3(0.045, 0.018, 0.72), color.lightened(0.28))
    hood_line.position = Vector3(0.0, 0.958, -0.78)
    root.add_child(hood_line)
    var front_bumper := _box(Vector3(1.58, 0.13, 0.12), color.darkened(0.32))
    front_bumper.position = Vector3(0, 0.36, -1.62)
    root.add_child(front_bumper)
    var rear_bumper := _box(Vector3(1.58, 0.13, 0.12), color.darkened(0.32))
    rear_bumper.position = Vector3(0, 0.36, 1.58)
    root.add_child(rear_bumper)
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
    front_light.material_override = _mat(Color(0.92, 0.97, 1.0), 0.12, 0.18)
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
    # High-detail procedural body kit: layered fascia, glass trim, vents, badges and wheel hardware.
    # Vehicle faces forward along -Z.
    var front_lip := _box(Vector3(1.82, 0.055, 0.28), Color(0.018, 0.021, 0.025))
    front_lip.position = Vector3(0, 0.285, -1.58)
    root.add_child(front_lip)
    var rear_diffuser := _box(Vector3(1.28, 0.12, 0.20), Color(0.025, 0.028, 0.032))
    rear_diffuser.position = Vector3(0, 0.285, 1.56)
    root.add_child(rear_diffuser)

    # Individual LED headlight strips, amber indicators, and rear light bars.
    for side in [-1.0, 1.0]:
        var led := _box(Vector3(0.30, 0.035, 0.025), Color(0.78, 0.92, 1.0))
        led.position = Vector3(side * 0.55, 0.755, -1.655)
        root.add_child(led)
        var indicator := _box(Vector3(0.085, 0.035, 0.025), Color(1.0, 0.48, 0.06))
        indicator.position = Vector3(side * 0.78, 0.70, -1.65)
        root.add_child(indicator)
        var tail_outer := _box(Vector3(0.47, 0.12, 0.055), Color(0.19, 0.012, 0.018))
        tail_outer.position = Vector3(side * 0.48, 0.69, 1.535)
        root.add_child(tail_outer)
        var tail_led := _box(Vector3(0.39, 0.045, 0.025), Color(1.0, 0.025, 0.018))
        tail_led.position = Vector3(side * 0.48, 0.70, 1.57)
        root.add_child(tail_led)

    # Metallic grille mesh effect with multiple narrow horizontal slats.
    for row in range(4):
        var slat := _box(Vector3(0.52, 0.012, 0.018), Color(0.30, 0.33, 0.36))
        slat.position = Vector3(0, 0.455 + float(row) * 0.035, -1.685)
        root.add_child(slat)

    # Side skirts, door handles, mirrors with glass, vents and sculpted accent lines.
    for side in [-1.0, 1.0]:
        var skirt := _box(Vector3(0.10, 0.12, 1.42), color.darkened(0.25))
        skirt.position = Vector3(side * 0.87, 0.36, 0.05)
        root.add_child(skirt)
        var handle := _box(Vector3(0.035, 0.045, 0.20), Color(0.72, 0.74, 0.76))
        handle.position = Vector3(side * 0.884, 0.69, 0.02)
        root.add_child(handle)
        var side_vent := _box(Vector3(0.025, 0.16, 0.34), Color(0.018, 0.022, 0.025))
        side_vent.position = Vector3(side * 0.884, 0.68, -0.78)
        root.add_child(side_vent)
        for vent_line in range(3):
            var vent_slit := _box(Vector3(0.018, 0.012, 0.24), Color(0.38, 0.40, 0.42))
            vent_slit.position = Vector3(side * 0.901, 0.65 + float(vent_line) * 0.045, -0.78)
            root.add_child(vent_slit)
        var mirror_glass := _box(Vector3(0.035, 0.075, 0.13), Color(0.22, 0.39, 0.48))
        mirror_glass.position = Vector3(side * 1.09, 0.925, -0.45)
        root.add_child(mirror_glass)
        var lower_trim := _box(Vector3(0.025, 0.025, 1.08), color.lightened(0.22))
        lower_trim.position = Vector3(side * 0.91, 0.43, 0.20)
        root.add_child(lower_trim)

    # Wheels receive visible brake discs, calipers, hubs and five metallic spokes per side.
    for side in [-1.0, 1.0]:
        for z in [-1.02, 1.02]:
            var disc := _cylinder(0.145, 0.225, Color(0.31, 0.33, 0.35))
            disc.rotation.z = PI / 2.0
            disc.position = Vector3(side * 0.995, 0.34, z)
            root.add_child(disc)
            var hub := _cylinder(0.055, 0.245, Color(0.78, 0.80, 0.82))
            hub.rotation.z = PI / 2.0
            hub.position = Vector3(side * 1.105, 0.34, z)
            root.add_child(hub)
            var caliper := _box(Vector3(0.075, 0.18, 0.10), Color(0.78, 0.035, 0.025))
            caliper.position = Vector3(side * 1.105, 0.39, z - 0.12)
            root.add_child(caliper)
            for spoke_index in range(5):
                var spoke := _box(Vector3(0.045, 0.245, 0.052), Color(0.72, 0.75, 0.78))
                spoke.position = Vector3(side * 1.125, 0.34, z)
                spoke.rotation.x = float(spoke_index) * TAU / 5.0
                root.add_child(spoke)

    # Hood power creases and a pair of raised vents catch highlights as the camera moves.
    for side in [-1.0, 1.0]:
        var hood_crease := _box(Vector3(0.025, 0.018, 0.72), color.lightened(0.18))
        hood_crease.position = Vector3(side * 0.43, 0.93, -0.80)
        root.add_child(hood_crease)
        var hood_vent := _box(Vector3(0.20, 0.025, 0.28), Color(0.025, 0.028, 0.032))
        hood_vent.position = Vector3(side * 0.25, 0.94, -1.05)
        root.add_child(hood_vent)
        for vent in range(3):
            var hood_slit := _box(Vector3(0.15, 0.012, 0.018), Color(0.42, 0.44, 0.46))
            hood_slit.position = Vector3(side * 0.25, 0.958, -1.13 + float(vent) * 0.075)
            root.add_child(hood_slit)

    # Rear exhaust tips and license plate frame.
    for side in [-1.0, 1.0]:
        var exhaust := _cylinder(0.075, 0.13, Color(0.48, 0.50, 0.52))
        exhaust.rotation.x = PI / 2.0
        exhaust.position = Vector3(side * 0.48, 0.34, 1.66)
        root.add_child(exhaust)
        var exhaust_inner := _cylinder(0.043, 0.14, Color(0.035, 0.038, 0.04))
        exhaust_inner.rotation.x = PI / 2.0
        exhaust_inner.position = Vector3(side * 0.48, 0.34, 1.70)
        root.add_child(exhaust_inner)
    var plate := _box(Vector3(0.48, 0.12, 0.025), Color(0.82, 0.84, 0.82))
    plate.position = Vector3(0, 0.49, 1.635)
    root.add_child(plate)
    var plate_text := _box(Vector3(0.34, 0.018, 0.012), Color(0.035, 0.04, 0.045))
    plate_text.position = Vector3(0, 0.50, 1.652)
    root.add_child(plate_text)

    # Subtle front fender markers and window pillars make the silhouette read more clearly.
    for side in [-1.0, 1.0]:
        var marker := _box(Vector3(0.025, 0.045, 0.12), Color(1.0, 0.42, 0.035))
        marker.position = Vector3(side * 0.89, 0.62, -1.02)
        root.add_child(marker)
        var pillar := _box(Vector3(0.045, 0.30, 0.055), Color(0.025, 0.035, 0.042))
        pillar.position = Vector3(side * 0.54, 1.08, 0.05)
        pillar.rotation.x = deg_to_rad(-8.0)
        root.add_child(pillar)

    _add_tuning_parts(root, color)
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
    ui_layer = layer
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
    # Driving layout changes with steering mode. Pedals stay on-screen in both modes.
    left_button = _button(layer, "◀", Vector2(0.02, 0.72), Vector2(0.14, 0.94))
    right_button = _button(layer, "▶", Vector2(0.15, 0.72), Vector2(0.27, 0.94))
    brake_button = _button(layer, "BRAKE", Vector2(0.72, 0.76), Vector2(0.84, 0.95))
    gas_button = _button(layer, "GAS", Vector2(0.86, 0.76), Vector2(0.98, 0.95))
    # Pedals use the actual button hold state, not screen-coordinate guesses.
    # This keeps gas/brake reliable while another finger steers.
    gas_button.button_down.connect(func(): gas_pressed = true)
    gas_button.button_up.connect(func(): gas_pressed = false)
    brake_button.button_down.connect(func(): brake_pressed = true)
    brake_button.button_up.connect(func(): brake_pressed = false)
    _refresh_control_layout()


func _make_menu() -> void:
    menu_panel = Control.new()
    menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    menu_panel.z_index = 20
    ui_layer.add_child(menu_panel)

    # Original racing-game menu with the familiar garage / play / settings flow.
    # It uses our own layout and generated 3D scene rather than copied proprietary assets.
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.008, 0.018, 0.035, 0.38)
    menu_panel.add_child(shade)

    var top_bar := ColorRect.new()
    top_bar.anchor_right = 1.0
    top_bar.anchor_bottom = 0.145
    top_bar.color = Color(0.012, 0.025, 0.045, 0.92)
    menu_panel.add_child(top_bar)

    var title := Label.new()
    title.text = "OLD RACING"
    title.anchor_left = 0.035
    title.anchor_right = 0.38
    title.anchor_top = 0.018
    title.anchor_bottom = 0.085
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 38)
    title.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
    title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    title.add_theme_constant_override("shadow_offset_x", 2)
    title.add_theme_constant_override("shadow_offset_y", 2)
    menu_panel.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "HIGHWAY  •  TRAFFIC  •  SPEED"
    subtitle.anchor_left = 0.04
    subtitle.anchor_right = 0.40
    subtitle.anchor_top = 0.078
    subtitle.anchor_bottom = 0.13
    subtitle.add_theme_font_size_override("font_size", 15)
    subtitle.add_theme_color_override("font_color", Color(0.40, 0.80, 1.0))
    menu_panel.add_child(subtitle)

    var wallet := Panel.new()
    wallet.anchor_left = 0.78
    wallet.anchor_right = 0.965
    wallet.anchor_top = 0.035
    wallet.anchor_bottom = 0.115
    var wallet_style := StyleBoxFlat.new()
    wallet_style.bg_color = Color(0.04, 0.09, 0.14, 0.96)
    wallet_style.border_color = Color(0.20, 0.62, 0.90, 0.9)
    wallet_style.set_border_width_all(1)
    wallet_style.set_corner_radius_all(10)
    wallet.add_theme_stylebox_override("panel", wallet_style)
    menu_panel.add_child(wallet)

    var wallet_text := Label.new()
    wallet_text.text = "●   %d" % coins
    wallet_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    wallet_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    wallet_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    wallet_text.add_theme_font_size_override("font_size", 22)
    wallet_text.add_theme_color_override("font_color", Color(1.0, 0.80, 0.16))
    wallet.add_child(wallet_text)

    var left_caption := Label.new()
    left_caption.text = "YOUR RIDE"
    left_caption.anchor_left = 0.055
    left_caption.anchor_right = 0.38
    left_caption.anchor_top = 0.22
    left_caption.anchor_bottom = 0.29
    left_caption.add_theme_font_size_override("font_size", 22)
    left_caption.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
    menu_panel.add_child(left_caption)

    var car_caption := Label.new()
    car_caption.text = _car_display_name(selected_car_index)
    car_caption.anchor_left = 0.055
    car_caption.anchor_right = 0.43
    car_caption.anchor_top = 0.29
    car_caption.anchor_bottom = 0.35
    car_caption.add_theme_font_size_override("font_size", 17)
    car_caption.add_theme_color_override("font_color", Color(0.45, 0.82, 1.0))
    menu_panel.add_child(car_caption)

    var panel := Panel.new()
    panel.anchor_left = 0.65
    panel.anchor_right = 0.965
    panel.anchor_top = 0.19
    panel.anchor_bottom = 0.94
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.012, 0.03, 0.052, 0.91)
    panel_style.border_color = Color(0.18, 0.50, 0.72, 0.88)
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(14)
    panel.add_theme_stylebox_override("panel", panel_style)
    menu_panel.add_child(panel)

    var section := Label.new()
    section.text = "MAIN MENU"
    section.anchor_left = 0.68
    section.anchor_right = 0.94
    section.anchor_top = 0.215
    section.anchor_bottom = 0.28
    section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    section.add_theme_font_size_override("font_size", 25)
    section.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
    menu_panel.add_child(section)

    var hint := Label.new()
    hint.text = "CHOOSE YOUR NEXT DRIVE"
    hint.anchor_left = 0.68
    hint.anchor_right = 0.94
    hint.anchor_top = 0.275
    hint.anchor_bottom = 0.325
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 12)
    hint.add_theme_color_override("font_color", Color(0.58, 0.76, 0.90))
    menu_panel.add_child(hint)

    var start_button := _menu_button("▶   PLAY", 0.69, 0.35, 0.93, 0.47, 28, true)
    start_button.pressed.connect(_start_game)
    menu_panel.add_child(start_button)

    var garage_button := _menu_button("GARAGE  /  CHANGE CAR", 0.69, 0.49, 0.93, 0.585, 16, false)
    garage_button.pressed.connect(_open_car_selector)
    menu_panel.add_child(garage_button)
    car_color_button = garage_button

    var upgrade_button := _menu_button("UPGRADES", 0.69, 0.60, 0.93, 0.69, 17, false)
    upgrade_button.pressed.connect(_show_upgrades)
    menu_panel.add_child(upgrade_button)

    control_mode_button = _menu_button("STEERING: BUTTONS", 0.69, 0.705, 0.93, 0.795, 15, false)
    control_mode_button.pressed.connect(_toggle_control_mode)
    menu_panel.add_child(control_mode_button)

    var footer := Label.new()
    footer.text = "ENDLESS HIGHWAY  •  AVOID TRAFFIC"
    footer.anchor_left = 0.675
    footer.anchor_right = 0.945
    footer.anchor_top = 0.83
    footer.anchor_bottom = 0.90
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_font_size_override("font_size", 11)
    footer.add_theme_color_override("font_color", Color(0.57, 0.70, 0.81))
    menu_panel.add_child(footer)

func _menu_button(label_text: String, left: float, top: float, right: float, bottom: float, font_size: int, primary: bool) -> Button:
    var b := Button.new()
    b.text = label_text
    b.anchor_left = left
    b.anchor_top = top
    b.anchor_right = right
    b.anchor_bottom = bottom
    b.add_theme_font_size_override("font_size", font_size)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.02, 0.48, 0.86, 0.96) if primary else Color(0.07, 0.12, 0.18, 0.96)
    normal.border_color = Color(0.40, 0.82, 1.0, 1.0) if primary else Color(0.24, 0.48, 0.66, 0.95)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(10)
    normal.content_margin_left = 8
    normal.content_margin_right = 8
    b.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.05, 0.62, 1.0, 1.0) if primary else Color(0.10, 0.22, 0.32, 1.0)
    b.add_theme_stylebox_override("hover", hover)
    b.add_theme_color_override("font_color", Color.WHITE)
    b.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.70))
    return b

func _show_upgrades() -> void:
    # Simple working upgrade feedback for the current prototype.
    var message := "UPGRADES  •  ENGINE + HANDLING"
    message_label.text = message
    await get_tree().create_timer(2.0).timeout
    if is_instance_valid(message_label) and menu_active:
        message_label.text = ""
func _toggle_control_mode() -> void:
    tilt_mode = not tilt_mode
    control_mode_button.text = "STEERING: TILT" if tilt_mode else "STEERING: BUTTONS"
    touch_steer = 0.0
    active_touches.clear()
    _refresh_control_layout()

func _refresh_control_layout() -> void:
    if not is_instance_valid(left_button) or not is_instance_valid(right_button):
        return
    # Tilt mode: no steering arrows; brake is on the far left and gas on the far right.
    left_button.visible = not tilt_mode
    right_button.visible = not tilt_mode
    if tilt_mode:
        brake_button.anchor_left = 0.02
        brake_button.anchor_right = 0.16
        brake_button.text = "BRAKE"
    else:
        brake_button.anchor_left = 0.72
        brake_button.anchor_right = 0.84
        brake_button.text = "BRAKE"
    gas_button.anchor_left = 0.86
    gas_button.anchor_right = 0.98
    brake_button.queue_redraw()
    gas_button.queue_redraw()

func _open_car_selector() -> void:
    if is_instance_valid(selector_panel):
        selector_panel.queue_free()
    selector_active = true
    selector_panel = Control.new()
    selector_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    selector_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    selector_panel.z_index = 40
    ui_layer.add_child(selector_panel)

    var backdrop := ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color(0.008, 0.018, 0.032, 0.98)
    selector_panel.add_child(backdrop)

    var top := ColorRect.new()
    top.anchor_right = 1.0
    top.anchor_bottom = 0.12
    top.color = Color(0.02, 0.055, 0.085, 1.0)
    selector_panel.add_child(top)

    var heading := Label.new()
    heading.text = "GARAGE  /  CAR SELECT"
    heading.anchor_left = 0.035
    heading.anchor_top = 0.025
    heading.anchor_right = 0.62
    heading.anchor_bottom = 0.10
    heading.add_theme_font_size_override("font_size", 30)
    heading.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
    selector_panel.add_child(heading)

    # A separate 3D viewport gives the car a clean, full-screen studio preview.
    var preview_frame := Panel.new()
    preview_frame.anchor_left = 0.025
    preview_frame.anchor_top = 0.15
    preview_frame.anchor_right = 0.69
    preview_frame.anchor_bottom = 0.89
    var frame_style := StyleBoxFlat.new()
    frame_style.bg_color = Color(0.025, 0.055, 0.08, 0.95)
    frame_style.border_color = Color(0.10, 0.42, 0.62, 0.95)
    frame_style.set_border_width_all(2)
    frame_style.set_corner_radius_all(14)
    preview_frame.add_theme_stylebox_override("panel", frame_style)
    selector_panel.add_child(preview_frame)

    var viewport_container := SubViewportContainer.new()
    viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    viewport_container.stretch = true
    preview_frame.add_child(viewport_container)
    selector_viewport = SubViewport.new()
    selector_viewport.size = Vector2i(900, 650)
    selector_viewport.own_world_3d = true
    selector_viewport.transparent_bg = false
    selector_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport_container.add_child(selector_viewport)

    var preview_world := Node3D.new()
    selector_viewport.add_child(preview_world)
    var studio_env := WorldEnvironment.new()
    var studio_environment := Environment.new()
    studio_environment.background_mode = Environment.BG_COLOR
    studio_environment.background_color = Color(0.035, 0.075, 0.11)
    studio_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    studio_environment.ambient_light_color = Color(0.65, 0.75, 0.88)
    studio_environment.ambient_light_energy = 1.0
    studio_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    studio_env.environment = studio_environment
    preview_world.add_child(studio_env)

    var studio_floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(16.0, 16.0)
    studio_floor.mesh = floor_mesh
    studio_floor.position.y = -0.08
    studio_floor.material_override = _mat(Color(0.045, 0.065, 0.085), 0.28, 0.42)
    preview_world.add_child(studio_floor)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-38, -32, 0)
    key_light.light_energy = 2.0
    key_light.shadow_enabled = true
    preview_world.add_child(key_light)
    var fill_light := OmniLight3D.new()
    fill_light.position = Vector3(-4.0, 3.0, 2.0)
    fill_light.light_energy = 2.2
    fill_light.omni_range = 12.0
    preview_world.add_child(fill_light)
    var rim_light := OmniLight3D.new()
    rim_light.position = Vector3(3.0, 2.5, -4.0)
    rim_light.light_energy = 2.5
    rim_light.omni_range = 12.0
    preview_world.add_child(rim_light)

    var studio_camera := Camera3D.new()
    studio_camera.position = Vector3(4.2, 2.8, 5.5)
    studio_camera.look_at(Vector3(0, 0.58, 0), Vector3.UP)
    studio_camera.fov = 42.0
    preview_world.add_child(studio_camera)
    studio_camera.current = true

    selector_preview = _make_car(selected_car_color, true)
    selector_preview.position = Vector3.ZERO
    selector_preview.rotation.y = deg_to_rad(-25.0)
    preview_world.add_child(selector_preview)

    var hint := Label.new()
    hint.text = "DRAG TO ROTATE 360°"
    hint.anchor_left = 0.08
    hint.anchor_top = 0.81
    hint.anchor_right = 0.62
    hint.anchor_bottom = 0.87
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 16)
    hint.add_theme_color_override("font_color", Color(0.45, 0.84, 1.0))
    selector_panel.add_child(hint)

    var info := Label.new()
    info.text = "CHOOSE YOUR MACHINE"
    info.anchor_left = 0.72
    info.anchor_top = 0.15
    info.anchor_right = 0.97
    info.anchor_bottom = 0.205
    info.add_theme_font_size_override("font_size", 19)
    info.add_theme_color_override("font_color", Color(0.45, 0.84, 1.0))
    selector_panel.add_child(info)

    selector_car_label = Label.new()
    selector_car_label.anchor_left = 0.72
    selector_car_label.anchor_top = 0.205
    selector_car_label.anchor_right = 0.98
    selector_car_label.anchor_bottom = 0.265
    selector_car_label.add_theme_font_size_override("font_size", 20)
    selector_car_label.add_theme_color_override("font_color", Color.WHITE)
    selector_panel.add_child(selector_car_label)

    var previous := _menu_button("◀  PREVIOUS", 0.72, 0.275, 0.835, 0.34, 14, false)
    previous.pressed.connect(func(): _selector_change_car(-1))
    selector_panel.add_child(previous)
    var next := _menu_button("NEXT  ▶", 0.845, 0.275, 0.97, 0.34, 14, false)
    next.pressed.connect(func(): _selector_change_car(1))
    selector_panel.add_child(next)

    var tuning_title := Label.new()
    tuning_title.text = "TUNING"
    tuning_title.anchor_left = 0.72
    tuning_title.anchor_top = 0.37
    tuning_title.anchor_right = 0.96
    tuning_title.anchor_bottom = 0.415
    tuning_title.add_theme_font_size_override("font_size", 23)
    tuning_title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.18))
    selector_panel.add_child(tuning_title)

    selector_color_label = _selector_option_button("PAINT: " + tuning_color_names[paint_index % tuning_color_names.size()], 0.72, 0.425, 0.97, 0.49)
    selector_color_label.pressed.connect(_selector_cycle_color)
    selector_panel.add_child(selector_color_label)

    selector_bumper_label = _selector_option_button("FRONT / REAR BUMPER: %d" % (tuning_bumper + 1), 0.72, 0.50, 0.97, 0.565)
    selector_bumper_label.pressed.connect(_selector_cycle_bumper)
    selector_panel.add_child(selector_bumper_label)

    selector_rims_label = _selector_option_button("WHEELS: %d" % (tuning_rims + 1), 0.72, 0.575, 0.97, 0.64)
    selector_rims_label.pressed.connect(_selector_cycle_rims)
    selector_panel.add_child(selector_rims_label)

    selector_hood_label = _selector_option_button("HOOD: %d" % (tuning_hood + 1), 0.72, 0.65, 0.97, 0.715)
    selector_hood_label.pressed.connect(_selector_cycle_hood)
    selector_panel.add_child(selector_hood_label)

    selector_spoiler_label = _selector_option_button("SPOILER: %d" % (tuning_spoiler + 1), 0.72, 0.725, 0.97, 0.79)
    selector_spoiler_label.pressed.connect(_selector_cycle_spoiler)
    selector_panel.add_child(selector_spoiler_label)

    var select_button := _menu_button("SELECT CAR", 0.72, 0.82, 0.97, 0.895, 19, true)
    select_button.pressed.connect(_confirm_selected_car)
    selector_panel.add_child(select_button)
    var back_button := _menu_button("BACK TO MENU", 0.72, 0.91, 0.97, 0.97, 15, false)
    back_button.pressed.connect(_close_car_selector)
    selector_panel.add_child(back_button)
    _refresh_selector_preview()

func _selector_option_button(label_text: String, left: float, top: float, right: float, bottom: float) -> Button:
    return _menu_button(label_text, left, top, right, bottom, 13, false)

func _refresh_selector_preview() -> void:
    if not is_instance_valid(selector_panel):
        return
    if is_instance_valid(selector_preview):
        selector_preview.queue_free()
    selector_preview = _make_car(selected_car_color, true)
    selector_preview.position = Vector3.ZERO
    selector_preview.rotation.y = deg_to_rad(-25.0)
    var world_root := selector_viewport.get_child(0) as Node3D
    world_root.add_child(selector_preview)
    selector_car_label.text = _car_display_name(selected_car_index)
    selector_color_label.text = "PAINT: " + tuning_color_names[paint_index % tuning_color_names.size()]
    selector_bumper_label.text = "BUMPER KIT: %d" % (tuning_bumper + 1)
    selector_rims_label.text = "WHEELS: %d" % (tuning_rims + 1)
    selector_hood_label.text = "HOOD: %d" % (tuning_hood + 1)
    selector_spoiler_label.text = "SPOILER: %d" % (tuning_spoiler + 1)

func _selector_change_car(direction: int) -> void:
    selected_car_index = posmod(selected_car_index + direction, car_names.size())
    _refresh_selector_preview()

func _selector_cycle_color() -> void:
    paint_index = (paint_index + 1) % tuning_colors.size()
    selected_car_color = tuning_colors[paint_index]
    # Preserve the chosen vehicle separately from paint colour.
    _refresh_selector_preview()

func _selector_cycle_bumper() -> void:
    tuning_bumper = (tuning_bumper + 1) % 3
    _refresh_selector_preview()

func _selector_cycle_rims() -> void:
    tuning_rims = (tuning_rims + 1) % 4
    _refresh_selector_preview()

func _selector_cycle_hood() -> void:
    tuning_hood = (tuning_hood + 1) % 3
    _refresh_selector_preview()

func _selector_cycle_spoiler() -> void:
    tuning_spoiler = (tuning_spoiler + 1) % 4
    _refresh_selector_preview()

func _tint_vehicle_paint(node: Node, color: Color) -> void:
    # Recolor bright painted body surfaces on imported cars while preserving dark rubber, glass, and trim.
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            for surface_index in range(mesh_instance.mesh.get_surface_count()):
                var material := mesh_instance.get_active_material(surface_index)
                if material is StandardMaterial3D:
                    var source := material as StandardMaterial3D
                    var material_name := source.resource_name.to_lower()
                    var excluded := ["glass", "window", "tire", "tyre", "rubber", "wheel", "rim", "chrome", "metal", "light", "lamp"]
                    var keep_original := false
                    for word in excluded:
                        if material_name.contains(word):
                            keep_original = true
                            break
                    if not keep_original and source.albedo_color.get_luminance() > 0.20:
                        var painted := source.duplicate() as StandardMaterial3D
                        if painted != null:
                            painted.albedo_color = color
                            painted.metallic = maxf(painted.metallic, 0.22)
                            painted.roughness = minf(painted.roughness, 0.34)
                            mesh_instance.set_surface_override_material(surface_index, painted)
    for child in node.get_children():
        _tint_vehicle_paint(child, color)

func _add_tuning_parts(root: Node3D, color: Color) -> void:
    # Modular visual body-kit choices. Parts are procedural and remain free of external paid assets.
    var bumper_width := 1.82 + float(tuning_bumper) * 0.10
    var lip_depth := 0.28 + float(tuning_bumper) * 0.08
    var front_lip := _box(Vector3(bumper_width, 0.055, lip_depth), Color(0.018, 0.021, 0.025))
    front_lip.position = Vector3(0, 0.285, -1.58 - float(tuning_bumper) * 0.04)
    root.add_child(front_lip)
    var rear_diffuser := _box(Vector3(1.28 + float(tuning_bumper) * 0.10, 0.12, 0.20 + float(tuning_bumper) * 0.04), Color(0.025, 0.028, 0.032))
    rear_diffuser.position = Vector3(0, 0.285, 1.56 + float(tuning_bumper) * 0.035)
    root.add_child(rear_diffuser)

    var rim_colors: Array[Color] = [Color(0.72, 0.75, 0.78), Color(0.12, 0.13, 0.15), Color(0.78, 0.45, 0.12), Color(0.85, 0.86, 0.88)]
    for side in [-1.0, 1.0]:
        for z in [-1.02, 1.02]:
            var rim := _cylinder(0.19 + float(tuning_rims) * 0.012, 0.215, rim_colors[tuning_rims])
            rim.rotation.z = PI / 2.0
            rim.position = Vector3(side * 1.01, 0.34, z)
            root.add_child(rim)
            for spoke_index in range(5 + tuning_rims):
                var spoke := _box(Vector3(0.035, 0.22, 0.045), rim_colors[tuning_rims])
                spoke.position = Vector3(side * 1.125, 0.34, z)
                spoke.rotation.x = float(spoke_index) * TAU / float(5 + tuning_rims)
                root.add_child(spoke)

    var hood_color := color.lightened(0.06 + float(tuning_hood) * 0.06)
    var hood := _box(Vector3(0.52 + float(tuning_hood) * 0.12, 0.035, 0.30 + float(tuning_hood) * 0.09), hood_color)
    hood.position = Vector3(0, 0.94, -0.96)
    root.add_child(hood)
    if tuning_hood > 0:
        for side in [-1.0, 1.0]:
            var vent := _box(Vector3(0.10, 0.018, 0.23), Color(0.025, 0.028, 0.032))
            vent.position = Vector3(side * (0.15 + float(tuning_hood) * 0.06), 0.97, -0.97)
            root.add_child(vent)

    var spoiler_width := 1.45 + float(tuning_spoiler) * 0.20
    var spoiler_height := 0.07 + float(tuning_spoiler) * 0.025
    var spoiler := _box(Vector3(spoiler_width, spoiler_height, 0.22), color.darkened(0.10))
    spoiler.position = Vector3(0, 1.02 + float(tuning_spoiler) * 0.10, 1.42)
    root.add_child(spoiler)
    if tuning_spoiler > 1:
        for side in [-1.0, 1.0]:
            var support := _box(Vector3(0.045, 0.20, 0.07), Color(0.07, 0.08, 0.09))
            support.position = Vector3(side * 0.48, 0.99 + float(tuning_spoiler) * 0.08, 1.34)
            root.add_child(support)

func _confirm_selected_car() -> void:
    if is_instance_valid(player):
        player.queue_free()
    player = _make_car(selected_car_color, true)
    player.position = Vector3(0, 0.0, PLAYER_Z)
    add_child(player)
    car_color_button.text = "GARAGE: " + _car_display_name(selected_car_index)
    _close_car_selector()

func _close_car_selector() -> void:
    selector_active = false
    if is_instance_valid(selector_panel):
        selector_panel.queue_free()
    selector_panel = null


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
        steer = clamp(Input.get_accelerometer().x / 5.0, -1.0, 1.0)
        if abs(touch_steer) > 0.1:
            steer = touch_steer
    if Input.is_action_pressed("ui_left"):
        steer = -1.0
    elif Input.is_action_pressed("ui_right"):
        steer = 1.0
    steering = move_toward(steering, steer, delta * 2.5)
    player.position.x = clamp(player.position.x + steering * delta * 6.0, -5.1, 5.1)
    if gas_pressed and not brake_pressed:
        speed = min(MAX_SPEED, speed + delta * 17.0)
    elif brake_pressed and not gas_pressed:
        speed = max(MIN_SPEED, speed - delta * 28.0)
    elif gas_pressed and brake_pressed:
        speed = move_toward(speed, MIN_SPEED, delta * 35.0)
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

func _input(event: InputEvent) -> void:
    if selector_active and is_instance_valid(selector_preview):
        if event is InputEventScreenTouch:
            selector_dragging = event.pressed
            selector_last_x = event.position.x
        elif event is InputEventScreenDrag and selector_dragging:
            selector_preview.rotation.y += (event.position.x - selector_last_x) * 0.012
            selector_last_x = event.position.x
        elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
            selector_dragging = event.pressed
            selector_last_x = event.position.x
        elif event is InputEventMouseMotion and selector_dragging:
            selector_preview.rotation.y += (event.position.x - selector_last_x) * 0.012
            selector_last_x = event.position.x
    # Track each finger separately so steering and pedals work at the same time.
    var changed := false
    if event is InputEventScreenTouch:
        if event.pressed:
            active_touches[event.index] = event.position
        else:
            active_touches.erase(event.index)
        changed = true
    elif event is InputEventScreenDrag:
        if active_touches.has(event.index):
            active_touches[event.index] = event.position
            changed = true
    if changed:
        _refresh_touch_controls()

func _refresh_touch_controls() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return
    # Steering is tracked per finger; pedal hold state comes from button_down/up.
    var left_down := false
    var right_down := false
    for finger in active_touches:
        var p: Vector2 = active_touches[finger]
        var nx := p.x / viewport_size.x
        var ny := p.y / viewport_size.y
        if ny >= 0.68 and not tilt_mode and nx < 0.145:
            left_down = true
        elif ny >= 0.68 and not tilt_mode and nx >= 0.145 and nx < 0.29:
            right_down = true
    if left_down and not right_down:
        touch_steer = -1.0
    elif right_down and not left_down:
        touch_steer = 1.0
    else:
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
