extends Node3D
## HEXWORKS: Cursed Academy - automation / idle game on a floating island.
## One script: world building, economy, events, boss raids, UI, save.

const M = preload("res://scripts/m3d.gd")
const FX = preload("res://shaders/fx.gdshader")
const R := 24.0          # island radius
const SR := 14.5         # station ring radius
const WA = [0.0, PI * 0.5, PI, PI * 1.5]
const WINGS = [
	{"name": "Cursed Forest", "col": Color("3dffb0"), "boss": "Thornmaw", "hero": "vex", "master": "Vex"},
	{"name": "Ember Courtyard", "col": Color("ff7a00"), "boss": "Cinder Warden", "hero": "brann", "master": "Brann"},
	{"name": "Forbidden Library", "col": Color("00e5ff"), "boss": "The Librarian", "hero": "lyra", "master": "Lyra"},
	{"name": "Heart of the Academy", "col": Color("ff2bd6"), "boss": "Corrupted Archmage", "hero": "vex", "master": "The Headmaster"},
]
const ST = ["Soul Well", "Cauldron", "Rune Altar", "Portal"]
const BASE = [1.0, 1.2, 0.9, 1.5]
const C0 = [10.0, 14.0, 18.0, 12.0]
const VAL = [1.0, 20.0, 400.0, 8000.0]
const CM = [1.0, 40.0, 1600.0, 64000.0]
const UNLOCK = [0.0, 5e4, 5e6, 5e8]
const BOSS_HP = [6e3, 4e5, 3e7, 2.5e9]
const BOSSP = [
	{"seal": 9.0, "slam": 0.0, "shields": [0.5], "orbs": 4},
	{"seal": 8.0, "slam": 12.0, "shields": [0.5], "orbs": 4},
	{"seal": 7.0, "slam": 0.0, "shields": [0.66, 0.33], "orbs": 6},
	{"seal": 6.0, "slam": 11.0, "shields": [0.7, 0.4], "orbs": 6},
]
const MILE = [10, 25, 50, 100, 150, 200, 300, 400, 500]
const RELICS = [
	{"name": "Soul Lens", "desc": "+50% all production"},
	{"name": "Quick Hands", "desc": "Taps give 2x souls"},
	{"name": "Battle Choir", "desc": "+25% boss damage"},
	{"name": "Wisp Magnet", "desc": "Stray souls collect themselves", "max": 1, "cost": 5},
]
const TUT = [
	"Welcome, Headmaster! This floating academy turns lost souls into power.\n\nDrag to look around. Scroll (or pinch) to zoom.",
	"Tap the glowing SOUL WELL under the arrow to gather souls by hand.\n\nGoal: collect 15 souls.",
	"A wing is a production line:\nWell > Cauldron > Altar > Portal.\nIt only runs as fast as its SLOWEST station (red !).\n\nGoal: upgrade the station under the arrow (buttons at the bottom).",
	"Stray souls drift over the island.\n\nGoal: tap the floating wisp under the arrow.",
	"Masters run a wing for you: production x2 and automatic upgrades.\n\nGoal: hire Vex (400 souls) with the button at the bottom left.",
	"Each wing has a BOSS. Press 'Fight Thornmaw' when you make about 100 souls per second.\n\nIn the fight: tap purple-sealed stations, tap the rune orbs when the boss is shielded, and use Surge / Ward / Soulburst.",
	"Beating a boss opens the next wing and gives RUNES for permanent Relics (top right).\n\nGolden ravens give x5 production - tap them!\nCurse clouds slow a station - tap it 3 times.\n\nGood luck!",
]
var tut := 0
var tut_hold := 0.0
var tut_lv := 4
var tut_w := 0
var wisp_taken := 0
var cam_moved := false
var tut_panel: Control
var l_tut: Label
var l_tut_t: Label
var b_tut: Button
var tut_arrow: Node3D
const SUF = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
const MOON := Vector3(0.45, 0.5, -0.74)
const SAVE := "user://hexworks.json"

# --- state (saved) ---
var souls := 0.0
var total := 0.0
var runes := 0
var grads := 0
var lv = [[1, 1, 1, 1], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
var master = [false, false, false, false]
var auto = [true, true, true, true]
var boss_lv = [0, 0, 0, 0]
var relic = [0, 0, 0, 0]
var muted := false

# --- runtime ---
var sel := 0
var buy_mode := 0
var frenzy := 0.0
var time := 0.0
var smoke := false
var low := false
var noise := FastNoiseLite.new()
var cam: Camera3D
var yaw := 0.0
var pitch := 0.62
var dist := 50.0
var yaw_t := 0.0
var pitch_t := 0.62
var dist_t := 50.0
var focus := Vector3(0, 2.5, 0)
var focus_t := Vector3(0, 2.5, 0)
var shake := 0.0
var idle_t := 0.0
var sts = []            # sts[w][i] = station dict
var leys = []
var orbs = []
var heroes = []
var tower_orbs = []
var imps = []
var ravens = []
var rocks = []
var lanterns = []
var wisps = []
var wisp_t := 4.0
var gold = null
var gold_t := 60.0
var curse_t := 70.0
var auto_t := 0.0
var save_t := 20.0
var B = null            # boss fight dict
var surge := 0.0
var ward := 0.0
var cd = [0.0, 0.0, 0.0]
var bolt_t := 0.0
var pressing := false
var dragged := false
var press_pos := Vector2.ZERO
var touches = {}
var pinch_d := 0.0
var pad_pos := Vector2(640, 360)
var pad_on := false
var dot_tex: GradientTexture2D
var music: AudioStreamPlayer
# ui
var hud: Control
var l_souls: Label
var l_sps: Label
var l_runes: Label
var l_wing: Label
var b_master: Button
var b_boss: Button
var b_buy: Button
var b_unlock: Button
var b_mute: Button
var left: Control
var cards: Control
var card_ui = []
var abil: Control
var abil_b = []
var boss_panel: Control
var l_bname: Label
var bar: ProgressBar
var l_btime: Label
var l_toast: Label
var toast_t := 0.0
var popup: Control
var relic_b = []
var relic_l = []
var b_grad: Button
var cursor: Control


func _ready() -> void:
	smoke = "--smoke" in OS.get_cmdline_user_args()
	low = OS.has_feature("web") or OS.has_feature("mobile") or "--low" in OS.get_cmdline_user_args()
	randomize()
	noise.seed = 7
	noise.frequency = 0.05
	dot_tex = GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	dot_tex.gradient = g
	dot_tex.fill = GradientTexture2D.FILL_RADIAL
	dot_tex.fill_from = Vector2(0.5, 0.5)
	dot_tex.fill_to = Vector2(1.0, 0.5)
	dot_tex.width = 32
	dot_tex.height = 32
	_env()
	_island()
	_academy()
	_wings()
	_decor()
	_life()
	_ui()
	_audio()
	if not smoke:
		_load()
	for w in 4:
		_refresh_wing(w)
	tut_arrow = Node3D.new()
	M.add(tut_arrow, M.cyl(0.55, 0.0, 1.1, 8), M.toon(Color(1.0, 0.8, 0.25), 2.6, false), Vector3.ZERO)
	add_child(tut_arrow)


func _tut_next() -> void:
	tut += 1
	tut_hold = 0.0
	tut_lv = lv[0][0] + lv[0][1] + lv[0][2] + lv[0][3]
	tut_w = wisp_taken
	if tut >= TUT.size():
		tut = -1
		_toast("Tutorial done. Open it again any time with the Help button.")
		_save()


func _tut_tick(dt: float) -> void:
	tut_panel.visible = tut >= 0 and B == null
	tut_arrow.visible = false
	if tut < 0 or B != null:
		return
	l_tut_t.text = "Tutorial  %d / %d" % [tut + 1, TUT.size()]
	l_tut.text = TUT[tut]
	b_tut.text = "Next" if tut < TUT.size() - 1 else "Got it"
	var done := false
	var tp = null
	var off := 5.4
	match tut:
		0:
			done = cam_moved
		1:
			tp = sts[0][0]["pos"]
			done = total >= 15.0
		2:
			tp = sts[0][bottleneck(0)]["pos"]
			done = lv[0][0] + lv[0][1] + lv[0][2] + lv[0][3] > tut_lv
		3:
			if wisps.is_empty():
				_spawn_wisp()
			tp = wisps[0]["n"].position
			off = 1.6
			done = wisp_taken > tut_w
		4:
			done = master[0]
	if tp != null:
		tut_arrow.visible = true
		tut_arrow.position = tp + Vector3(0, off + sin(time * 5.0) * 0.35, 0)
		tut_arrow.rotation.y += dt * 2.5
	if done:
		tut_hold += dt
		if tut_hold > (2.5 if tut == 0 else 1.0):
			_sfx("levelup", -12.0)
			_tut_next()
	else:
		tut_hold = 0.0


# ------------------------------------------------------------ world

func gy(x: float, z: float) -> float:
	return noise.get_noise_2d(x, z) * 0.45


func _env() -> void:
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	sm.set_shader_parameter("moon_dir", MOON)
	sky.sky_material = sm
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.36, 0.75)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.75
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.15
	e.adjustment_contrast = 1.06
	if not low:
		e.ssao_enabled = true
		e.ssao_intensity = 2.5
		e.volumetric_fog_enabled = true
		e.volumetric_fog_density = 0.0028
		e.volumetric_fog_albedo = Color(0.55, 0.4, 0.9)
		e.volumetric_fog_emission = Color(0.04, 0.02, 0.09)
		e.volumetric_fog_length = 140.0
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.7, 1.0)
	moon.light_energy = 1.25
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 130.0
	add_child(moon)
	moon.look_at_from_position(MOON * 60.0, Vector3.ZERO)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.75, 0.45, 0.95)
	fill.light_energy = 0.45
	add_child(fill)
	fill.look_at_from_position(Vector3(-30, 25, 45), Vector3.ZERO)
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.far = 700.0
	if not low:
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_far_enabled = true
		ca.dof_blur_far_distance = 95.0
		ca.dof_blur_far_transition = 70.0
		ca.dof_blur_amount = 0.07
		cam.attributes = ca
	add_child(cam)
	for k in 2:
		var pm := PlaneMesh.new()
		pm.size = Vector2(700, 700)
		var mm := ShaderMaterial.new()
		mm.shader = load("res://shaders/mist.gdshader")
		mm.set_shader_parameter("seed", k * 13.7)
		if k == 1:
			mm.set_shader_parameter("c1", Color(0.35, 0.1, 0.4))
			mm.set_shader_parameter("c2", Color(0.1, 0.2, 0.55))
		M.add(self, pm, mm, Vector3(0, -16.0 - k * 9.0, 0))


