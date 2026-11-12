extends RefCounted
## Style B 3D models and effects, built from primitives (toon shading + ink outline).
## Heroes, enemies, boss and ability VFX. Units: 1 = about one hero width.

const INK := Color("0d0816")

static var _cache := {}


# --- materials ---

static func toon(c: Color, emit := 0.0, outline := true) -> StandardMaterial3D:
	var key := "t%s_%s_%s" % [c.to_html(), emit, outline]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.75
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if outline:
		var o := StandardMaterial3D.new()
		o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		o.albedo_color = INK
		o.cull_mode = BaseMaterial3D.CULL_FRONT
		o.grow = true
		o.grow_amount = 0.04
		m.next_pass = o
	_cache[key] = m
	return m


## Bright unshaded see-through material for magic (values above 1 glow).
static func glow(c: Color, alpha := 0.85, power := 2.5) -> StandardMaterial3D:
	var key := "g%s_%s_%s" % [c.to_html(), alpha, power]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c.r * power, c.g * power, c.b * power, alpha)
	_cache[key] = m
	return m


static func flat(c: Color) -> StandardMaterial3D:
	return glow(c, c.a, 1.0)


# --- meshes ---

static func sphere(r: float, segs := 24) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(4, segs / 2)
	return s


static func cyl(top: float, bottom: float, h: float, segs := 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	return c


static func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


static func torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 32
	return t


## Flat ring sector on the ground (cones, arcs, telegraphs). Angles in radians on XZ.
static func sector(r0: float, r1: float, a0: float, a1: float, n := 28) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var aa := a0 + (a1 - a0) * i / n
		var ab := a0 + (a1 - a0) * (i + 1) / n
		var p1 := Vector3(cos(aa) * r0, 0, sin(aa) * r0)
		var p2 := Vector3(cos(aa) * r1, 0, sin(aa) * r1)
		var p3 := Vector3(cos(ab) * r1, 0, sin(ab) * r1)
		var p4 := Vector3(cos(ab) * r0, 0, sin(ab) * r0)
		for v in [p1, p2, p3, p1, p3, p4]:
			st.add_vertex(v)
	return st.commit()


## Upright curved wall (waves, slash ribbons): arc of radius r, height h.
static func wall(r: float, h: float, a0: float, a1: float, n := 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var aa := a0 + (a1 - a0) * i / n
		var ab := a0 + (a1 - a0) * (i + 1) / n
		var k := sin(PI * (i + 0.5) / n)
		var ha := h * (0.4 + 0.6 * k)
		var b1 := Vector3(cos(aa) * r, 0, sin(aa) * r)
		var b2 := Vector3(cos(ab) * r, 0, sin(ab) * r)
		var t1 := b1 + Vector3(0, ha, 0) + Vector3(cos(aa), 0, sin(aa)) * h * 0.25
		var t2 := b2 + Vector3(0, ha, 0) + Vector3(cos(ab), 0, sin(ab)) * h * 0.25
		for v in [b1, t1, t2, b1, t2, b2]:
			st.add_vertex(v)
	return st.commit()


static func add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func light(parent: Node3D, pos: Vector3, c: Color, energy := 1.5, rng := 3.5) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	parent.add_child(l)
	return l


static func shadow(parent: Node3D, r: float) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0.38)
	add(parent, cyl(r, r, 0.01), m, Vector3(0, 0.02, 0))


static func eyes(parent: Node3D, pos: Vector3, gap: float, c: Color, r := 0.05) -> void:
	add(parent, sphere(r, 8), toon(c, 6.0, false), pos + Vector3(-gap, 0, 0))
	add(parent, sphere(r, 8), toon(c, 6.0, false), pos + Vector3(gap, 0, 0))


# --- heroes (face +Z) ---

static func hero(id: String, pose := "idle") -> Node3D:
	var root := Node3D.new()
	shadow(root, 0.55)
	var body := Node3D.new()
	body.name = "body"
	root.add_child(body)
	match id:
		"vex": _vex(body, pose)
		"lyra": _lyra(body, pose)
		"brann": _brann(body, pose)
	if pose == "attack":
		body.rotation.x = 0.22
		body.position.z = 0.12
	elif pose == "windup":
		body.rotation.x = -0.18
	return root


## Two jointed legs with boots. hip = hip height, w = half distance between legs.
static func _legs(b: Node3D, w: float, hip: float, r: float, leg: Material, boot: Material, pose: String) -> void:
	for side in [-1.0, 1.0]:
		var step: float = 0.0
		if pose == "attack":
			step = 0.22 * side
		elif pose == "windup":
			step = -0.12 * side
		elif pose == "walk_a" or pose == "walk_b":
			step = 0.2 * side * (1.0 if pose == "walk_a" else -1.0)
		var h := Vector3(w * side, hip, 0)
		var k := Vector3(w * 1.1 * side, hip * 0.52, 0.06 + step * 0.5)
		var a := Vector3(w * 1.15 * side, 0.14, step)
		_bone(b, h, k, r, leg)
		_bone(b, k, a, r * 0.85, leg)
		add(b, box(r * 2.4, 0.16, r * 3.6), boot, a + Vector3(0, -0.05, 0.05))


## Two eyebrows above the eyes. tilt > 0 = angry (inner ends down), < 0 = soft.
static func _brows(b: Node3D, at: Vector3, gap: float, mat: Material, tilt: float) -> void:
	for side in [-1.0, 1.0]:
		add(b, box(0.055, 0.014, 0.02), mat, at + Vector3(gap * side, 0, 0), Vector3(-0.3, 0, tilt * side))


## Upper + lower arm from shoulder to hand; the elbow bends outward and down.
static func _arm(b: Node3D, sh: Vector3, hand: Vector3, r: float, mat: Material, side: float) -> void:
	var el := (sh + hand) * 0.5 + Vector3(0.1 * side, -0.08, -0.04)
	_bone(b, sh, el, r, mat)
	_bone(b, el, hand, r * 0.85, mat)


## Vex, Blood Duelist: slim vampire duelist. High collar, tattered cape, magenta claw gauntlets.
static func _vex(b: Node3D, pose: String) -> void:
	var mag := Color("ff2bd6")
	var cloth := toon(Color("3a0f3e"))
	var dark := toon(Color("1a0818"))
	var cape_in := toon(Color("7a1060"))
	_legs(b, 0.1, 0.78, 0.07, toon(Color("24101e")), toon(Color("140812")), pose)
	# coat tails and torso
	add(b, wall(0.2, 0.55, PI * 0.95, PI * 2.05), cloth, Vector3(0, 0.38, 0))
	add(b, cyl(0.2, 0.15, 0.52), cloth, Vector3(0, 1.05, 0))
	add(b, torus(0.14, 0.17), toon(mag, 1.5, false), Vector3(0, 0.82, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	add(b, box(0.05, 0.4, 0.03), toon(mag, 0.8, false), Vector3(0, 1.08, 0.18))
	# tattered cape: dark outside, magenta inside, strips of different length
	for i in 6:
		var x := -0.24 + i * 0.096
		var l := 0.75 + 0.25 * sin(i * 1.7)
		add(b, box(0.1, l, 0.025), dark, Vector3(x, 1.3 - l * 0.5, -0.2 - l * 0.12), Vector3(-0.22, 0, x * 0.4))
		add(b, box(0.09, l * 0.95, 0.02), cape_in, Vector3(x, 1.3 - l * 0.5, -0.17 - l * 0.11), Vector3(-0.22, 0, x * 0.4))
	# high vampire collar
	add(b, wall(0.21, 0.3, PI * 0.85, PI * 2.15), toon(Color("5a0f45")), Vector3(0, 1.28, 0))
	# head: pale face, swept dark hair, glowing eyes
	add(b, sphere(0.16), toon(Color("f2d6dc")), Vector3(0, 1.5, 0.02))
	add(b, sphere(0.17), dark, Vector3(0, 1.56, -0.04), Vector3.ZERO, Vector3(1.05, 0.85, 1.05))
	add(b, cyl(0.0, 0.1, 0.34, 6), dark, Vector3(0.04, 1.62, -0.22), Vector3(-1.2, 0, 0.2))
	add(b, cyl(0.0, 0.07, 0.24, 6), dark, Vector3(-0.1, 1.6, -0.2), Vector3(-1.0, 0, -0.4))
	eyes(b, Vector3(0, 1.5, 0.16), 0.06, Color("ff4ae0"), 0.03)
	# sharp angry brows, a thin smirk and two little fangs
	_brows(b, Vector3(0, 1.545, 0.15), 0.06, toon(Color("1a0818"), 0.0, false), 0.45)
	add(b, box(0.07, 0.012, 0.02), toon(Color("5a1030"), 0.0, false), Vector3(0.01, 1.435, 0.155), Vector3(0, 0, -0.15))
	for side in [-1.0, 1.0]:
		add(b, cyl(0.0, 0.009, 0.035, 4), toon(Color("ffffff"), 0.3, false), Vector3(0.022 * side, 1.418, 0.15), Vector3(PI, 0, 0))
	# arms with claw gauntlets
	var hands := {"idle": [Vector3(-0.3, 0.86, 0.12), Vector3(0.3, 0.86, 0.12)],
		"windup": [Vector3(-0.32, 1.0, 0.25), Vector3(0.38, 1.2, -0.3)],
		"attack": [Vector3(-0.34, 0.95, -0.15), Vector3(0.12, 1.1, 0.62)]}
	var hs: Array = hands.get(pose, hands["idle"])
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var sh := Vector3(0.22 * side, 1.24, 0)
		var hand: Vector3 = hs[i]
		_arm(b, sh, hand, 0.055, cloth, side)
		add(b, sphere(0.075), toon(Color("24101e")), hand)
		var dir := (hand - (sh + hand) * 0.5).normalized()
		for k in 3:
			var off := Vector3((k - 1) * 0.035, (k - 1) * 0.02, 0)
			var tip := hand + dir * 0.26 + off
			var mi := add(b, cyl(0.0, 0.022, 0.26, 5), toon(mag, 2.5, false), (hand + tip) * 0.5 + off * 0.5)
			var ax := Vector3.UP.cross(dir)
			if ax.length() > 0.001:
				mi.basis = Basis(ax.normalized(), Vector3.UP.angle_to(dir))


## Lyra, Magic Gunslinger: long white ponytail, short-brim hat, long coat, scarf, rune pistol.
static func _lyra(b: Node3D, pose: String) -> void:
	var cyan := Color("00e5ff")
	var coat := toon(Color("0a3a4a"))
	var hair := toon(Color("dfe8f0"))
	_legs(b, 0.1, 0.76, 0.068, toon(Color("1a3038")), toon(Color("081418")), pose)
	add(b, wall(0.24, 0.6, PI * 0.9, PI * 2.1), coat, Vector3(0, 0.3, 0))
	add(b, cyl(0.19, 0.2, 0.52), coat, Vector3(0, 1.03, 0))
	add(b, box(0.42, 0.06, 0.32), toon(Color("3a2a1a")), Vector3(0, 0.8, 0))
	for i in 3:
		add(b, box(0.04, 0.08, 0.04), toon(cyan, 3.0, false), Vector3(-0.12 + i * 0.12, 0.8, 0.17))
	add(b, box(0.1, 0.22, 0.12), toon(Color("3a2a1a")), Vector3(0.22, 0.7, 0.02))
	# scarf: ring + tail blowing back
	add(b, torus(0.11, 0.17), toon(cyan, 0.6), Vector3(0, 1.3, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	add(b, box(0.09, 0.42, 0.03), toon(cyan, 0.6), Vector3(0.1, 1.15, -0.2), Vector3(-0.6, 0.3, 0))
	# head, white hair with a long ponytail, glowing eyes
	add(b, sphere(0.155), toon(Color("f0d8c0")), Vector3(0, 1.49, 0.02))
	add(b, sphere(0.165), hair, Vector3(0, 1.54, -0.04), Vector3.ZERO, Vector3(1.05, 0.9, 1.05))
	for i in 4:
		add(b, sphere(0.085 - i * 0.012, 10), hair, Vector3(0, 1.45 - i * 0.13, -0.22 - i * 0.03))
	add(b, sphere(0.04, 8), toon(cyan, 3.0, false), Vector3(0, 1.5, -0.2))
	eyes(b, Vector3(0, 1.49, 0.16), 0.06, cyan, 0.028)
	# soft brows, small confident mouth, a hint of blush
	_brows(b, Vector3(0, 1.54, 0.145), 0.06, toon(Color("b8c8d8"), 0.0, false), -0.15)
	add(b, box(0.05, 0.011, 0.02), toon(Color("8a3a40"), 0.0, false), Vector3(0, 1.425, 0.15), Vector3(0, 0, 0.1))
	for side in [-1.0, 1.0]:
		add(b, sphere(0.022, 6), toon(Color("ff9aa8"), 0.0, false), Vector3(0.085 * side, 1.455, 0.13), Vector3.ZERO, Vector3(1.3, 0.6, 0.5))
	# short brim hat tipped back so the face reads from above
	var hat := Node3D.new()
	hat.position = Vector3(0, 1.66, -0.02)
	hat.rotation.x = -0.35
	b.add_child(hat)
	add(hat, cyl(0.34, 0.34, 0.035), toon(Color("102028")), Vector3.ZERO)
	add(hat, cyl(0.15, 0.18, 0.2), toon(Color("102028")), Vector3(0, 0.1, 0))
	add(hat, cyl(0.185, 0.185, 0.045), toon(cyan, 2.0, false), Vector3(0, 0.04, 0))
	# arms: right hand holds the pistol, left rests or steadies the aim
	var aim := pose == "windup" or pose == "attack"
	var rh := Vector3(0.22, 1.18, 0.55) if pose == "attack" else (Vector3(0.24, 1.15, 0.35) if pose == "windup" else Vector3(0.3, 0.88, 0.1))
	var lh := Vector3(0.05, 1.12, 0.42) if aim else Vector3(-0.28, 0.85, 0.06)
	_arm(b, Vector3(0.21, 1.24, 0), rh, 0.05, coat, 1.0)
	_arm(b, Vector3(-0.21, 1.24, 0), lh, 0.05, coat, -1.0)
	add(b, sphere(0.055), toon(Color("f0d8c0")), lh)
	var gun := Node3D.new()
	gun.position = rh
	gun.rotation.x = 0.0 if aim else 1.3
	b.add_child(gun)
	add(gun, box(0.06, 0.13, 0.07), toon(Color("3a2a1a")), Vector3(0, -0.05, -0.02), Vector3(-0.3, 0, 0))
	add(gun, box(0.07, 0.08, 0.2), toon(Color("2a3440")), Vector3(0, 0.03, 0.06))
	add(gun, cyl(0.03, 0.03, 0.22, 10), toon(Color("4a5868")), Vector3(0, 0.04, 0.24), Vector3(PI / 2, 0, 0))
	for k in 2:
		add(gun, torus(0.03, 0.045), toon(cyan, 4.0, false), Vector3(0, 0.04, 0.18 + k * 0.1), Vector3(PI / 2, 0, 0))
	add(gun, sphere(0.045, 10), toon(cyan, 5.0, false), Vector3(0, 0.04, 0.36))


## Brann, Runic Guardian: plate armor with a glowing chest rune, curved horned helm,
## braided ginger beard, fur collar, rune shield and a runed broadsword.
static func _brann(b: Node3D, pose: String) -> void:
	var org := Color("ff7a00")
	var steel := toon(Color("8a93a3"))
	var steel_dk := toon(Color("5a6070"))
	var leather := toon(Color("5a2a0a"))
	_legs(b, 0.16, 0.74, 0.1, steel_dk, toon(Color("2a1a10")), pose)
	add(b, box(0.42, 0.55, 0.06), toon(Color("8a3a0a")), Vector3(0, 0.55, 0.2))
	add(b, box(0.36, 0.08, 0.07), toon(org, 1.2), Vector3(0, 0.3, 0.21))
	add(b, cyl(0.3, 0.27, 0.3), leather, Vector3(0, 0.88, 0))
	add(b, box(0.62, 0.42, 0.42), steel, Vector3(0, 1.17, 0))
	add(b, box(0.5, 0.06, 0.44), steel_dk, Vector3(0, 0.96, 0))
	add(b, torus(0.06, 0.1), toon(org, 4.0, false), Vector3(0, 1.18, 0.215), Vector3(PI / 2, 0, 0))
	add(b, box(0.03, 0.14, 0.02), toon(org, 4.0, false), Vector3(0, 1.18, 0.22))
	add(b, torus(0.14, 0.27), toon(Color("4a3020")), Vector3(0, 1.4, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	# pauldrons
	for side in [-1.0, 1.0]:
		add(b, sphere(0.2), toon(org), Vector3(0.38 * side, 1.36, 0), Vector3.ZERO, Vector3(1.1, 0.8, 1.1))
		add(b, torus(0.17, 0.22), steel, Vector3(0.38 * side, 1.3, 0), Vector3(0, 0, 0.4 * side))
		add(b, cyl(0.0, 0.05, 0.18, 6), steel, Vector3(0.45 * side, 1.5, 0), Vector3(0, 0, -0.6 * side))
	# helm, visor, curved horns, beard with braids
	add(b, sphere(0.22), steel, Vector3(0, 1.62, 0))
	add(b, box(0.3, 0.045, 0.08), toon(Color("ffb347"), 4.0, false), Vector3(0, 1.62, 0.2))
	add(b, box(0.05, 0.16, 0.06), steel_dk, Vector3(0, 1.56, 0.21))
	for side in [-1.0, 1.0]:
		var h0 := Vector3(0.19 * side, 1.72, 0)
		var h1 := h0 + Vector3(0.18 * side, 0.1, -0.04)
		var h2 := h1 + Vector3(0.06 * side, 0.2, -0.08)
		_bone(b, h0, h1, 0.06, toon(Color("e0d0b0")))
		_bone(b, h1, h2, 0.04, toon(Color("e0d0b0")))
	# big ginger beard sticking out in front of the helm and fur collar (reads from above)
	var beard := toon(Color("d8641e"))
	add(b, cyl(0.2, 0.04, 0.42, 10), beard, Vector3(0, 1.36, 0.28), Vector3(0.55, 0, 0), Vector3(1.0, 1.0, 0.75))
	add(b, sphere(0.17, 12), beard, Vector3(0, 1.5, 0.22), Vector3.ZERO, Vector3(1.15, 0.6, 0.7))
	for side in [-1.0, 1.0]:
		add(b, cyl(0.03, 0.055, 0.16, 6), beard, Vector3(0.1 * side, 1.53, 0.3), Vector3(0, 0, 1.2 * side))   # mustache
		add(b, cyl(0.025, 0.035, 0.3, 6), beard, Vector3(0.09 * side, 1.2, 0.36), Vector3(0.35, 0, 0))   # braids
		add(b, sphere(0.035, 6), toon(Color("c8d0e0")), Vector3(0.09 * side, 1.05, 0.41))
	# arms: shield on the left, sword on the right
	var rh: Vector3 = {"idle": Vector3(0.42, 0.95, 0.15), "windup": Vector3(0.45, 1.45, -0.2), "attack": Vector3(0.25, 1.05, 0.6)}.get(pose, Vector3(0.42, 0.95, 0.15))
	var lh := Vector3(-0.4, 1.0, 0.32)
	_arm(b, Vector3(0.36, 1.3, 0), rh, 0.085, steel_dk, 1.0)
	_arm(b, Vector3(-0.36, 1.3, 0), lh, 0.085, steel_dk, -1.0)
	add(b, sphere(0.085), leather, rh)
	var shield := Node3D.new()
	shield.position = lh + Vector3(-0.08, 0, 0.08)
	shield.rotation = Vector3(PI / 2, 0.45, 0)
	b.add_child(shield)
	add(shield, cyl(0.38, 0.38, 0.07, 28), toon(Color("b85a1a")), Vector3.ZERO)
	add(shield, torus(0.34, 0.4), steel, Vector3(0, 0.02, 0))
	add(shield, torus(0.14, 0.2), toon(org, 3.0, false), Vector3(0, 0.05, 0))
	add(shield, sphere(0.08), steel, Vector3(0, 0.05, 0))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		add(shield, box(0.03, 0.02, 0.1), toon(org, 3.0, false), Vector3(cos(a) * 0.27, 0.05, sin(a) * 0.27), Vector3(0, -a, 0))
	var sw := Node3D.new()
	sw.position = rh
	sw.rotation = {"idle": Vector3(0.35, 0, 0.15), "windup": Vector3(-1.0, 0, 0.3), "attack": Vector3(1.55, 0, 0)}.get(pose, Vector3.ZERO)
	b.add_child(sw)
	add(sw, cyl(0.035, 0.035, 0.22, 8), toon(Color("3a2010")), Vector3(0, -0.02, 0))
	add(sw, sphere(0.05, 8), toon(org, 1.0), Vector3(0, -0.15, 0))
	add(sw, box(0.34, 0.06, 0.08), steel, Vector3(0, 0.1, 0))
	add(sw, box(0.15, 1.0, 0.035), toon(Color("c8d0e0")), Vector3(0, 0.62, 0))
	add(sw, cyl(0.0, 0.075, 0.14, 4), toon(Color("c8d0e0")), Vector3(0, 1.19, 0), Vector3(0, PI / 4, 0), Vector3(1, 1, 0.3))
	add(sw, box(0.03, 0.8, 0.04), toon(org, 3.0, false), Vector3(0, 0.58, 0))


# --- enemies (face +Z) ---

## pose: idle / windup / attack. Elites are 1.4x, darker, with gold details and a gold aura ring.
static func enemy(kind: String, elite := false, pose := "idle") -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "body"
	root.add_child(body)
	match kind:
		"wolf": _wolf(body, elite, pose)
		"wisp": _wisp(body, elite, pose)
		"brute": _brute(body, elite, pose)
	if elite:
		body.scale = Vector3.ONE * 1.4
		var r := 0.85 if kind != "brute" else 1.15
		add(root, sector(r - 0.1, r, 0, TAU, 40), glow(Color("ffc830"), 0.9), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3.ONE * 1.4)
	shadow(root, 0.6 if kind != "brute" else 1.0)
	return root


## Cursed Wolf: lean, arched back, shaggy spikes, long snout with fangs, bushy tail,
## a glowing curse scar on the flank. Wind-up = crouch, attack = mid-leap with jaws open.
static func _wolf(b: Node3D, elite: bool, pose: String) -> void:
	var fur := toon(Color("403638") if not elite else Color("2a2224"))
	var fur_hi := toon(Color("6a5a58") if not elite else Color("3e3436"))
	var mane := toon(Color("241c20")) if not elite else toon(Color("ffc830"), 1.2)
	var eye := Color("ff3040") if not elite else Color("ffc830")
	var crouch := 0.0
	var lift := 0.0
	var tilt := 0.0
	if pose == "windup":
		crouch = 0.14
		tilt = 0.12
	elif pose == "attack":
		lift = 0.35
		tilt = -0.22
	var bod := Node3D.new()
	bod.position = Vector3(0, lift - crouch, 0)
	bod.rotation.x = tilt
	b.add_child(bod)
	add(bod, capsule(0.2, 1.05), fur, Vector3(0, 0.6, -0.05), Vector3(PI / 2 + 0.08, 0, 0), Vector3(0.9, 1, 1))
	add(bod, sphere(0.27), fur_hi, Vector3(0, 0.7, 0.32), Vector3.ZERO, Vector3(0.78, 0.95, 1.15))
	# shaggy spikes along neck and back
	for i in 8:
		var z := 0.45 - i * 0.13
		var h := 0.26 - i * 0.018
		add(bod, cyl(0.0, 0.07, h, 5), mane, Vector3(0, 0.84 - i * 0.012, z), Vector3(-0.9, 0, 0))
	for side in [-1.0, 1.0]:
		add(bod, cyl(0.0, 0.06, 0.22, 5), mane, Vector3(0.17 * side, 0.78, 0.36), Vector3(-0.7, 0, -0.5 * side))
	# curse scar and a fresh wound
	add(bod, box(0.02, 0.05, 0.36), toon(Color("b04aff"), 3.0, false), Vector3(0.235, 0.62, -0.05), Vector3(0.3, 0, 0))
	add(bod, sphere(0.06, 8), toon(Color("a01020"), 0.5, false), Vector3(-0.22, 0.56, -0.2))
	# head: skull, long snout, jaw (opens on attack), fangs, ears, eyes
	var head := Node3D.new()
	head.position = Vector3(0, 0.78, 0.55)
	head.rotation.x = 0.15 if pose == "windup" else 0.0
	bod.add_child(head)
	add(head, sphere(0.19), fur, Vector3(0, 0, 0), Vector3.ZERO, Vector3(0.85, 0.85, 1.15))
	add(head, cyl(0.06, 0.12, 0.42, 10), fur, Vector3(0, -0.04, 0.29), Vector3(PI / 2, 0, 0))
	add(head, sphere(0.05, 8), toon(Color("0d0a10")), Vector3(0, -0.02, 0.5))
	var jaw_open := 0.55 if pose == "attack" else 0.1
	var jaw := Node3D.new()
	jaw.position = Vector3(0, -0.09, 0.1)
	jaw.rotation.x = jaw_open
	head.add_child(jaw)
	add(jaw, box(0.12, 0.05, 0.36), fur_hi, Vector3(0, -0.02, 0.17))
	add(jaw, box(0.09, 0.02, 0.3), toon(Color("7a1020")), Vector3(0, 0.01, 0.16))
	for side in [-1.0, 1.0]:
		add(head, cyl(0.0, 0.022, 0.09, 5), toon(Color("e8e0d0")), Vector3(0.045 * side, -0.12, 0.42), Vector3(PI, 0, 0))
		add(jaw, cyl(0.0, 0.02, 0.07, 5), toon(Color("e8e0d0")), Vector3(0.04 * side, 0.03, 0.3))
		add(head, cyl(0.0, 0.07, 0.22, 4), mane, Vector3(0.1 * side, 0.18, -0.04), Vector3(-0.25, 0, -0.3 * side))
		add(head, sphere(0.032, 8), toon(eye, 6.0, false), Vector3(0.09 * side, 0.04, 0.14))
	# legs: front straight, hind legs with the backward ankle
	var reach := 0.25 if pose == "attack" else 0.0
	for side in [-1.0, 1.0]:
		var x: float = 0.13 * side
		var f0 := Vector3(x, 0.62, 0.32)
		var f1 := Vector3(x * 1.1, 0.33, 0.36 + reach)
		var f2 := Vector3(x * 1.1, 0.06 + crouch, 0.38 + reach * 1.6)
		_bone(bod, f0, f1, 0.06, fur)
		_bone(bod, f1, f2, 0.045, fur)
		var h0 := Vector3(x, 0.6, -0.42)
		var h1 := Vector3(x * 1.15, 0.38, -0.3 - reach * 0.5)
		var h2 := Vector3(x * 1.1, 0.22 + crouch * 0.5, -0.5 - reach)
		var h3 := Vector3(x * 1.1, 0.06 + crouch, -0.44 - reach)
		_bone(bod, h0, h1, 0.08, fur)
		_bone(bod, h1, h2, 0.05, fur)
		_bone(bod, h2, h3, 0.04, fur)
	# bushy tail: chain of spheres curving up
	for i in 5:
		var k := i / 4.0
		add(bod, sphere(0.09 - k * 0.04, 8), fur_hi if i % 2 == 0 else fur, Vector3(0, 0.66 + k * 0.22, -0.62 - k * 0.3))
	if elite:
		add(bod, torus(0.15, 0.22), toon(Color("5a4a2a")), Vector3(0, 0.74, 0.42), Vector3(1.2, 0, 0))
		for i in 6:
			var a := TAU * i / 6.0
			add(bod, cyl(0.0, 0.03, 0.12, 4), toon(Color("ffc830"), 1.5), Vector3(cos(a) * 0.2, 0.74 + sin(a) * 0.08, 0.42 + sin(a) * 0.14), Vector3(0, 0, -a + PI / 2))
		add(head, box(0.02, 0.18, 0.02), toon(Color("e8d8c0")), Vector3(-0.09, 0.03, 0.15), Vector3(0, 0, 0.5))


## Grave Wisp: a hooded ghost of green fire. Skull face in the hood, wispy tail curling down,
## two ghost hands, soul motes. Wind-up = hands together charging a bolt, attack = bolt released.
static func _wisp(b: Node3D, elite: bool, pose: String) -> void:
	var c := Color("9aff70") if not elite else Color("d8ff50")
	var deep := Color("2a8a3a") if not elite else Color("8a8a20")
	var y := 1.15
	# body: translucent flame layers tapering into a curled tail
	for i in 6:
		var k := i / 5.0
		add(b, sphere(0.34 - k * 0.24, 14), glow(c, 0.32 - k * 0.04, 1.4), Vector3(sin(k * 3.0) * 0.12, y - 0.1 - k * 0.75, -0.08 - k * 0.15))
	# hood
	add(b, sphere(0.3, 18), toon(deep, 0.6), Vector3(0, y + 0.05, -0.03), Vector3.ZERO, Vector3(1.0, 1.05, 1.0))
	add(b, cyl(0.0, 0.18, 0.3, 10), toon(deep, 0.6), Vector3(0, y + 0.32, -0.12), Vector3(-0.6, 0, 0))
	add(b, sphere(0.23, 16), toon(Color("0a140c")), Vector3(0, y + 0.02, 0.1), Vector3.ZERO, Vector3(1, 1, 0.8))
	# skull face glowing inside the hood
	add(b, sphere(0.14, 14), toon(Color("e8f0d8"), 0.8), Vector3(0, y, 0.15), Vector3.ZERO, Vector3(1, 1.1, 0.8))
	for side in [-1.0, 1.0]:
		add(b, sphere(0.04, 8), toon(Color("061006")), Vector3(0.05 * side, y + 0.03, 0.26))
		add(b, sphere(0.022, 6), toon(c, 6.0, false), Vector3(0.05 * side, y + 0.03, 0.29))
	add(b, box(0.08, 0.03, 0.02), toon(Color("061006")), Vector3(0, y - 0.08, 0.27))
	# ghost hands
	var charge := pose != "idle"
	for side in [-1.0, 1.0]:
		var hp := Vector3(0.1 * side, y - 0.15, 0.42) if charge else Vector3(0.36 * side, y - 0.25, 0.12)
		add(b, sphere(0.07, 10), glow(c, 0.7, 1.6), hp)
		for k in 3:
			add(b, cyl(0.0, 0.015, 0.1, 4), glow(c, 0.8, 1.8), hp + Vector3((k - 1) * 0.03, 0.0, 0.07), Vector3(PI / 2, 0, 0))
	if pose == "windup":
		orb(b, Vector3(0, y - 0.12, 0.55), 0.13, c, 1.5)
	elif pose == "attack":
		orb(b, Vector3(0, y - 0.1, 1.3), 0.15, c, 1.5)
		for k in 5:
			add(b, sphere(0.1 - k * 0.015, 8), glow(c, 0.5 - k * 0.08, 1.6), Vector3(0, y - 0.1, 1.1 - k * 0.15))
	# soul motes
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		add(b, sphere(0.035, 6), glow(c, 0.9, 2.0), Vector3(cos(a) * 0.5, y + sin(a * 2.0) * 0.2, sin(a) * 0.5))
	light(b, Vector3(0, y, 0.4), c, 1.4, 3.0)
	if elite:
		for i in 5:
			var a := TAU * i / 5.0
			add(b, box(0.06, 0.18, 0.06), toon(Color("ffc830"), 2.5, false), Vector3(cos(a) * 0.22, y + 0.42, sin(a) * 0.22 - 0.03), Vector3(0, a, 0.3))
		add(b, sector(0.55, 0.62, 0, TAU, 32), glow(Color("ffc830"), 0.8, 1.6), Vector3(0, y - 0.35, 0), Vector3(0.2, 0, 0))


## Bark Brute: hunched forest ogre with bark plates, mossy shoulders, branches growing from
## its back, knuckles on the ground. Wind-up = both fists raised, attack = fists slammed down.
static func _brute(b: Node3D, elite: bool, pose: String) -> void:
	var bark := toon(Color("4a3a2a") if not elite else Color("3a2e26"))
	var bark_dk := toon(Color("2e2218"))
	var skin := toon(Color("6a5440"))
	var moss := toon(Color("3f7a3a"))
	var eye := Color("ff3040") if not elite else Color("ffc830")
	# torso: big hunched mass with bark plates
	add(b, sphere(0.82), bark, Vector3(0, 1.25, -0.1), Vector3(-0.3, 0, 0), Vector3(1.15, 1.0, 0.95))
	add(b, sphere(0.55), skin, Vector3(0, 1.0, 0.35), Vector3.ZERO, Vector3(1.1, 0.9, 0.8))
	for i in 7:
		var a := -1.2 + i * 0.4
		add(b, box(0.32, 0.5, 0.1), bark_dk, Vector3(sin(a) * 0.82, 1.45 + cos(a * 1.3) * 0.1, -0.2 + cos(a) * 0.3 - 0.35), Vector3(-0.5, a, 0))
	# branches and roots growing from the back, with a few leaves
	for br in [[Vector3(-0.35, 1.9, -0.45), Vector3(-0.7, 2.6, -0.8)], [Vector3(0.3, 1.95, -0.4), Vector3(0.55, 2.75, -0.6)], [Vector3(0.0, 1.85, -0.7), Vector3(0.1, 2.4, -1.2)]]:
		_bone(b, br[0], br[1], 0.06, bark_dk)
		add(b, sphere(0.14, 8), toon(Color("7a3196")), br[1] + Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.2, 0.6, 1.2))
	for p in [Vector3(-0.65, 1.75, 0.1), Vector3(0.65, 1.75, 0.1), Vector3(0.0, 1.95, -0.15)]:
		add(b, sphere(0.25, 10), moss, p, Vector3.ZERO, Vector3(1.3, 0.5, 1.1))
	# head: small, low, tusks and horns, glowing eyes under a heavy brow
	var hp := Vector3(0, 1.32, 0.78)
	add(b, sphere(0.27), skin, hp, Vector3.ZERO, Vector3(1.1, 0.9, 1.0))
	add(b, box(0.48, 0.1, 0.2), bark_dk, hp + Vector3(0, 0.12, 0.1), Vector3(0.3, 0, 0))
	for side in [-1.0, 1.0]:
		add(b, sphere(0.045, 8), toon(eye, 6.0, false), hp + Vector3(0.1 * side, 0.04, 0.24))
		add(b, cyl(0.0, 0.05, 0.22, 6), toon(Color("e8dcc0")), hp + Vector3(0.12 * side, -0.16, 0.2), Vector3(-0.3, 0, -0.3 * side))
		var h0 := hp + Vector3(0.2 * side, 0.18, -0.05)
		var h1 := h0 + Vector3(0.22 * side, 0.18, -0.05)
		var h2 := h1 + Vector3(0.05 * side, 0.22, 0.08)
		_bone(b, h0, h1, 0.07, toon(Color("d8cfb0")))
		_bone(b, h1, h2, 0.045, toon(Color("d8cfb0")))
	# arms: huge, gorilla stance (knuckles down); wind-up raises both, attack slams down in front
	for side in [-1.0, 1.0]:
		var sh := Vector3(0.75 * side, 1.55, 0.15)
		var fist := Vector3(0.95 * side, 0.22, 0.55)
		if pose == "windup":
			# both fists clasped high in front of the head: a clear "about to smash" silhouette
			fist = Vector3(0.2 * side, 2.75, 0.85)
		elif pose == "attack":
			fist = Vector3(0.35 * side, 0.22, 1.3)
		var el := (sh + fist) * 0.5 + Vector3(0.3 * side, 0.05, -0.1)
		_bone(b, sh, el, 0.22, bark)
		_bone(b, el, fist, 0.18, skin)
		var fs := 1.25 if pose != "idle" else 1.0
		add(b, sphere(0.27, 12), bark_dk, fist, Vector3.ZERO, Vector3(1.0, 0.85, 1.0) * fs)
		add(b, sphere(0.3, 12), moss, sh + Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1.0, 0.45, 1.0))
	if pose == "windup":
		# red glow gathering between the raised fists
		add(b, sphere(0.2, 12), toon(Color("ff3040"), 3.0, false), Vector3(0, 2.75, 0.95))
		add(b, sphere(0.38, 12), glow(Color("ff3040"), 0.25, 1.3), Vector3(0, 2.75, 0.95))
	# short thick legs
	for side in [-1.0, 1.0]:
		_bone(b, Vector3(0.35 * side, 0.75, -0.2), Vector3(0.4 * side, 0.15, -0.1), 0.2, bark)
		add(b, box(0.32, 0.14, 0.42), bark_dk, Vector3(0.4 * side, 0.07, 0.0))
	if elite:
		add(b, box(1.0, 0.18, 0.7), toon(Color("6a6070")), Vector3(0, 2.05, -0.15), Vector3(-0.3, 0, 0))
		for x in [-0.35, 0.0, 0.35]:
			add(b, cyl(0.0, 0.08, 0.32, 6), toon(Color("ffc830"), 1.2), Vector3(x, 2.28, -0.2))
		for side in [-1.0, 1.0]:
			add(b, box(0.4, 0.3, 0.4), toon(Color("6a6070")), Vector3(0.75 * side, 1.7, 0.15))


## Thornmaw, the Rotten Stag (boss 1). Rotting stag with an open ribcage and a cursed
## heart, bone skull, huge thorn-wrapped antlers, moss, glowing mushrooms and roots.
## pose: idle / slam (head down) / charge (head low, lunging) / howl (head up). enraged = phase 2.
static func boss(pose := "idle", enraged := false) -> Node3D:
	var root := Node3D.new()
	shadow(root, 2.2)
	var hide := toon(Color("2e2a3a"))
	var hide_dark := toon(Color("1f1b29"))
	var bone := toon(Color("d8ccaa"))
	var bone_dark := toon(Color("a89a78"))
	var thorn := toon(Color("4a1a2a"))
	var curse := Color("ff2030") if not enraged else Color("ff4a10")
	var hot := 4.0 if not enraged else 7.0
	var lean := 0.0 if pose != "charge" else 0.12
	var body := Node3D.new()
	body.rotation.x = lean
	root.add_child(body)
	# torso: long hide body, a sunken rotten flank with exposed ribs and the cursed heart
	add(body, capsule(0.78, 3.2), hide, Vector3(0, 2.0, 0), Vector3(PI / 2, 0, 0))
	add(body, sphere(0.85), hide, Vector3(0, 2.2, 0.85), Vector3.ZERO, Vector3(1.0, 1.0, 0.9))
	add(body, sphere(0.7), hide_dark, Vector3(0, 1.95, -1.1))
	add(body, sphere(0.55, 16), toon(Color("120a12")), Vector3(0.55, 1.95, 0.2), Vector3.ZERO, Vector3(0.6, 1.0, 1.5))
	add(body, sphere(0.55, 16), toon(Color("120a12")), Vector3(-0.55, 1.95, 0.2), Vector3.ZERO, Vector3(0.6, 1.0, 1.5))
	for sx in [-0.5, 0.5]:
		orb(body, Vector3(sx, 1.95, 0.25), 0.22, curse, 1.2 if not enraged else 2.2)
	for side in [-1.0, 1.0]:
		for i in 5:
			var z := 0.85 - i * 0.32
			var top := Vector3(0.25 * side, 2.72, z)
			var mid := Vector3(0.8 * side, 2.15, z + 0.06)
			var low := Vector3(0.62 * side, 1.42, z + 0.14)
			_bone(body, top, mid, 0.06, bone)
			_bone(body, mid, low, 0.05, bone)
	# spine of thorns, bigger towards the shoulders
	for i in 9:
		var z := 1.35 - i * 0.33
		var h := 0.35 + 0.35 * sin(PI * (i + 1) / 10.0)
		add(body, cyl(0.0, 0.1, h, 6), thorn, Vector3(0, 2.75 + h * 0.4, z), Vector3(-0.35, 0, 0))
		add(body, sphere(0.04, 6), toon(curse, hot, false), Vector3(0, 2.75 + h * 0.85, z - h * 0.3))
	# moss blankets, glowing mushrooms, hanging roots under the belly
	var moss := toon(Color("3f7a3a"))
	var moss_hi := toon(Color("5aa04a"))
	for p in [Vector3(0.5, 2.55, -0.6), Vector3(-0.55, 2.5, 0.5), Vector3(0.35, 2.65, 0.9), Vector3(-0.4, 2.45, -1.2), Vector3(0.6, 2.2, -1.4)]:
		add(body, sphere(0.32, 10), moss, p, Vector3.ZERO, Vector3(1.2, 0.45, 1.0))
		add(body, sphere(0.16, 8), moss_hi, p + Vector3(0.05, 0.1, 0.05), Vector3.ZERO, Vector3(1, 0.5, 1))
	for p in [Vector3(0.55, 2.7, -0.5), Vector3(0.7, 2.6, -0.7), Vector3(-0.6, 2.62, 0.45), Vector3(0.45, 2.45, -1.45)]:
		add(body, cyl(0.03, 0.04, 0.16, 6), toon(Color("d8d0c0")), p + Vector3(0, 0.08, 0))
		add(body, sphere(0.11, 10), toon(Color("3fe0d0"), 2.5, false), p + Vector3(0, 0.18, 0), Vector3.ZERO, Vector3(1, 0.45, 1))
	light(body, Vector3(0.6, 3.0, -0.6), Color("3fe0d0"), 0.8, 2.5)
	for i in 8:
		var p := Vector3(randf_range(-0.5, 0.5), 1.35, randf_range(-1.2, 1.0))
		var l := randf_range(0.35, 0.8)
		add(body, cyl(0.015, 0.035, l, 5), toon(Color("2a1a14"), 0.0, false), p - Vector3(0, l * 0.5, 0), Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)))
	add(body, cyl(0.0, 0.18, 0.6, 8), hide_dark, Vector3(0, 2.3, -1.75), Vector3(-1.1, 0, 0))
	# legs: jointed deer legs with dark hooves
	var leg := toon(Color("1c1826"))
	var hoof := toon(Color("0d0a10"))
	for side in [-1.0, 1.0]:
		var x: float = 0.5 * side
		var f := [Vector3(x, 1.75, 1.05), Vector3(x * 1.05, 0.95, 1.25), Vector3(x, 0.2, 1.1)]
		_bone(root, f[0], f[1], 0.17, leg)
		_bone(root, f[1], f[2], 0.11, leg)
		add(root, cyl(0.1, 0.14, 0.22, 8), hoof, f[2] + Vector3(0, -0.06, 0.02))
		var b := [Vector3(x, 1.95, -1.15), Vector3(x * 1.05, 1.15, -1.55), Vector3(x, 0.55, -1.2), Vector3(x, 0.2, -1.32)]
		_bone(root, b[0], b[1], 0.22, leg)
		_bone(root, b[1], b[2], 0.12, leg)
		_bone(root, b[2], b[3], 0.1, leg)
		add(root, cyl(0.1, 0.14, 0.22, 8), hoof, b[3] + Vector3(0, -0.06, 0))
		add(root, sphere(0.1, 8), bone_dark, f[1] + Vector3(0.08 * side, 0, 0.06))
	# neck + head on a pivot so poses can lower or raise it
	var head := Node3D.new()
	head.position = Vector3(0, 2.45, 1.35)
	head.rotation.x = {"idle": 0.0, "slam": 0.75, "charge": 0.45, "howl": -0.55}.get(pose, 0.0)
	body.add_child(head)
	_bone(head, Vector3.ZERO, Vector3(0, 0.85, 0.65), 0.42, hide)
	for i in 6:
		var k := i / 5.0
		add(head, cyl(0.0, 0.08, 0.45, 6), thorn, Vector3(0, 0.45 + 0.4 * k, 0.3 * k - 0.25), Vector3(-1.0, 0, 0))
	var skull := Vector3(0, 1.0, 0.85)
	add(head, sphere(0.42, 20), bone, skull, Vector3(0.25, 0, 0), Vector3(0.95, 0.85, 1.25))
	_bone(head, skull + Vector3(0, -0.08, 0.3), skull + Vector3(0, -0.3, 0.85), 0.2, bone)
	add(head, sphere(0.13, 10), bone_dark, skull + Vector3(0, -0.32, 0.88))
	_bone(head, skull + Vector3(0, -0.28, 0.2), skull + Vector3(0, -0.5, 0.7), 0.1, bone_dark)
	for i in 4:
		var tz := 0.35 + i * 0.1
		add(head, cyl(0.0, 0.025, 0.12, 5), bone, skull + Vector3(0.09, -0.32 - tz * 0.3, tz), Vector3(PI, 0, 0))
		add(head, cyl(0.0, 0.025, 0.12, 5), bone, skull + Vector3(-0.09, -0.32 - tz * 0.3, tz), Vector3(PI, 0, 0))
	for side in [-1.0, 1.0]:
		add(head, sphere(0.13, 10), toon(Color("0a0608")), skull + Vector3(0.21 * side, 0.06, 0.25))
		add(head, sphere(0.075, 8), toon(curse, 6.0, false), skull + Vector3(0.23 * side, 0.06, 0.3))
		add(head, cyl(0.02, 0.06, 0.12, 6), bone_dark, skull + Vector3(0.35 * side, 0.05, 0.05), Vector3(0, 0, -1.3 * side))
		_antler(head, skull + Vector3(0.2 * side, 0.3, -0.1), side, bone, thorn, curse, hot)
	light(head, skull + Vector3(0, -0.3, 1.3), curse, 0.5, 1.6)
	# floating spores and the enraged aura
	for i in 14:
		var p := Vector3(randf_range(-1.5, 1.5), randf_range(1.0, 3.6), randf_range(-1.8, 2.2))
		add(root, sphere(0.035, 6), glow(Color("9aff70"), 0.8, 2.0), p)
	if enraged:
		add(root, sector(2.0, 2.15, 0, TAU, 48), glow(curse, 0.9, 2.0), Vector3(0, 0.04, 0))
		for i in 6:
			var a := TAU * i / 6.0
			add(root, cyl(0.0, 0.05, 1.4, 5), glow(curse, 0.5, 2.0), Vector3(cos(a) * 1.4, 0.7, sin(a) * 1.4))
	return root


## One antler: a beam that sweeps out and back with 4 tines, wrapped in thorns, moss hanging.
static func _antler(root: Node3D, base: Vector3, side: float, mat: Material, thorn_mat: Material, curse: Color, hot: float) -> void:
	var pts := [base, base + Vector3(0.36 * side, 0.44, -0.12), base + Vector3(0.8 * side, 0.92, -0.24), base + Vector3(1.08 * side, 1.56, -0.2)]
	for i in 3:
		_bone(root, pts[i], pts[i + 1], 0.1 - i * 0.02, mat)
	var tines := [[1, Vector3(0.7 * side, 1.0, 0.35)], [2, Vector3(1.6 * side, 1.4, 0.15)], [2, Vector3(0.75 * side, 1.85, -0.05)], [3, Vector3(1.9 * side, 2.3, -0.2)], [3, Vector3(1.15 * side, 2.45, -0.35)]]
	for t in tines:
		var a: Vector3 = pts[t[0]]
		var tip: Vector3 = base + t[1] * 0.8
		_bone(root, a, tip, 0.05, mat)
		add(root, sphere(0.06, 8), toon(curse, hot, false), tip)
	for i in 3:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		for k in 3:
			var p := a.lerp(b, (k + 0.5) / 3.0)
			add(root, cyl(0.0, 0.04, 0.16, 5), thorn_mat, p + Vector3(0.05 * side, 0.02, 0.05 * (k - 1)), Vector3(0.6 * (k - 1), 0, 1.2 * side))
	var moss := toon(Color("4a8a3a"), 0.0, false)
	for i in [1, 2]:
		var p: Vector3 = pts[i] + Vector3(0.1 * side, 0, 0)
		add(root, cyl(0.03, 0.01, 0.5, 5), moss, p - Vector3(0, 0.25, 0))


# --- baking (one mesh per pose instead of ~100 nodes) ---

static var _poses := {}


## Body mesh of a hero/enemy in a pose, baked once and cached.
## pose: idle / walk_a / walk_b / windup / attack (enemies have no walk poses).
static func pose_mesh(hero_model: bool, kind: String, pose: String, elite := false) -> ArrayMesh:
	var key := "%s_%s_%s_%s" % [hero_model, kind, pose, elite]
	if _poses.has(key):
		return _poses[key]
	var am: ArrayMesh
	var root: Node3D
	if kind == "boss":
		# Thornmaw: the whole model (legs hang off the root); elite = enraged
		root = boss(pose, elite)
		am = bake(root)
		root.free()
		_poses[key] = am
		return am
	root = hero(kind, pose) if hero_model else enemy(kind, elite, pose)
	am = bake(root.get_node("body"))
	root.free()
	_poses[key] = am
	return am


## Merges every mesh under n (n's own transform included) into one ArrayMesh with one
## surface per material. Lights and other nodes are skipped.
static func bake(n: Node3D) -> ArrayMesh:
	var groups := {}
	_bake_walk(n, n.transform, groups)
	var am := ArrayMesh.new()
	for mat in groups:
		var g: Array = groups[mat]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g[0]
		arr[Mesh.ARRAY_NORMAL] = g[1]
		arr[Mesh.ARRAY_INDEX] = g[2]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, mat)
	return am


static func _bake_walk(n: Node3D, xf: Transform3D, groups: Dictionary) -> void:
	if n is MeshInstance3D and n.mesh:
		var mat: Material = n.material_override
		if not groups.has(mat):
			groups[mat] = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()]
		var g: Array = groups[mat]
		var nb := xf.basis.inverse().transposed()
		for s in n.mesh.get_surface_count():
			var a: Array = n.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var ns = a[Mesh.ARRAY_NORMAL]
			var has_n: bool = ns != null and ns.size() == vs.size()
			var base: int = g[0].size()
			for i in vs.size():
				g[0].append(xf * vs[i])
				g[1].append((nb * ns[i]).normalized() if has_n else Vector3.UP)
			var idx = a[Mesh.ARRAY_INDEX]
			if idx != null and idx.size() > 0:
				for k in idx:
					g[2].append(base + k)
			else:
				for k in vs.size():
					g[2].append(base + k)
	for c in n.get_children():
		if c is Node3D:
			_bake_walk(c, xf * c.transform, groups)


static func _bone(root: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := add(root, cyl(r * 0.75, r, a.distance_to(b), 10), mat, (a + b) * 0.5)
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	elif dir.y < 0.0:
		mi.basis = Basis(Vector3.RIGHT, PI)
	add(root, sphere(r, 10), mat, b)
	return mi


# --- effects ---

static func telegraph_circle(parent: Node3D, pos: Vector3, r: float) -> void:
	add(parent, sector(0, r, 0, TAU, 40), flat(Color(1, 0.15, 0.2, 0.2)), pos + Vector3(0, 0.03, 0))
	add(parent, sector(r - 0.07, r, 0, TAU, 40), glow(Color("ff3040"), 1.0, 1.5), pos + Vector3(0, 0.04, 0))


static func telegraph_cone(parent: Node3D, pos: Vector3, dir: float, r: float, half: float, fill := 0.6) -> void:
	add(parent, sector(0, r, dir - half, dir + half), flat(Color(1, 0.15, 0.2, 0.18)), pos + Vector3(0, 0.03, 0))
	add(parent, sector(0, r * fill, dir - half, dir + half), flat(Color(1, 0.2, 0.25, 0.25)), pos + Vector3(0, 0.035, 0))
	add(parent, sector(r - 0.07, r, dir - half, dir + half), glow(Color("ff3040"), 1.0, 1.5), pos + Vector3(0, 0.04, 0))


static func telegraph_line(parent: Node3D, pos: Vector3, dir: float, length: float, w: float) -> void:
	var m := add(parent, box(w, 0.01, length), flat(Color(1, 0.15, 0.2, 0.22)), pos + Vector3(sin(dir) * length * 0.5, 0.03, cos(dir) * length * 0.5))
	m.rotation.y = dir
	for s in [-1.0, 1.0]:
		var e := add(parent, box(0.06, 0.01, length), glow(Color("ff3040"), 1.0, 1.5), Vector3.ZERO)
		e.rotation.y = dir
		e.position = pos + Vector3(sin(dir) * length * 0.5, 0.04, cos(dir) * length * 0.5) + Vector3(cos(dir), 0, -sin(dir)) * w * 0.5 * s


static func orb(parent: Node3D, pos: Vector3, r: float, c: Color, lit := 2.0) -> void:
	add(parent, sphere(r * 0.6), toon(Color(c.lightened(0.6)), 5.0, false), pos)
	add(parent, sphere(r), glow(c, 0.55), pos)
	add(parent, sphere(r * 1.5), glow(c, 0.15), pos)
	if lit > 0.0:
		light(parent, pos, c, lit, r * 8.0)


static func beam(parent: Node3D, a: Vector3, b: Vector3, r: float, c: Color) -> void:
	var mi := add(parent, cyl(r, r, a.distance_to(b), 10), glow(c, 0.9), (a + b) * 0.5)
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	var mo := add(parent, cyl(r * 2.5, r * 2.5, a.distance_to(b), 10), glow(c, 0.18), (a + b) * 0.5)
	mo.basis = mi.basis


## Horizontal crescent slash ribbon around pos, facing angle dir.
static func slash(parent: Node3D, pos: Vector3, dir: float, r: float, c: Color, span := 2.0, width := 0.35) -> void:
	add(parent, sector(r - width, r, dir - span * 0.5, dir + span * 0.5), glow(c, 0.85), pos)
	add(parent, sector(r - 0.05, r + 0.03, dir - span * 0.5, dir + span * 0.5), glow(Color.WHITE, 0.9, 1.5), pos + Vector3(0, 0.01, 0))
	light(parent, pos + Vector3(cos(dir) * r, 0.3, sin(dir) * r), c, 1.8, 3.0)


static func spikes(parent: Node3D, pos: Vector3, c: Color, h: float, n := 1) -> void:
	for i in n:
		var o := Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15)) if n > 1 else Vector3.ZERO
		add(parent, cyl(0.0, 0.14, h, 6), toon(c, 0.6), pos + o + Vector3(0, h * 0.5, 0), Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)))