func _ground_col(p: Vector3, r: float) -> Color:
	var n := noise.get_noise_2d(p.x * 3.0 + 50.0, p.z * 3.0)
	var c := Color(0.09, 0.24, 0.25).lerp(Color(0.22, 0.12, 0.34), clampf(n * 1.6 + 0.5, 0.0, 1.0))
	var stone := Color(0.33, 0.30, 0.42)
	var path := clampf(1.0 - absf(r - SR) / 2.2, 0.0, 1.0)
	path = maxf(path, clampf((8.2 - r) / 1.5, 0.0, 1.0))
	c = c.lerp(stone, clampf(path * 1.6, 0.0, 1.0))
	return c.lightened(randf() * 0.05)


func _island() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rn := 26
	var sn := 64
	var dn := 9
	var grid = []
	for i in rn + dn + 1:
		var row = []
		for j in sn:
			var a := TAU * j / sn
			var wob := 1.0 + 0.07 * noise.get_noise_2d(sin(a) * 60.0, cos(a) * 60.0)
			var p: Vector3
			var c: Color
			if i <= rn:
				var r := R * float(i) / rn * lerpf(1.0, wob, float(i) / rn)
				p = Vector3(sin(a) * r, 0, cos(a) * r)
				p.y = gy(p.x, p.z)
				c = _ground_col(p, r)
			else:
				var k := float(i - rn) / dn
				var r2 := R * wob * pow(1.0 - k, 0.7) * (1.0 + 0.16 * noise.get_noise_2d(j * 9.0, i * 17.0))
				p = Vector3(sin(a) * r2, -k * 18.0 - 0.5 + noise.get_noise_2d(j * 5.0, i * 31.0), cos(a) * r2)
				c = Color(0.19, 0.13, 0.28).lerp(Color(0.06, 0.04, 0.11), k)
				if i % 2 == 0:
					c = c.lightened(0.07)
			row.append([p, c])
		grid.append(row)
	for i in rn + dn:
		for j in sn:
			var j1 := (j + 1) % sn
			for q in [[grid[i][j], grid[i + 1][j1], grid[i + 1][j]], [grid[i][j], grid[i][j1], grid[i + 1][j1]]]:
				for v in q:
					st.set_color(v[1])
					st.add_vertex(v[0])
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	M.add(self, st.commit(), mat, Vector3.ZERO)


func _academy() -> void:
	var stone := M.toon(Color("4d4368"))
	var stone2 := M.toon(Color("3a3250"))
	var roof := M.toon(Color("234462"))
	var win := M.toon(Color("ffc45e"), 2.6, false)
	var a := Node3D.new()
	add_child(a)
	M.add(a, M.cyl(6.6, 7.2, 0.7, 24), stone2, Vector3(0, 0.3, 0))
	M.add(a, M.box(6.4, 4.6, 5.0), stone, Vector3(0, 2.9, 0))
	M.add(a, M.cyl(0.0, 4.6, 2.8, 4), roof, Vector3(0, 6.6, 0), Vector3(0, PI / 4, 0))
	M.add(a, M.cyl(1.5, 1.8, 12.0, 12), stone, Vector3(0, 6.0, -1.2))
	M.add(a, M.cyl(0.0, 2.3, 4.4, 12), roof, Vector3(0, 14.2, -1.2))
	M.add(a, M.sphere(0.75), M.toon(Color("ff2bd6"), 3.0, false), Vector3(0, 17.4, -1.2))
	M.light(a, Vector3(0, 17.4, -1.2), Color("ff2bd6"), 3.0, 16.0)
	for s in 4:
		var ang := s * PI * 0.5
		for k in 3:
			M.add(a, M.box(0.5, 0.9, 0.12), win, Vector3(sin(ang) * 1.72, 5.0 + k * 2.4, -1.2 + cos(ang) * 1.72), Vector3(0, ang, 0))
	for k in 5:
		M.add(a, M.box(0.55, 1.1, 0.1), win, Vector3(-2.4 + k * 1.2, 3.4, 2.52))
		M.add(a, M.box(0.1, 1.1, 0.55), win, Vector3(3.22 * (1 if k % 2 == 0 else -1), 3.4, -1.6 + k * 0.8))
	M.add(a, M.box(1.3, 2.0, 0.14), M.toon(Color("1c1626")), Vector3(0, 1.6, 2.53))
	var corners = [Vector3(3.5, 0, 2.9), Vector3(3.5, 0, -2.9), Vector3(-3.5, 0, -2.9), Vector3(-3.5, 0, 2.9)]
	for w in 4:
		var c: Vector3 = corners[w]
		M.add(a, M.cyl(1.0, 1.2, 7.4, 10), stone, c + Vector3(0, 3.7, 0))
		M.add(a, M.cyl(0.0, 1.5, 2.8, 10), roof, c + Vector3(0, 8.7, 0))
		M.add(a, M.box(0.45, 0.8, 0.1), win, c + Vector3(0, 5.6, 1.08 * signf(c.z)))
		var o := M.add(a, M.sphere(0.34), M.toon(WINGS[w]["col"], 3.0, false), c + Vector3(0, 10.5, 0))
		tower_orbs.append(o)
	M.light(a, Vector3(0, 3.0, 4.5), Color("ffb060"), 1.6, 8.0)


func _fxp(parent: Node3D, size: float, mode: int, col: Color, pos: Vector3, power := 1.0) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	var sm := ShaderMaterial.new()
	sm.shader = FX
	sm.set_shader_parameter("col", col)
	sm.set_shader_parameter("mode", mode)
	sm.set_shader_parameter("power", power)
	var mi := M.add(parent, pm, sm, pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _pmat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(col.r * 2.0, col.g * 2.0, col.b * 2.0)
	m.albedo_texture = dot_tex
	return m


func _parts(parent: Node3D, col: Color, n: int, life: float, speed: float, rad: float, pos: Vector3, size := 0.22) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = rad
	p.direction = Vector3.UP
	p.spread = 18.0
	p.gravity = Vector3(0, 0.3, 0)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _pmat(col)
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.position = pos
	parent.add_child(p)
	return p


func _burst(pos: Vector3, col: Color, n := 14, speed := 4.0) -> void:
	var p := _parts(self, col, n, 0.7, speed, 0.2, pos, 0.3)
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.gravity = Vector3(0, -5, 0)
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)


func _station(w: int, i: int) -> Dictionary:
	var col: Color = WINGS[w]["col"]
	var stone := M.toon(Color("5a5074"))
	var dark := M.toon(Color("25202f"))
	var ang: float = WA[w] + (i - 1.5) * 0.3
	var pos := Vector3(sin(ang) * SR, 0, cos(ang) * SR)
	pos.y = gy(pos.x, pos.z)
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = ang
	add_child(n)
	var fx := Node3D.new()
	n.add_child(fx)
	var spin: Node3D = null
	match i:
		0:
			M.add(n, M.cyl(1.25, 1.45, 0.85, 12), stone, Vector3(0, 0.42, 0))
			M.add(n, M.cyl(1.02, 1.02, 0.06, 16), M.flat(Color(0.02, 0.01, 0.04)), Vector3(0, 0.83, 0))
			for sx in [-1.2, 1.2]:
				M.add(n, M.box(0.16, 1.9, 0.16), dark, Vector3(sx, 1.4, 0))
			M.add(n, M.box(2.7, 0.16, 0.22), dark, Vector3(0, 2.36, 0))
			M.add(n, M.cyl(0.0, 1.7, 0.9, 4), M.toon(Color("2b3f5e")), Vector3(0, 2.9, 0), Vector3(0, PI / 4, 0))
			_fxp(fx, 2.1, 2, col, Vector3(0, 0.88, 0), 1.2)
			_parts(fx, col, 14, 1.8, 1.5, 0.6, Vector3(0, 1.0, 0))
		1:
			for k in 3:
				M.add(n, M.box(0.18, 0.7, 0.18), dark, Vector3(sin(k * TAU / 3) * 0.8, 0.35, cos(k * TAU / 3) * 0.8))
			M.add(n, M.sphere(1.2), dark, Vector3(0, 1.25, 0), Vector3.ZERO, Vector3(1, 0.82, 1))
			M.add(n, M.torus(0.85, 1.08), M.toon(Color("6b6480")), Vector3(0, 1.95, 0))
			_fxp(fx, 1.9, 2, col, Vector3(0, 2.0, 0), 1.3)
			for k in 3:
				M.add(fx, M.cyl(0.0, 0.22, 0.6, 6), M.toon(Color("ff8a2a"), 3.0, false), Vector3(sin(k * 2.1) * 0.35, 0.3, cos(k * 2.1) * 0.35))
			_parts(fx, col.lightened(0.3), 16, 2.2, 1.2, 0.7, Vector3(0, 2.1, 0), 0.3)
		2:
			M.add(n, M.cyl(1.5, 1.75, 0.36, 8), stone, Vector3(0, 0.18, 0))
			M.add(n, M.cyl(1.0, 1.2, 0.36, 8), stone, Vector3(0, 0.54, 0))
			M.add(n, M.cyl(0.3, 0.42, 1.1, 8), dark, Vector3(0, 1.25, 0))
			spin = Node3D.new()
			spin.position = Vector3(0, 2.6, 0)
			fx.add_child(spin)
			var cm := M.toon(col, 2.4, false)
			M.add(spin, M.cyl(0.0, 0.48, 0.85, 5), cm, Vector3(0, 0.42, 0))
			M.add(spin, M.cyl(0.0, 0.48, 0.85, 5), cm, Vector3(0, -0.42, 0), Vector3(PI, 0, 0))
			_fxp(fx, 4.6, 3, col, Vector3(0, 0.08, 0), 1.0)
			_parts(fx, col, 10, 1.6, 0.8, 0.9, Vector3(0, 1.8, 0))
		3:
			M.add(n, M.box(3.2, 0.45, 1.3), stone, Vector3(0, 0.22, 0))
			M.add(n, M.torus(1.3, 1.68), stone, Vector3(0, 2.25, 0), Vector3(PI / 2, 0, 0))
			var sw := _fxp(fx, 2.9, 1, col, Vector3(0, 2.25, 0), 1.2)
			sw.rotation.x = PI / 2
			_parts(fx, col, 12, 1.4, 1.0, 1.0, Vector3(0, 2.2, 0))
	var li := M.light(fx, Vector3(0, 2.4, 0.6), col, 1.6, 6.0)
	var warn := Label3D.new()
	warn.text = "!"
	warn.font_size = 140
	warn.pixel_size = 0.012
	warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warn.no_depth_test = true
	warn.modulate = Color(1, 0.25, 0.2)
	warn.outline_size = 24
	warn.position = Vector3(0, 4.6, 0)
	warn.visible = false
	n.add_child(warn)
	return {"n": n, "fx": fx, "pos": pos, "seal": 0, "curse": 0, "warn": warn, "punch": 0.0, "spin": spin, "base": 1.0, "seal_n": null, "curse_n": null, "light": li}


func _wings() -> void:
	for w in 4:
		var col: Color = WINGS[w]["col"]
		var row = []
		for i in 4:
			row.append(_station(w, i))
		sts.append(row)
		# ley line ribbon on the ground
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts = []
		for k in 41:
			var a: float = WA[w] + lerpf(-0.45, 0.45, k / 40.0)
			var c := Vector3(sin(a) * SR, 0, cos(a) * SR)
			var side := Vector3(sin(a), 0, cos(a)) * 0.38
			pts.append([c - side, c + side, k * 0.4])
		for k in 40:
			var p0 = pts[k]
			var p1 = pts[k + 1]
			for q in [[p0[0], 0.0, p0[2]], [p0[1], 1.0, p0[2]], [p1[0], 0.0, p1[2]], [p0[1], 1.0, p0[2]], [p1[1], 1.0, p1[2]], [p1[0], 0.0, p1[2]]]:
				var v: Vector3 = q[0]
				st.set_uv(Vector2(q[1], q[2]))
				st.add_vertex(Vector3(v.x, gy(v.x, v.z) + 0.14, v.z))
		var sm := ShaderMaterial.new()
		sm.shader = FX
		sm.set_shader_parameter("col", col)
		sm.set_shader_parameter("mode", 0)
		var ley := M.add(self, st.commit(), sm, Vector3.ZERO)
		ley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		leys.append(ley)
		# soul orbs flowing through the stations
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = M.sphere(0.17, 8)
		mm.instance_count = 36
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = M.glow(col, 0.95, 2.2)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		orbs.append(mm)
		# wing master
		var h: Node3D = M.hero(WINGS[w]["hero"], "idle")
		var hp := Vector3(sin(WA[w]) * 11.9, 0, cos(WA[w]) * 11.9)
		hp.y = gy(hp.x, hp.z)
		h.position = hp
		h.rotation.y = WA[w]
		h.scale = Vector3.ONE * 1.6
		add_child(h)
		heroes.append(h)
		for k in 5:
			imps.append(_imp(w))


func _imp(w: int) -> Dictionary:
	var col: Color = WINGS[w]["col"]
	var n := Node3D.new()
	M.add(n, M.capsule(0.22, 0.62), M.toon(col.darkened(0.62)), Vector3(0, 0.36, 0))
	M.add(n, M.cyl(0.0, 0.29, 0.5, 8), M.toon(col.darkened(0.45)), Vector3(0, 0.9, 0))
	M.eyes(n, Vector3(0, 0.6, 0.19), 0.09, col, 0.045)
	add_child(n)
	var s: Dictionary = sts[w][randi() % 4]
	n.position = s["pos"] + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	return {"n": n, "w": w, "tgt": n.position, "t": randf() * 6.0, "k": imps.size() % 5}


func _decor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in [[1.15, 1.7, 1.7], [0.88, 1.5, 2.65], [0.56, 1.3, 3.5]]:
		st.append_from(M.cyl(0.0, c[0], c[1], 7), 0, Transform3D(Basis(), Vector3(0, c[2], 0)))
	var fmesh := st.commit()
	var n := 150 if low else 300
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.use_colors = true
	fm.mesh = fmesh
	fm.instance_count = n
	var tm := MultiMesh.new()
	tm.transform_format = MultiMesh.TRANSFORM_3D
	tm.mesh = M.cyl(0.14, 0.22, 1.3, 6)
	tm.instance_count = n
	var pal = [Color("5a2d8c"), Color("1f7a7a"), Color("a02a7a"), Color("1d5a4a"), Color("3b2a78")]
	for i in n:
		var a := randf() * TAU
		var r := randf_range(18.4, 22.8) if randf() < 0.85 else randf_range(9.0, 11.0)
		var p := Vector3(sin(a) * r, 0, cos(a) * r)
		p.y = gy(p.x, p.z)
		var s := randf_range(0.55, 1.15) * (1.0 if r > 12.0 else 0.6)
		var b := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(s, s * randf_range(0.9, 1.3), s))
		fm.set_instance_transform(i, Transform3D(b, p))
		tm.set_instance_transform(i, Transform3D(b, p + Vector3(0, 0.6 * s, 0)))
		var c: Color = pal[randi() % pal.size()]
		fm.set_instance_color(i, c.darkened(0.25 + randf() * 0.3))
	var fi := MultiMeshInstance3D.new()
	fi.multimesh = fm
	var fsm := ShaderMaterial.new()
	fsm.shader = load("res://shaders/foliage.gdshader")
	fi.material_override = fsm
	add_child(fi)
	var ti := MultiMeshInstance3D.new()
	ti.multimesh = tm
	ti.material_override = M.toon(Color("2a1c2e"), 0.0, false)
	add_child(ti)
	# glowing crystals
	for i in 40:
		var a := randf() * TAU
		var r := randf_range(17.5, 22.0) if i % 3 > 0 else randf_range(9.0, 11.2)
		var p := Vector3(sin(a) * r, 0, cos(a) * r)
		p.y = gy(p.x, p.z) + 0.4
		var w := int(fposmod(a + PI * 0.25, TAU) / (PI * 0.5)) % 4
		var s := randf_range(0.6, 1.5)
		M.add(self, M.cyl(0.0, 0.26, 1.2, 5), M.toon(WINGS[w]["col"], 2.2, false), p, Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3)), Vector3(s, s, s))
	# lanterns along the inner edge of the road
	for i in 12:
		var a := i * TAU / 12.0 + 0.26
		var p := Vector3(sin(a) * 12.2, 0, cos(a) * 12.2)
		p.y = gy(p.x, p.z)
		M.add(self, M.box(0.12, 1.9, 0.12), M.toon(Color("25202f")), p + Vector3(0, 0.95, 0))
		M.add(self, M.sphere(0.2, 10), M.toon(Color("ffc060"), 3.0, false), p + Vector3(0, 2.05, 0))
		if not low or i % 2 == 0:
			lanterns.append(M.light(self, p + Vector3(0, 2.2, 0), Color("ffb050"), 1.1, 5.0))
	# floating rocks around the island
	for i in 12:
		var a := randf() * TAU
		var r := randf_range(31.0, 52.0)
		var n3 := Node3D.new()
		n3.position = Vector3(sin(a) * r, randf_range(-9.0, 7.0), cos(a) * r)
		var s := randf_range(1.0, 3.2)
		M.add(n3, M.sphere(1.0, 7), M.toon(Color("2c2440")), Vector3.ZERO, Vector3(randf(), randf(), randf()), Vector3(s, s * 0.6, s))
		M.add(n3, M.cyl(0.0, 0.9, 1.6, 6), M.toon(Color("1d182c")), Vector3(0, -s * 0.75, 0), Vector3(PI, 0, 0), Vector3(s, s, s))
		if i % 3 == 0:
			M.add(n3, M.cyl(0.0, 0.25, 1.1, 5), M.toon(Color("9a6bff"), 2.4, false), Vector3(0, s * 0.7, 0))
		add_child(n3)
		rocks.append({"n": n3, "y": n3.position.y, "ph": randf() * TAU})


func _life() -> void:
	# fireflies over the whole island
	var f := _parts(self, Color(0.7, 1.0, 0.6), 60 if low else 140, 6.0, 0.4, 1.0, Vector3(0, 2.5, 0), 0.16)
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	f.emission_box_extents = Vector3(22, 2.5, 22)
	f.spread = 180.0
	f.gravity = Vector3.ZERO
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.5, Color.WHITE)
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	f.color_ramp = g
	for i in 7:
		ravens.append(_raven(Color("15101c"), false))


func _raven(col: Color, glowing: bool) -> Dictionary:
	var n := Node3D.new()
	var mat = M.toon(col, 3.0, false) if glowing else M.toon(col, 0.0, false)
	M.add(n, M.box(0.16, 0.13, 0.55), mat, Vector3.ZERO)
	var wl := Node3D.new()
	var wr := Node3D.new()
	n.add_child(wl)
	n.add_child(wr)
	M.add(wl, M.box(0.7, 0.03, 0.32), mat, Vector3(0.38, 0, 0))
	M.add(wr, M.box(0.7, 0.03, 0.32), mat, Vector3(-0.38, 0, 0))
	if glowing:
		n.scale = Vector3.ONE * 2.0
		M.light(n, Vector3.ZERO, col, 2.0, 6.0)
	add_child(n)
	return {"n": n, "wl": wl, "wr": wr, "a": randf() * TAU, "r": randf_range(8.0, 15.0), "y": randf_range(11.0, 18.0), "sp": randf_range(0.25, 0.5) * (1 if randf() < 0.5 else -1), "t": 0.0}