static func tornado(parent: Node3D, pos: Vector3, h: float, c: Color) -> void:
	for i in 7:
		var k := i / 6.0
		var r := 0.18 + 0.55 * k
		add(parent, torus(r * 0.82, r), glow(c, 0.45 - 0.03 * i, 1.6), pos + Vector3(sin(k * 5.0) * 0.12, 0.15 + k * h, cos(k * 5.0) * 0.12), Vector3(0.15 * sin(i), 0, 0.15 * cos(i)))


static func rock(parent: Node3D, pos: Vector3, r: float) -> void:
	add(parent, sphere(r, 6), toon(Color("7a6048")), pos, Vector3(0.4, 0.7, 0.2), Vector3(1.1, 0.9, 1))


static func cracks(parent: Node3D, pos: Vector3, r: float, c: Color) -> void:
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var m := add(parent, box(0.07, 0.01, r), glow(c, 0.9, 2.0), pos + Vector3(cos(a) * r * 0.5, 0.04, sin(a) * r * 0.5))
		m.rotation.y = -a + PI / 2


# --- places (points of interest) ---

## state: "" normal, "open" (chest), "used" (altar), "off"/"on" (waystone).
static func poi(kind: String, state := "") -> Node3D:
	var n := Node3D.new()
	n.set_meta("poi_model", true)
	var stone := toon(Color("5a5670"))
	var stone_hi := toon(Color("7a7690"))
	match kind:
		"moonwell":
			add(n, cyl(1.2, 1.35, 0.5, 24), stone, Vector3(0, 0.25, 0))
			add(n, torus(1.0, 1.25), stone_hi, Vector3(0, 0.5, 0))
			add(n, cyl(1.0, 1.0, 0.05, 24), toon(Color("6ab8ff"), 3.0, false), Vector3(0, 0.46, 0))
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				add(n, box(0.25, 1.3, 0.25), stone, Vector3(cos(a) * 1.25, 0.65, sin(a) * 1.25))
				add(n, sphere(0.1, 8), toon(Color("bfe0ff"), 4.0, false), Vector3(cos(a) * 1.25, 1.4, sin(a) * 1.25))
		"chest":
			var wood := toon(Color("4a2a1a"))
			var gold := toon(Color("d8a030"), 0.4)
			add(n, box(1.1, 0.6, 0.7), wood, Vector3(0, 0.3, 0))
			for x in [-0.4, 0.4]:
				add(n, box(0.1, 0.62, 0.72), gold, Vector3(x, 0.3, 0))
			var lid := Node3D.new()
			lid.position = Vector3(0, 0.6, -0.35)
			lid.rotation.x = -1.6 if state == "open" else 0.0
			n.add_child(lid)
			add(lid, cyl(0.35, 0.35, 1.1, 12), wood, Vector3(0, 0, 0.35), Vector3(0, 0, PI / 2), Vector3(1, 1, 1))
			add(lid, box(0.18, 0.22, 0.08), gold, Vector3(0, -0.05, 0.72))
			if state != "open":
				add(n, sphere(0.06, 8), toon(Color("c060ff"), 5.0, false), Vector3(0, 0.55, 0.37))
			else:
				orb(n, Vector3(0, 0.7, 0), 0.2, Color("c060ff"), 1.0)
		"den":
			add(n, sphere(1.5, 14), toon(Color("3a3448")), Vector3(0, 0.3, -0.4), Vector3.ZERO, Vector3(1.3, 0.8, 1.0))
			add(n, sphere(0.75, 12), toon(Color("0a0610")), Vector3(0, 0.45, 0.55), Vector3.ZERO, Vector3(1.1, 0.9, 0.6))
			for side in [-1.0, 1.0]:
				add(n, sphere(0.07, 8), toon(Color("ff3040"), 6.0, false), Vector3(0.18 * side, 0.6, 0.85))
				add(n, cyl(0.0, 0.18, 0.9, 6), toon(Color("d8cfb0")), Vector3(0.9 * side, 0.9, 0.3), Vector3(0.3, 0, -0.5 * side))
			for i in 5:
				add(n, cyl(0.04, 0.05, 0.4, 5), toon(Color("d8d0b8")), Vector3(randf_range(-1, 1), 0.06, randf_range(0.8, 1.4)), Vector3(PI / 2, randf() * TAU, 0))
		"merchant":
			var c := Color("60f0ff")
			add(n, cyl(0.15, 0.55, 1.5, 14), glow(c, 0.35, 1.2), Vector3(0, 0.95, 0))
			add(n, sphere(0.32, 14), glow(c, 0.45, 1.2), Vector3(0, 1.85, 0))
			add(n, sphere(0.24, 12), toon(Color("061018")), Vector3(0, 1.82, 0.1))
			eyes(n, Vector3(0, 1.85, 0.3), 0.08, c, 0.04)
			add(n, cyl(0.02, 0.02, 0.5, 5), toon(Color("3a3040")), Vector3(0.55, 1.3, 0.2))
			orb(n, Vector3(0.55, 0.95, 0.2), 0.14, Color("ffd060"), 1.2)
			add(n, box(1.2, 0.5, 0.6), toon(Color("3a2a40")), Vector3(0, 0.25, 0.8))
			for i in 3:
				add(n, sphere(0.09, 8), toon([Color("ff5070"), Color("70ff90"), Color("b070ff")][i], 3.0, false), Vector3(-0.35 + i * 0.35, 0.6, 0.8))
		"rune":
			add(n, box(0.9, 2.6, 0.55), stone, Vector3(0, 1.3, 0), Vector3(0, 0.3, 0.04))
			add(n, cyl(0.0, 0.48, 0.5, 4), stone_hi, Vector3(0, 2.85, 0), Vector3(0, PI / 4 + 0.3, 0))
			for i in 3:
				add(n, box(0.08, 0.35, 0.05), toon(Color("60ff9a"), 4.0, false), Vector3(0.08 * (i - 1), 1.0 + i * 0.5, 0.3), Vector3(0, 0.3, 0.4 * (i - 1)))
		"altar":
			var lit := state != "used"
			add(n, box(1.6, 0.8, 1.0), stone, Vector3(0, 0.4, 0))
			add(n, box(1.8, 0.15, 1.2), stone_hi, Vector3(0, 0.85, 0))
			add(n, sector(0, 0.5, 0, TAU, 20), glow(Color("ff3060"), 0.8 if lit else 0.15, 2.0 if lit else 1.0), Vector3(0, 0.94, 0))
			for x in [-0.7, 0.7]:
				add(n, cyl(0.06, 0.06, 0.3, 6), toon(Color("e0d8c0")), Vector3(x, 1.08, 0.4))
				if lit:
					add(n, sphere(0.06, 6), toon(Color("ffb040"), 5.0, false), Vector3(x, 1.28, 0.4))
		"gate":
			for side in [-1.0, 1.0]:
				add(n, box(0.9, 4.2, 0.9), stone, Vector3(2.2 * side, 2.1, 0))
				add(n, cyl(0.0, 0.25, 1.0, 5), toon(Color("5a2a3a")), Vector3(2.2 * side, 4.6, 0))
			add(n, box(5.5, 0.8, 1.0), stone_hi, Vector3(0, 4.4, 0))
			add(n, cyl(1.8, 1.8, 0.1, 32), glow(Color("ff3060"), 0.55, 1.6), Vector3(0, 2.1, 0), Vector3(PI / 2, 0, 0), Vector3(1, 1, 1.0))
			add(n, torus(1.65, 1.85), toon(Color("ff3060"), 3.0, false), Vector3(0, 2.1, 0), Vector3(PI / 2, 0, 0))
			add(n, sphere(0.35, 12), toon(Color("e8dcc0")), Vector3(0, 4.9, 0.3))
			eyes(n, Vector3(0, 4.92, 0.6), 0.12, Color("ff3040"), 0.06)
		"waystone":
			var on := state != "off"
			var c := Color("70d0ff")
			add(n, cyl(0.0, 0.45, 2.2, 4), stone, Vector3(0, 1.1, 0), Vector3(0, PI / 4, 0))
			add(n, cyl(0.6, 0.7, 0.25, 8), stone_hi, Vector3(0, 0.12, 0))
			add(n, box(0.07, 0.6, 0.05), toon(c, 4.0 if on else 0.0, false) if on else toon(Color("3a3a4a")), Vector3(0, 1.0, 0.25))
			if on:
				orb(n, Vector3(0, 2.5, 0), 0.15, c, 1.0)
	return n