# ------------------------------------------------------------ economy

func miles(l: int) -> int:
	var n := 0
	for m in MILE:
		if l >= m:
			n += 1
	return n


func next_mile(l: int) -> int:
	for m in MILE:
		if l < m:
			return m
	return 0


func st_rate(w: int, i: int) -> float:
	var l: int = lv[w][i]
	if l <= 0:
		return 0.0
	var r: float = BASE[i] * l * pow(2.0, miles(l))
	if sts[w][i]["curse"] > 0:
		r *= 0.25
	return r


func bottleneck(w: int) -> int:
	var b := 0
	for i in 4:
		if st_rate(w, i) < st_rate(w, b):
			b = i
	return b


func flow(w: int) -> float:
	return st_rate(w, bottleneck(w))


func wing_sps(w: int) -> float:
	return flow(w) * VAL[w] * (2.0 if master[w] else 1.0)


func gmult() -> float:
	return (1.0 + 0.5 * relic[0]) * (1.0 + 0.25 * grads) * (5.0 if frenzy > 0.0 else 1.0)


func sps() -> float:
	var s := 0.0
	for w in 4:
		s += wing_sps(w)
	return s * gmult()


func cost1(w: int, i: int) -> float:
	return C0[i] * CM[w] * pow(1.15, lv[w][i] - 1)


func buy_n(w: int, i: int) -> int:
	if buy_mode == 0:
		return 1
	if buy_mode == 1:
		return 10
	return maxi(1, int(floor(log(souls * 0.15 / cost1(w, i) + 1.0) / log(1.15))))


func cost_n(w: int, i: int, n: int) -> float:
	return cost1(w, i) * (pow(1.15, n) - 1.0) / 0.15


func fmt(v: float) -> String:
	if v < 1000.0:
		return str(int(v)) if v >= 100.0 or v == floor(v) else "%.1f" % v
	var e := int(floor(log(v) / log(1000.0)))
	e = mini(e, SUF.size() - 1)
	return "%.2f%s" % [v / pow(1000.0, e), SUF[e]]


func _earn(x: float) -> void:
	souls += x
	total += x


func _buy(w: int, i: int, n := -1) -> bool:
	if lv[w][i] <= 0:
		return false
	if n < 0:
		n = buy_n(w, i)
	var c := cost_n(w, i, n)
	if souls < c:
		return false
	souls -= c
	var before := miles(lv[w][i])
	lv[w][i] += n
	var s: Dictionary = sts[w][i]
	s["punch"] = 1.0
	if miles(lv[w][i]) > before:
		_sfx("levelup", -10.0)
		_burst(s["pos"] + Vector3(0, 2, 0), WINGS[w]["col"], 30, 6.0)
		_float("x2!", s["pos"] + Vector3(0, 4, 0), Color(1, 0.85, 0.3))
	_refresh_wing(w)
	return true


func _unlock(w: int) -> void:
	if lv[w][0] > 0 or souls < UNLOCK[w] or boss_lv[w - 1] <= 0:
		return
	souls -= UNLOCK[w]
	lv[w] = [1, 1, 1, 1]
	_refresh_wing(w)
	_sfx("portal", -6.0)
	for i in 4:
		sts[w][i]["punch"] = 1.5
		_burst(sts[w][i]["pos"] + Vector3(0, 1.5, 0), WINGS[w]["col"], 24, 6.0)
	_toast("%s is open!" % WINGS[w]["name"])


func _hire(w: int) -> void:
	if lv[w][0] <= 0:
		return
	if master[w]:
		auto[w] = not auto[w]
	elif souls >= 400.0 * CM[w]:
		souls -= 400.0 * CM[w]
		master[w] = true
		_sfx("shrine", -8.0)
		_toast("%s now runs %s: production x2 and automatic upgrades." % [WINGS[w]["master"], WINGS[w]["name"]])
		_burst(heroes[w].position + Vector3(0, 1.5, 0), WINGS[w]["col"], 30, 5.0)
	_refresh_wing(w)


func _refresh_wing(w: int) -> void:
	var on: bool = lv[w][0] > 0
	leys[w].visible = on
	tower_orbs[w].visible = on
	heroes[w].visible = master[w]
	for i in 4:
		var s: Dictionary = sts[w][i]
		s["fx"].visible = on
		s["base"] = 0.8 if not on else 1.0 + minf(lv[w][i], 300.0) / 300.0 * 0.45
	for im in imps:
		if im["w"] == w:
			var need := 0
			if on:
				need = clampi(2 + (lv[w][0] + lv[w][1] + lv[w][2] + lv[w][3]) / 25, 2, 5)
			im["n"].visible = im["k"] < need


func tap_value() -> float:
	return maxf(1.0, sps() * 0.15) * pow(2.0, relic[1])


func _tap_station(w: int, i: int) -> void:
	var s: Dictionary = sts[w][i]
	var p: Vector3 = s["pos"] + Vector3(0, 2.0, 0)
	if lv[w][0] <= 0:
		_select(w)
		return
	s["punch"] = 1.0
	if s["seal"] > 0:
		s["seal"] -= 1
		_sfx("hit", -6.0, randf_range(0.9, 1.2))
		_burst(p, Color(0.7, 0.3, 1.0), 10, 5.0)
		if s["seal"] <= 0:
			_clear_seal(s)
			_sfx("crit", -6.0)
		return
	if s["curse"] > 0:
		s["curse"] -= 1
		_sfx("hit", -6.0, randf_range(0.9, 1.2))
		_burst(p, Color(0.6, 0.2, 0.9), 10, 5.0)
		if s["curse"] <= 0:
			if s["curse_n"] != null:
				s["curse_n"].queue_free()
				s["curse_n"] = null
			var rw := sps() * 15.0
			_earn(rw)
			_float("Cleansed! +" + fmt(rw), p, Color(0.8, 0.6, 1.0))
			_sfx("chest", -8.0)
		return
	sel = w
	var g := tap_value()
	_earn(g)
	_float("+" + fmt(g), p + Vector3(0, 1.0, 0), WINGS[w]["col"])
	_burst(p, WINGS[w]["col"], 8, 3.5)
	_sfx("select", -9.0, randf_range(0.85, 1.3))


func _clear_seal(s: Dictionary) -> void:
	s["seal"] = 0
	if s["seal_n"] != null:
		s["seal_n"].queue_free()
		s["seal_n"] = null


func _graduate_gain() -> int:
	if boss_lv[3] <= 0 and total < 1e9:
		return 0
	return maxi(3, int(pow(total / 1e7, 0.3)))


func _graduate() -> void:
	var g := _graduate_gain()
	if g <= 0 or B != null:
		return
	runes += g
	grads += 1
	souls = 0.0
	total = 0.0
	lv = [[1, 1, 1, 1], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
	master = [false, false, false, false]
	boss_lv = [0, 0, 0, 0]
	for w in 4:
		for i in 4:
			_clear_seal(sts[w][i])
			sts[w][i]["curse"] = 0
			if sts[w][i]["curse_n"] != null:
				sts[w][i]["curse_n"].queue_free()
				sts[w][i]["curse_n"] = null
		_refresh_wing(w)
	_select(0)
	popup.visible = false
	_sfx("ultimate", -6.0)
	_toast("Graduated! +%d runes, +25%% production forever." % g, 6.0)
	_save()


# ------------------------------------------------------------ events

func _spawn_wisp() -> void:
	var a := randf() * TAU
	var r := randf_range(8.0, 21.0)
	var n := Node3D.new()
	n.position = Vector3(sin(a) * r, gy(sin(a) * r, cos(a) * r) + 1.8, cos(a) * r)
	M.add(n, M.sphere(0.3, 10), M.glow(Color(0.7, 1.0, 0.95), 0.95, 2.4), Vector3.ZERO)
	_parts(n, Color(0.6, 1.0, 0.9), 8, 1.0, 0.6, 0.25, Vector3.ZERO)
	add_child(n)
	wisps.append({"n": n, "t": 0.0, "y": n.position.y})


func _take_wisp(wd: Dictionary) -> void:
	var g := maxf(15.0, sps() * 25.0)
	_earn(g)
	_float("+" + fmt(g), wd["n"].position, Color(0.7, 1.0, 0.95))
	_burst(wd["n"].position, Color(0.7, 1.0, 0.95), 16, 4.0)
	_sfx("pickup", -8.0, randf_range(0.9, 1.2))
	wisp_taken += 1
	wd["n"].queue_free()
	wisps.erase(wd)


func _take_gold() -> void:
	if gold == null:
		return
	frenzy = 20.0
	_burst(gold["n"].position, Color(1, 0.8, 0.2), 40, 7.0)
	_sfx("ultimate", -6.0)
	_toast("Golden raven! Production x5 for 20 seconds.")
	gold["n"].queue_free()
	gold = null


func _curse_random() -> void:
	var pool = []
	for w in 4:
		if lv[w][0] > 0:
			for i in 4:
				if sts[w][i]["curse"] == 0 and sts[w][i]["seal"] == 0:
					pool.append(sts[w][i])
	if pool.is_empty():
		return
	var s: Dictionary = pool[randi() % pool.size()]
	s["curse"] = 3
	var n := Node3D.new()
	n.position = Vector3(0, 3.6, 0)
	var cm := M.glow(Color(0.22, 0.0, 0.32), 0.85, 1.0)
	for k in 4:
		M.add(n, M.sphere(0.7, 8), cm, Vector3(sin(k * 1.6) * 0.8, cos(k * 2.3) * 0.25, cos(k * 1.6) * 0.5))
	_parts(n, Color(0.6, 0.2, 1.0), 10, 1.2, 1.4, 0.8, Vector3(0, -0.4, 0)).direction = Vector3.DOWN
	s["n"].add_child(n)
	s["curse_n"] = n
	_sfx("roar", -14.0, 1.5)
	_toast("A curse cloud is choking a station. Tap it 3 times!")


# ------------------------------------------------------------ boss raid

func _boss_model(w: int, alt: bool) -> Node3D:
	var n: Node3D
	match w:
		0:
			n = M.boss("slam" if alt else "idle", false)
			n.scale = Vector3.ONE * 4.0
		1:
			n = M.enemy("brute", true, "attack" if alt else "idle")
			n.scale = Vector3.ONE * 6.0
		2:
			n = M.enemy("wisp", true, "attack" if alt else "idle")
			n.scale = Vector3.ONE * 6.5
		_:
			n = M.boss("howl" if alt else "idle", true)
			n.scale = Vector3.ONE * 5.5
	return n


func boss_start(w: int) -> void:
	if B != null or lv[w][0] <= 0:
		return
	var a: float = WA[w]
	var root := Node3D.new()
	root.position = Vector3(sin(a) * 34.0, -26.0, cos(a) * 34.0)
	root.rotation.y = a + PI
	add_child(root)
	var idle := _boss_model(w, false)
	var alt := _boss_model(w, true)
	alt.visible = false
	root.add_child(idle)
	root.add_child(alt)
	M.light(root, Vector3(0, 9, 7), WINGS[w]["col"], 6.0, 30.0)
	var shield := M.add(root, M.sphere(1.0, 20), M.glow(Color(0.6, 0.3, 1.0), 0.09, 1.5), Vector3(0, 6, 0), Vector3.ZERO, Vector3.ONE * 9.5)
	shield.visible = false
	var hp: float = BOSS_HP[w] * pow(5.0, boss_lv[w])
	B = {"w": w, "hp": hp, "max": hp, "t": 80.0, "root": root, "idle": idle, "alt": alt, "shield": shield,
		"shields": BOSSP[w]["shields"].duplicate(), "orbs": [], "seal_t": 5.0, "slam_t": BOSSP[w]["slam"], "slam": null, "end": 0.0, "hit": 0.0}
	create_tween().tween_property(root, "position:y", -4.0, 2.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	yaw_t += wrapf(a + 1.15 - yaw_t, -PI, PI)
	pitch_t = 0.3
	dist_t = 66.0
	focus_t = Vector3(sin(a) * 16.0, 3.0, cos(a) * 16.0)
	cd = [0.0, 0.0, 0.0]
	shake = 0.6
	_sfx("roar", -3.0)
	_music("boss")
	_toast("%s rises from the mist! Your stations fire on their own - break seals and shields." % WINGS[w]["boss"], 6.0)


func _boss_center() -> Vector3:
	return B["root"].position + Vector3(0, 6.5, 0)


func _boss_dps() -> float:
	var sealed := 0
	for w in 4:
		for i in 4:
			if sts[w][i]["seal"] > 0:
				sealed += 1
	return sps() * (1.0 + 0.25 * relic[2]) * (3.0 if surge > 0.0 else 1.0) * pow(0.75, sealed)


func _boss_pose(alt: bool) -> void:
	B["idle"].visible = not alt
	B["alt"].visible = alt


func _spawn_orbs() -> void:
	var n: int = BOSSP[B["w"]]["orbs"]
	for k in n:
		var o := Node3D.new()
		M.add(o, M.sphere(0.9, 12), M.toon(Color(0.75, 0.4, 1.0), 2.6, false), Vector3.ZERO)
		add_child(o)
		B["orbs"].append({"n": o, "a": k * TAU / n, "ph": randf() * TAU})
	B["shield"].visible = true
	_sfx("block", -4.0, 0.7)
	_toast("Shield up! Tap the %d rune orbs circling the boss." % n)


func _pop_orb(o: Dictionary) -> void:
	_burst(o["n"].position, Color(0.8, 0.5, 1.0), 20, 6.0)
	_sfx("crit", -6.0, randf_range(0.9, 1.2))
	o["n"].queue_free()
	B["orbs"].erase(o)
	if B["orbs"].is_empty():
		B["shield"].visible = false
		shake = 0.4
		_sfx("ultimate", -8.0)


func _seal_random() -> void:
	var pool = []
	for w in 4:
		if lv[w][0] > 0:
			for i in 4:
				if sts[w][i]["seal"] == 0:
					pool.append(sts[w][i])
	if pool.is_empty():
		return
	_seal(pool[randi() % pool.size()], 3)


func _seal(s: Dictionary, n: int) -> void:
	s["seal"] = n
	if s["seal_n"] == null:
		s["seal_n"] = M.add(s["n"], M.sphere(2.1, 14), M.glow(Color(0.55, 0.15, 1.0), 0.38, 1.5), Vector3(0, 1.5, 0))
	_sfx("shoot", -8.0, 0.6)


func _ability(k: int) -> void:
	if B == null or cd[k] > 0.0 or B["end"] > 0.0:
		return
	match k:
		0:
			surge = 6.0
			cd[0] = 20.0
			_sfx("levelup", -6.0)
			_toast("Surge! Damage x3.")
		1:
			ward = 3.0
			cd[1] = 12.0
			_sfx("block", -4.0)
			for w in 4:
				for i in 4:
					if sts[w][i]["seal"] > 0:
						_burst(sts[w][i]["pos"] + Vector3(0, 2, 0), Color(0.6, 0.8, 1.0), 12, 5.0)
						_clear_seal(sts[w][i])
			_toast("Ward! Seals broken, next slam blocked.")
		2:
			cd[2] = 30.0
			_sfx("ultimate", -5.0)
			shake = 0.5
			if not B["orbs"].is_empty():
				_pop_orb(B["orbs"][0])
			else:
				B["hp"] -= _boss_dps() * 8.0
				B["hit"] = 1.0
			_burst(_boss_center(), Color.WHITE, 40, 9.0)


func _bolt() -> void:
	var pool = []
	for w in 4:
		if lv[w][0] > 0:
			for i in 4:
				if sts[w][i]["seal"] == 0:
					pool.append([sts[w][i], w])
	if pool.is_empty():
		return
	var pk = pool[randi() % pool.size()]
	var col: Color = WINGS[pk[1]]["col"]
	var mi := M.add(self, M.sphere(0.32 if surge <= 0.0 else 0.5, 8), M.glow(col, 0.95, 2.6), pk[0]["pos"] + Vector3(0, 2.5, 0))
	var to := _boss_center() + Vector3(randf_range(-2, 2), randf_range(-3, 3), randf_range(-2, 2))
	var tw := create_tween()
	tw.tween_property(mi, "position", to, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_burst(to, col, 5, 3.0)
		mi.queue_free()
		if B != null:
			B["hit"] = maxf(B["hit"], 0.5))


func _boss_tick(dt: float) -> void:
	var w: int = B["w"]
	var p: Dictionary = BOSSP[w]
	var root: Node3D = B["root"]
	B["hit"] = maxf(0.0, B["hit"] - dt * 4.0)
	root.scale = Vector3.ONE * (1.0 + B["hit"] * 0.03)
	root.rotation.z = sin(time * 0.9) * 0.03
	if B["end"] > 0.0:
		B["end"] -= dt
		if B["end"] <= 0.0:
			root.queue_free()
			B = null
			pitch_t = 0.62
			dist_t = 50.0
			focus_t = Vector3(0, 2.5, 0)
			_music("forest")
		return
	B["t"] -= dt
	var enraged: bool = B["t"] < 20.0
	if B["orbs"].is_empty():
		B["hp"] -= _boss_dps() * dt
		bolt_t -= dt
		if bolt_t <= 0.0:
			bolt_t = 0.07 if surge > 0.0 else 0.14
			_bolt()
	if not B["shields"].is_empty() and B["hp"] <= B["max"] * B["shields"][0]:
		B["shields"].pop_front()
		_spawn_orbs()
	var bc := _boss_center()
	for o in B["orbs"]:
		o["a"] += dt * (1.3 if w >= 2 else 0.9)
		o["n"].position = bc + Vector3(cos(o["a"]) * 10.5, sin(o["a"] * 1.7 + o["ph"]) * 3.5, sin(o["a"]) * 10.5)
	B["seal_t"] -= dt
	if B["seal_t"] <= 0.0:
		B["seal_t"] = p["seal"] * (0.5 if enraged else 1.0)
		_seal_random()
	if p["slam"] > 0.0:
		if B["slam"] == null:
			B["slam_t"] -= dt
			if B["slam_t"] <= 0.0:
				var ws = []
				for k in 4:
					if lv[k][0] > 0:
						ws.append(k)
				var s: Dictionary = sts[ws[randi() % ws.size()]][randi() % 4]
				var ring := _fxp(self, 9.0, 3, Color(1.0, 0.15, 0.1), s["pos"] + Vector3(0, 0.25, 0), 1.6)
				B["slam"] = {"s": s, "t": 2.6, "ring": ring}
				_boss_pose(true)
				_sfx("roar", -8.0, 1.2)
				_toast("SLAM incoming! Use Ward.", 2.5)
		else:
			var sl: Dictionary = B["slam"]
			sl["t"] -= dt
			sl["ring"].material_override.set_shader_parameter("fill", 1.0 - sl["t"] / 2.6)
			if sl["t"] <= 0.0:
				if ward > 0.0:
					_toast("Blocked!")
					_sfx("block", -3.0)
				else:
					_seal(sl["s"], 5)
					B["t"] -= 5.0
					shake = 1.0
					_sfx("hit", -2.0, 0.6)
					_toast("Slam hit! Station stunned and 5 seconds lost.")
				_burst(sl["s"]["pos"] + Vector3(0, 1, 0), Color(1, 0.3, 0.2), 40, 9.0)
				sl["ring"].queue_free()
				B["slam"] = null
				B["slam_t"] = p["slam"] * (0.6 if enraged else 1.0)
				_boss_pose(false)
	if B["hp"] <= 0.0:
		_boss_end(true)
	elif B["t"] <= 0.0:
		_boss_end(false)


func _boss_end(won: bool) -> void:
	var w: int = B["w"]
	for o in B["orbs"]:
		o["n"].queue_free()
	B["orbs"].clear()
	B["shield"].visible = false
	if B["slam"] != null:
		B["slam"]["ring"].queue_free()
		B["slam"] = null
	for a in 4:
		for i in 4:
			_clear_seal(sts[a][i])
	surge = 0.0
	ward = 0.0
	B["end"] = 3.0
	create_tween().tween_property(B["root"], "position:y", -34.0, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if won:
		var first: bool = boss_lv[w] == 0
		var g := (w + 1) * (3 if first else 1)
		runes += g
		boss_lv[w] += 1
		var rw := sps() * 120.0
		_earn(rw)
		shake = 1.0
		for k in 6:
			_burst(_boss_center() + Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)), WINGS[w]["col"], 30, 10.0)
		_sfx("chest", -3.0)
		_sfx("levelup", -5.0)
		var msg := "%s defeated! +%d runes, +%s souls." % [WINGS[w]["boss"], g, fmt(rw)]
		if first and w < 3:
			msg += " %s can now be unlocked." % WINGS[w + 1]["name"]
		elif first:
			msg += " You can now Graduate (Relics menu)."
		_toast(msg, 7.0)
		_save()
	else:
		_sfx("roar", -4.0, 0.8)
		_toast("%s escaped. Upgrade your stations and try again." % WINGS[w]["boss"], 6.0)


# ------------------------------------------------------------ frame

func _process(dt: float) -> void:
	time += dt
	_earn(sps() * dt)
	frenzy = maxf(0.0, frenzy - dt)
	surge = maxf(0.0, surge - dt)
	ward = maxf(0.0, ward - dt)
	for k in 3:
		cd[k] = maxf(0.0, cd[k] - dt)
	# masters upgrade the bottleneck on their own
	auto_t -= dt
	if auto_t <= 0.0:
		auto_t = 0.35
		for w in 4:
			if master[w] and auto[w]:
				for k in 5:
					if not _buy(w, bottleneck(w), 1):
						break
	_anim(dt)
	_events(dt)
	if B != null:
		_boss_tick(dt)
	_pad(dt)
	_cam(dt)
	_ui_tick(dt)
	_tut_tick(dt)
	if smoke:
		_smoke()
	else:
		save_t -= dt
		if save_t <= 0.0:
			save_t = 20.0
			_save()


func _anim(dt: float) -> void:
	var speed := 2.0 if frenzy > 0.0 else 1.0
	for w in 4:
		var on: bool = lv[w][0] > 0
		var bn := bottleneck(w)
		for i in 4:
			var s: Dictionary = sts[w][i]
			s["punch"] = maxf(0.0, s["punch"] - dt * 5.0)
			var sc: float = s["base"] * (1.0 + s["punch"] * 0.14)
			s["n"].scale = Vector3(sc, sc * (1.0 + s["punch"] * 0.1), sc)
			if s["spin"] != null:
				s["spin"].rotation.y += dt * 1.5 * speed
				s["spin"].position.y = 2.6 + sin(time * 2.0 + w) * 0.2
			s["light"].light_energy = 1.6 + sin(time * 5.0 + i * 2.0 + w) * 0.3
			s["warn"].visible = on and i == bn and s["seal"] == 0 and fmod(time, 1.0) < 0.7 and (st_rate(w, (i + 1) % 4) > st_rate(w, i) * 1.01 or s["curse"] > 0)
			if s["seal_n"] != null:
				s["seal_n"].rotation.y += dt * 2.0
			if s["curse_n"] != null:
				s["curse_n"].rotation.y += dt * 0.8
		var mm: MultiMesh = orbs[w]
		if not on:
			mm.visible_instance_count = 0
			continue
		var n := clampi(6 + int(log(flow(w) + 1.0) * 3.0), 6, 36)
		mm.visible_instance_count = n
		for k in n:
			var t := fposmod(time * 0.11 * speed + float(k) / n, 1.0) * 3.0
			var seg := mini(int(t), 2)
			var f := t - seg
			var a: Vector3 = sts[w][seg]["pos"]
			var b: Vector3 = sts[w][seg + 1]["pos"]
			var sz := 0.7 + seg * 0.4
			mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(sz, sz, sz)), a.lerp(b, f) + Vector3(0, 1.6 + sin(f * PI) * 1.8, 0)))
		heroes[w].position.y = gy(heroes[w].position.x, heroes[w].position.z) + absf(sin(time * 1.6 + w)) * 0.12
	for im in imps:
		var n3: Node3D = im["n"]
		if not n3.visible:
			continue
		im["t"] += dt
		var to: Vector3 = im["tgt"] - n3.position
		to.y = 0.0
		if to.length() < 0.3:
			var s2: Dictionary = sts[im["w"]][randi() % 4]
			var off := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized() * randf_range(2.2, 3.2)
			im["tgt"] = s2["pos"] + off
		else:
			var d := to.normalized()
			n3.position += d * dt * 2.0 * speed
			n3.rotation.y = lerp_angle(n3.rotation.y, atan2(d.x, d.z), dt * 8.0)
		n3.position.y = gy(n3.position.x, n3.position.z) + absf(sin(im["t"] * 9.0)) * 0.22
	for rv in ravens:
		_fly(rv, dt)
	for rk in rocks:
		rk["n"].position.y = rk["y"] + sin(time * 0.4 + rk["ph"]) * 0.8
		rk["n"].rotation.y += dt * 0.05
	for i in lanterns.size():
		lanterns[i].light_energy = 1.1 + sin(time * 9.0 + i * 1.7) * 0.15 + sin(time * 23.0 + i) * 0.08


func _fly(rv: Dictionary, dt: float) -> void:
	rv["a"] += dt * rv["sp"]
	var n: Node3D = rv["n"]
	var a: float = rv["a"]
	n.position = Vector3(sin(a) * rv["r"], rv["y"] + sin(a * 3.0) * 1.2, cos(a) * rv["r"])
	n.rotation.y = a + (PI * 0.5 if rv["sp"] > 0.0 else -PI * 0.5)
	var fl := sin(time * 11.0 + rv["r"]) * 0.7
	rv["wl"].rotation.z = fl
	rv["wr"].rotation.z = -fl


func _events(dt: float) -> void:
	wisp_t -= dt
	if wisp_t <= 0.0:
		wisp_t = randf_range(5.0, 9.0)
		if wisps.size() < 5:
			_spawn_wisp()
	for wd in wisps.duplicate():
		wd["t"] += dt
		wd["n"].position.y = wd["y"] + sin(wd["t"] * 2.0) * 0.4
		if relic[3] > 0 and wd["t"] > 2.0:
			_take_wisp(wd)
		elif wd["t"] > 16.0:
			wd["n"].queue_free()
			wisps.erase(wd)
	gold_t -= dt
	if gold == null and gold_t <= 0.0:
		gold_t = randf_range(80.0, 130.0)
		gold = _raven(Color(1.0, 0.8, 0.2), true)
		gold["r"] = 17.0
		gold["y"] = 7.0
		gold["sp"] = 0.45
		_sfx("shrine", -12.0, 1.4)
	if gold != null:
		_fly(gold, dt)
		gold["t"] += dt
		if gold["t"] > 16.0:
			gold["n"].queue_free()
			gold = null
	if B == null:
		curse_t -= dt
		if curse_t <= 0.0:
			curse_t = randf_range(55.0, 90.0)
			if total > 2000.0:
				_curse_random()


func _cam(dt: float) -> void:
	idle_t += dt
	if idle_t > 15.0 and B == null:
		yaw_t += dt * 0.03
	var k := 1.0 - exp(-dt * 6.0)
	yaw = lerpf(yaw, yaw_t, k)
	pitch = lerpf(pitch, pitch_t, k)
	dist = lerpf(dist, dist_t, k)
	focus = focus.lerp(focus_t, 1.0 - exp(-dt * 3.0))
	shake = maxf(0.0, shake - dt * 2.0)
	var c := focus + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.5
	var p := c + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.look_at_from_position(p, c)


func _select(w: int) -> void:
	sel = posmod(w, 4)
	if B == null:
		yaw_t += wrapf(WA[sel] - yaw_t, -PI, PI)
	idle_t = 0.0


# ------------------------------------------------------------ input

func _scr(p: Vector3) -> Vector2:
	var vp := get_viewport()
	return cam.unproject_position(p) / Vector2(vp.size) * vp.get_visible_rect().size


func _pick(mp: Vector2) -> void:
	var list = []     # [pos, world radius, callable, priority]
	for wd in wisps:
		list.append([wd["n"].position, 1.0, _take_wisp.bind(wd), 0.4])
	if gold != null:
		list.append([gold["n"].position, 1.6, _take_gold, 0.4])
	if B != null and B["end"] <= 0.0:
		for o in B["orbs"]:
			list.append([o["n"].position, 1.6, _pop_orb.bind(o), 0.4])
		list.append([_boss_center(), 6.0, _tap_boss, 1.5])
	for w in 4:
		for i in 4:
			list.append([sts[w][i]["pos"] + Vector3(0, 1.4, 0), 1.9, _tap_station.bind(w, i), 1.0])
	var vr := get_viewport().get_visible_rect().size
	var best = null
	var bd := 1e9
	for c in list:
		var p: Vector3 = c[0]
		if cam.is_position_behind(p):
			continue
		var d := cam.global_position.distance_to(p)
		var pr: float = maxf(26.0, c[1] * vr.y / (2.0 * tan(deg_to_rad(cam.fov) * 0.5) * d))
		var dd := _scr(p).distance_to(mp)
		if dd < pr and dd / pr * c[3] < bd:
			bd = dd / pr * c[3]
			best = c
	if best != null:
		best[2].call()


func _tap_boss() -> void:
	if B["orbs"].is_empty():
		B["hp"] -= _boss_dps() * 0.3
		B["hit"] = 1.0
		_burst(_boss_center(), Color.WHITE, 8, 6.0)
		_sfx("hit", -8.0, randf_range(0.9, 1.2))
	else:
		_sfx("block", -8.0, 1.4)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		idle_t = 0.0
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist_t = maxf(24.0, dist_t - 3.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist_t = minf(85.0, dist_t + 3.0)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				press_pos = e.position
				dragged = false
				pressing = true
			else:
				if pressing and not dragged:
					_pick(e.position)
				pressing = false
	elif e is InputEventMouseMotion:
		if not (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			pressing = false
		elif pressing:
			if e.position.distance_to(press_pos) > 8.0:
				dragged = true
			if dragged and touches.size() < 2:
				yaw_t -= e.relative.x * 0.006
				cam_moved = true
				pitch_t = clampf(pitch_t + e.relative.y * 0.004, 0.15, 1.25)
				idle_t = 0.0
	elif e is InputEventScreenTouch:
		if e.pressed:
			touches[e.index] = e.position
		else:
			touches.erase(e.index)
		pinch_d = 0.0
	elif e is InputEventScreenDrag:
		touches[e.index] = e.position
		if touches.size() == 2:
			var v = touches.values()
			var d: float = v[0].distance_to(v[1])
			if pinch_d > 0.0 and d > 1.0:
				dist_t = clampf(dist_t * pinch_d / d, 24.0, 85.0)
			pinch_d = d
			dragged = true
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1: _select(0)
			KEY_2: _select(1)
			KEY_3: _select(2)
			KEY_4: _select(3)
			KEY_Q: _ability(0)
			KEY_W: _ability(1)
			KEY_E: _ability(2)
			KEY_SPACE: _tap_station(sel, 0)
			KEY_ESCAPE: popup.visible = false
			KEY_F11: _fullscreen()
	elif e is InputEventJoypadButton and e.pressed:
		pad_on = true
		match e.button_index:
			JOY_BUTTON_A: _pad_click()
			JOY_BUTTON_LEFT_SHOULDER: _select(sel - 1)
			JOY_BUTTON_RIGHT_SHOULDER: _select(sel + 1)
			JOY_BUTTON_X: _ability(0)
			JOY_BUTTON_Y: _ability(1)
			JOY_BUTTON_B:
				if popup.visible:
					popup.visible = false
				else:
					_ability(2)


func _fullscreen() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _pad(dt: float) -> void:
	var l := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var r := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var vr := get_viewport().get_visible_rect().size
	if l.length() > 0.2:
		pad_on = true
		pad_pos = (pad_pos + l * 650.0 * dt).clamp(Vector2.ZERO, vr)
		var m := InputEventMouseMotion.new()
		m.position = pad_pos
		m.global_position = pad_pos
		get_viewport().push_input(m, true)
	if r.length() > 0.2:
		yaw_t -= r.x * dt * 2.0
		pitch_t = clampf(pitch_t + r.y * dt * 1.2, 0.15, 1.25)
		idle_t = 0.0
	var z := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if absf(z) > 0.2:
		dist_t = clampf(dist_t - z * dt * 30.0, 24.0, 85.0)
	cursor.visible = pad_on
	cursor.position = pad_pos - Vector2(7, 7)


func _pad_click() -> void:
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.position = pad_pos
		b.global_position = pad_pos
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		get_viewport().push_input(b, true)
		await get_tree().process_frame


# ------------------------------------------------------------ ui

func _sb(bg: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


func _lbl(parent: Control, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _btn(parent: Control, text: String, cb: Callable, minsize := Vector2(0, 40)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minsize
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	b.pressed.connect(func(): _sfx("confirm", -12.0))
	parent.add_child(b)
	return b


func _pin(c: Control, preset: int, gh: int, gv: int, off: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.grow_horizontal = gh
	c.grow_vertical = gv
	c.offset_left = off.x
	c.offset_right = off.x
	c.offset_top = off.y
	c.offset_bottom = off.y


func _ui() -> void:
	var gold_c := Color(0.85, 0.66, 0.32, 0.6)
	var th := Theme.new()
	th.default_font_size = 15
	th.set_stylebox("panel", "PanelContainer", _sb(Color(0.05, 0.03, 0.11, 0.86), gold_c, 12, 12))
	th.set_stylebox("normal", "Button", _sb(Color(0.17, 0.10, 0.32), gold_c, 8, 8))
	th.set_stylebox("hover", "Button", _sb(Color(0.28, 0.17, 0.5), Color(1, 0.85, 0.5), 8, 8))
	th.set_stylebox("pressed", "Button", _sb(Color(0.4, 0.22, 0.66), Color(1, 0.9, 0.6), 8, 8))
	th.set_stylebox("disabled", "Button", _sb(Color(0.09, 0.08, 0.13, 0.9), Color(0.3, 0.28, 0.35), 8, 8))
	th.set_color("font_color", "Button", Color(1, 0.93, 0.8))
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.56))
	th.set_stylebox("background", "ProgressBar", _sb(Color(0.08, 0.04, 0.1), gold_c, 6, 0))
	th.set_stylebox("fill", "ProgressBar", _sb(Color(0.85, 0.12, 0.3), Color(1, 0.5, 0.5), 6, 0))
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.theme = th
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Palatino Linotype", "Georgia", "Times New Roman"])
	serif.font_weight = 700
	# top-left: currency
	var tl := PanelContainer.new()
	hud.add_child(tl)
	tl.position = Vector2(16, 16)
	var v := VBoxContainer.new()
	tl.add_child(v)
	var title := _lbl(v, "HEXWORKS", 20, Color(1.0, 0.82, 0.45))
	title.add_theme_font_override("font", serif)
	l_souls = _lbl(v, "0", 36, Color(0.9, 1.0, 0.97))
	l_souls.add_theme_font_override("font", serif)
	l_sps = _lbl(v, "", 15, Color(0.45, 1.0, 0.8))
	l_runes = _lbl(v, "", 15, Color(1.0, 0.55, 0.95))
	# top-right: menu
	var tr := HBoxContainer.new()
	hud.add_child(tr)
	_pin(tr, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END, Vector2(-16, 16))
	_btn(tr, "Help", _tut_restart, Vector2(80, 40))
	_btn(tr, "Relics", func(): popup.visible = not popup.visible, Vector2(96, 40))
	# tutorial panel (left, under the currency)
	tut_panel = PanelContainer.new()
	hud.add_child(tut_panel)
	tut_panel.position = Vector2(16, 150)
	tut_panel.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.05, 0.16, 0.93), Color(1.0, 0.8, 0.35, 0.9), 12, 12))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 8)
	tut_panel.add_child(tv)
	l_tut_t = _lbl(tv, "", 16, Color(1.0, 0.82, 0.45))
	l_tut_t.add_theme_font_override("font", serif)
	l_tut = _lbl(tv, "", 15, Color(0.95, 0.93, 1.0))
	l_tut.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_tut.custom_minimum_size = Vector2(300, 0)
	var th2 := HBoxContainer.new()
	tv.add_child(th2)
	b_tut = _btn(th2, "Next", _tut_next, Vector2(140, 38))
	_btn(th2, "Skip tutorial", _tut_skip, Vector2(140, 38))
	b_mute = _btn(tr, "Sound: On", _toggle_mute, Vector2(110, 40))
	_btn(tr, "Fullscreen", _fullscreen, Vector2(110, 40))
	# bottom: wing panel
	var bp := PanelContainer.new()
	hud.add_child(bp)
	_pin(bp, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN, Vector2(0, -14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	bp.add_child(h)
	left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	h.add_child(left)
	var nav := HBoxContainer.new()
	left.add_child(nav)
	_btn(nav, "<", func(): _select(sel - 1), Vector2(40, 36))
	l_wing = _lbl(nav, "", 18, Color.WHITE)
	l_wing.add_theme_font_override("font", serif)
	l_wing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_wing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_btn(nav, ">", func(): _select(sel + 1), Vector2(40, 36))
	b_master = _btn(left, "", func(): _hire(sel), Vector2(0, 36))
	b_boss = _btn(left, "", func(): boss_start(sel), Vector2(0, 36))
	b_buy = _btn(left, "", func(): buy_mode = (buy_mode + 1) % 3, Vector2(0, 30))
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	h.add_child(cards)
	for i in 4:
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(158, 0)
		pc.add_theme_stylebox_override("panel", _sb(Color(0.1, 0.07, 0.2, 0.9), Color(1, 1, 1, 0.12), 10, 8))
		cards.add_child(pc)
		var cv := VBoxContainer.new()
		pc.add_child(cv)
		var ln := _lbl(cv, ST[i], 16, Color.WHITE)
		var ll := _lbl(cv, "", 13, Color(0.75, 0.72, 0.85))
		var lr := _lbl(cv, "", 14, Color(0.6, 1.0, 0.8))
		var bu := _btn(cv, "", func(): _buy(sel, i), Vector2(0, 46))
		card_ui.append({"name": ln, "lv": ll, "rate": lr, "b": bu})
	b_unlock = _btn(h, "", func(): _unlock(sel), Vector2(420, 120))
	abil = HBoxContainer.new()
	abil.add_theme_constant_override("separation", 10)
	h.add_child(abil)
	for k in 3:
		abil_b.append(_btn(abil, "", func(): _ability(k), Vector2(210, 84)))
	# top-centre: boss bar
	boss_panel = PanelContainer.new()
	hud.add_child(boss_panel)
	_pin(boss_panel, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END, Vector2(0, 14))
	var bv := VBoxContainer.new()
	boss_panel.add_child(bv)
	l_bname = _lbl(bv, "", 20, Color(1, 0.8, 0.8))
	l_bname.add_theme_font_override("font", serif)
	l_bname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar = ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(520, 22)
	bv.add_child(bar)
	l_btime = _lbl(bv, "", 15, Color(1, 0.9, 0.7))
	l_btime.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# toast
	l_toast = _lbl(hud, "", 19, Color(1, 0.95, 0.8))
	l_toast.add_theme_constant_override("outline_size", 8)
	l_toast.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.1))
	l_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_toast.custom_minimum_size = Vector2(760, 0)
	l_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin(l_toast, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END, Vector2(0, 118))
	# relics popup
	popup = PanelContainer.new()
	hud.add_child(popup)
	_pin(popup, Control.PRESET_CENTER, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH, Vector2.ZERO)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	popup.add_child(pv)
	var pt := _lbl(pv, "Relics - bought with runes, kept forever", 20, Color(1.0, 0.82, 0.45))
	pt.add_theme_font_override("font", serif)
	for k in RELICS.size():
		var row := HBoxContainer.new()
		pv.add_child(row)
		var rl := _lbl(row, "", 15, Color.WHITE)
		rl.custom_minimum_size = Vector2(400, 0)
		relic_l.append(rl)
		relic_b.append(_btn(row, "", func(): _buy_relic(k), Vector2(130, 40)))
	b_grad = _btn(pv, "", _graduate, Vector2(0, 48))
	_btn(pv, "Close", func(): popup.visible = false, Vector2(0, 40))
	popup.visible = false
	cursor = ColorRect.new()
	cursor.color = Color(1, 0.85, 0.4)
	cursor.size = Vector2(14, 14)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.visible = false
	hud.add_child(cursor)


func _tut_restart() -> void:
	tut = 0
	tut_hold = 0.0
	cam_moved = false


func _tut_skip() -> void:
	tut = TUT.size()
	_tut_next()


func _relic_cost(k: int) -> int:
	return RELICS[k].get("cost", (relic[k] + 1) * 2)


func _buy_relic(k: int) -> void:
	var c := _relic_cost(k)
	if runes < c or relic[k] >= RELICS[k].get("max", 99):
		return
	runes -= c
	relic[k] += 1
	_sfx("shrine", -8.0)


func _toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	b_mute.text = "Sound: Off" if muted else "Sound: On"


func _toast(t: String, secs := 4.5) -> void:
	if l_toast == null:
		return
	l_toast.text = t
	toast_t = secs


func _float(text: String, p: Vector3, col: Color) -> void:
	if cam.is_position_behind(p):
		return
	var l := _lbl(hud, text, 20, col)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.0, 0.08))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = _scr(p) - Vector2(24, 12)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


func _ui_tick(dt: float) -> void:
	l_souls.text = fmt(souls) + " souls"
	l_sps.text = "+%s per second%s" % [fmt(sps()), "   FRENZY x5" if frenzy > 0.0 else ""]
	l_runes.text = "Runes: %d%s" % [runes, ("   Graduations: %d" % grads) if grads > 0 else ""]
	toast_t -= dt
	l_toast.modulate.a = clampf(toast_t, 0.0, 1.0)
	var fight: bool = B != null
	boss_panel.visible = fight
	abil.visible = fight
	left.visible = not fight
	var w := sel
	var col: Color = WINGS[w]["col"]
	var open: bool = lv[w][0] > 0
	cards.visible = open and not fight
	b_unlock.visible = not open and not fight
	if fight:
		l_bname.text = "%s  Lv %d" % [WINGS[B["w"]]["boss"], boss_lv[B["w"]] + 1]
		bar.value = clampf(B["hp"] / B["max"], 0.0, 1.0)
		var st2 := "SHIELDED - tap the orbs!" if not B["orbs"].is_empty() else ("ENRAGED" if B["t"] < 20.0 else "")
		l_btime.text = "%d s   %s" % [int(ceil(maxf(B["t"], 0.0))), st2]
		var names = ["Surge  [Q]\nDamage x3 for 6s", "Ward  [W]\nBreak seals, block slam", "Soulburst  [E]\nBig hit / pops an orb"]
		for k in 3:
			abil_b[k].disabled = cd[k] > 0.0
			abil_b[k].text = names[k] if cd[k] <= 0.0 else "%s\n%d s" % [names[k].get_slice("\n", 0), int(ceil(cd[k]))]
		return
	l_wing.text = WINGS[w]["name"]
	l_wing.add_theme_color_override("font_color", col.lightened(0.3))
	b_buy.text = "Buy amount: " + ["x1", "x10", "Max"][buy_mode]
	b_master.disabled = not open or (not master[w] and souls < 400.0 * CM[w])
	if master[w]:
		b_master.text = "%s: auto-upgrade %s" % [WINGS[w]["master"], "ON" if auto[w] else "OFF"]
	else:
		b_master.text = "Hire %s  (%s)" % [WINGS[w]["master"], fmt(400.0 * CM[w])]
	b_boss.disabled = not open
	b_boss.text = "Fight %s  Lv %d" % [WINGS[w]["boss"], boss_lv[w] + 1]
	if open:
		var bn := bottleneck(w)
		for i in 4:
			var c: Dictionary = card_ui[i]
			var l: int = lv[w][i]
			var nm := next_mile(l)
			c["lv"].text = "Lv %d%s" % [l, ("   x2 at %d" % nm) if nm > 0 else ""]
			c["rate"].text = "%s /s%s" % [fmt(st_rate(w, i)), "  SLOWEST" if i == bn else ""]
			c["rate"].add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if i == bn else Color(0.6, 1.0, 0.8))
			var n := buy_n(w, i)
			var cs := cost_n(w, i, n)
			c["b"].text = "Upgrade x%d\n%s" % [n, fmt(cs)]
			c["b"].disabled = souls < cs
	else:
		var need_boss: bool = boss_lv[w - 1] <= 0
		b_unlock.disabled = need_boss or souls < UNLOCK[w]
		if need_boss:
			b_unlock.text = "%s is sealed.\nDefeat %s in %s first." % [WINGS[w]["name"], WINGS[w - 1]["boss"], WINGS[w - 1]["name"]]
		else:
			b_unlock.text = "Open %s\n%s souls   (each soul here is worth x%d)" % [WINGS[w]["name"], fmt(UNLOCK[w]), int(VAL[w])]
	if popup.visible:
		for k in RELICS.size():
			var mx: int = RELICS[k].get("max", 99)
			relic_l[k].text = "%s  (Lv %d)  -  %s" % [RELICS[k]["name"], relic[k], RELICS[k]["desc"]]
			relic_b[k].disabled = runes < _relic_cost(k) or relic[k] >= mx
			relic_b[k].text = "Owned" if relic[k] >= mx else "%d runes" % _relic_cost(k)
		var g := _graduate_gain()
		b_grad.disabled = g <= 0
		b_grad.text = ("Graduate: start over with +%d runes and +25%% production" % g) if g > 0 else "Graduate: defeat the Corrupted Archmage first"


# ------------------------------------------------------------ audio / save

func _audio() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -12.0
	add_child(music)
	music.finished.connect(music.play)
	_music("forest")


func _music(n: String) -> void:
	music.stream = load("res://audio/music_%s.wav" % n)
	music.play()


func _sfx(n: String, vol := -8.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://audio/sfx_%s.wav" % n)
	p.volume_db = vol
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _save() -> void:
	if smoke:
		return
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"souls": souls, "total": total, "runes": runes, "grads": grads, "lv": lv, "master": master,
		"auto": auto, "boss_lv": boss_lv, "relic": relic, "muted": muted, "tut_done": tut < 0, "time": Time.get_unix_time_from_system()}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if typeof(d) != TYPE_DICTIONARY:
		return
	souls = float(d.get("souls", 0.0))
	total = float(d.get("total", 0.0))
	runes = int(d.get("runes", 0))
	grads = int(d.get("grads", 0))
	for w in 4:
		for i in 4:
			lv[w][i] = int(d["lv"][w][i])
		master[w] = bool(d["master"][w])
		auto[w] = bool(d["auto"][w])
		boss_lv[w] = int(d["boss_lv"][w])
		relic[w] = int(d["relic"][w])
	if bool(d.get("tut_done", false)):
		tut = -1
	if bool(d.get("muted", false)):
		_toggle_mute()
	var away := minf(Time.get_unix_time_from_system() - float(d.get("time", 0.0)), 4.0 * 3600.0)
	if away > 60.0:
		var g := sps() * away * 0.5
		_earn(g)
		_toast.call_deferred("Welcome back! Your academy made %s souls while you were away." % fmt(g), 7.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()


# ------------------------------------------------------------ smoke test (-- --smoke)

var _sm := 0
func _smoke() -> void:
	var dir := OS.get_environment("SHOTS_DIR")
	if _sm == 0 and time > 1.0:
		_sm = 1
		souls = 1e6
		buy_mode = 2
		for i in 4:
			_buy(0, i)
		_hire(0)
		_tap_station(0, 0)
		_curse_random()
		_spawn_wisp()
	elif _sm == 1 and time > 4.0:
		_sm = 2
		if dir != "":
			get_viewport().get_texture().get_image().save_png(dir + "/hex_1.png")
		boss_start(0)
		_seal_random()
	elif _sm == 2 and time > 9.0:
		_sm = 3
		_spawn_orbs()
		_ability(0)
		_ability(1)
	elif _sm == 3 and time > 10.5:
		_sm = 4
		if dir != "":
			get_viewport().get_texture().get_image().save_png(dir + "/hex_2.png")
		for o in B["orbs"].duplicate():
			_pop_orb(o)
		_ability(2)
		_pick(Vector2(300, 300))
		B["hp"] = 0.0
	elif _sm == 4 and time > 15.0:
		_sm = 5
		souls = 1e9
		_unlock(1)
		boss_start(1)
	elif _sm == 5 and time > 21.0:
		_sm = 6
		B["t"] = 0.1
	elif _sm == 6 and time > 26.0:
		_sm = 7
		total = 1e12
		boss_lv[3] = 1
		popup.visible = true
		_buy_relic(0)
		_graduate()
		print("SMOKE OK boss=%s runes=%d grads=%d" % [str(B == null), runes, grads])
		get_tree().quit()
