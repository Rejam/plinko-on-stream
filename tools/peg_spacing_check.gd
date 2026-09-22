@tool
extends EditorScript

## On-demand peg spacing check. Open a board scene, then File > Run (Ctrl+Shift+X).
##
## Why the peg-peg limit is exhaustive rather than a heuristic:
## the ball has friction 0, so a single contact gives one normal force along the
## peg-centre-to-ball-centre line, which balances gravity only at an unstable
## equilibrium the release impulse destroys. A ball can therefore only come to
## rest touching two pegs at once. Every peg touching the ball has its centre
## exactly (ball_r + peg_r) from the ball centre, so by the triangle inequality
## two simultaneous contacts are at most 2 * (ball_r + peg_r) apart. Keep every
## pair above that and no arrangement of pegs — pairs, pockets, anything — can
## trap a ball. Three-peg pockets need no separate rule; any two of the three
## contacts would themselves have to be within the limit.
##
## Walls are a flat surface rather than a second circle: the ball passes a
## peg-to-face gap wider than its own diameter, so the peg centre must clear the
## face by 2 * ball_r + peg_r.
##
## Markers are added as an internal, unowned child so they are never serialised
## into the .tscn and never appear in the scene tree dock. A run with no
## violations leaves nothing behind, so fixing the board clears the display.

const PEG_SCENE := "uid://ctc64dnv2jawv"
const BALL_SCENE := "uid://cthrtlsbusy3"
const MARKER_NAME := "__SpacingCheck"

## Amber band above the hard limit: flagged as having no margin, not as broken.
## Set to 1.0 to report only genuine violations.
const MARGIN_FACTOR := 1.125

const HARD_COLOUR := Color(1.0, 0.15, 0.15)
const WARN_COLOUR := Color(1.0, 0.7, 0.0, 0.5)

## Bucket dividers are a different authoring problem — pegs sit well clear of
## them by construction, and folding them in here drags the reported peg-wall
## minimum down to bucket geometry, hiding the board-wall headroom. Flip to true
## if that ever stops being true.
const INCLUDE_BUCKET_WALLS := false


func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("Spacing check: no scene open.")
		return

	_clear_markers(root)

	var pegs: Array[Node] = []
	_collect(root, pegs, func(n: Node) -> bool: return n is Peg)
	if pegs.is_empty():
		print("Spacing check: no Peg nodes under %s." % root.name)
		return

	var ball_r := _scene_circle_radius(BALL_SCENE)
	var peg_r := _scene_circle_radius(PEG_SCENE)
	if ball_r <= 0.0 or peg_r <= 0.0:
		push_error("Spacing check: could not read radii (ball %.1f, peg %.1f)." % [ball_r, peg_r])
		return

	var peg_limit := 2.0 * (ball_r + peg_r)
	var wall_limit := 2.0 * ball_r + peg_r

	var markers := Node2D.new()
	markers.name = MARKER_NAME
	root.add_child(markers, false, Node.INTERNAL_MODE_BACK)

	var report: Array[String] = []
	var hard := 0
	var warn := 0
	var unsupported: Array[String] = []

	# --- peg to peg ---
	var closest_pair := INF
	for i in pegs.size():
		for j in range(i + 1, pegs.size()):
			var a := pegs[i] as Node2D
			var b := pegs[j] as Node2D
			var d := a.global_position.distance_to(b.global_position)
			closest_pair = minf(closest_pair, d)
			if d >= peg_limit * MARGIN_FACTOR:
				continue
			var breach := d < peg_limit
			hard += int(breach)
			warn += int(not breach)
			_mark(markers, a.global_position, b.global_position, HARD_COLOUR if breach else WARN_COLOUR)
			report.append("  %s %6.1f  %s <-> %s" % [
				"TRAP " if breach else "tight",
				d,
				root.get_path_to(a),
				root.get_path_to(b),
			])

	# --- peg to wall ---
	var walls: Array[Node] = []
	_collect(root, walls, func(n: Node) -> bool: return _is_board_wall(n))
	var faces: Array[CollisionShape2D] = []
	for wall in walls:
		for child in wall.get_children():
			if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
				faces.append(child)

	var closest_wall := INF
	for peg in pegs:
		var p := (peg as Node2D).global_position
		for face in faces:
			var found: Variant = _nearest_point(face, p)
			if found == null:
				var kind := face.shape.get_class()
				if not unsupported.has(kind):
					unsupported.append(kind)
				continue
			var nearest: Vector2 = found
			var d := p.distance_to(nearest)
			closest_wall = minf(closest_wall, d)
			if d >= wall_limit * MARGIN_FACTOR:
				continue
			var breach := d < wall_limit
			hard += int(breach)
			warn += int(not breach)
			_mark(markers, p, nearest, HARD_COLOUR if breach else WARN_COLOUR)
			report.append("  %s %6.1f  %s -> %s" % [
				"TRAP " if breach else "tight",
				d,
				root.get_path_to(peg),
				root.get_path_to(face),
			])

	# --- summary ---
	print("Spacing check - %s" % root.name)
	print("  ball r %.1f, peg r %.1f  ->  peg-peg min %.1f, peg-wall min %.1f" % [
		ball_r, peg_r, peg_limit, wall_limit,
	])
	print("  %d pegs, %d board wall faces" % [pegs.size(), faces.size()])
	print("  closest peg pair %.1f, closest peg-wall %.1f" % [closest_pair, closest_wall])
	if not unsupported.is_empty():
		push_warning("Spacing check: skipped unsupported shape types %s - those faces were NOT checked." % ", ".join(unsupported))
	if report.is_empty():
		print("  clean")
	else:
		report.sort()
		print("  %d traps, %d without margin" % [hard, warn])
		for line in report:
			print(line)


## Board walls only by default: a PhysicsBody2D that is not a Peg and not inside
## a Bucket. Bucket mouths are Area2D, so they are excluded by the type test
## alone; the dividers and bases underneath them are not.
func _is_board_wall(node: Node) -> bool:
	if not (node is PhysicsBody2D) or node is Peg:
		return false
	if INCLUDE_BUCKET_WALLS:
		return true
	var parent := node.get_parent()
	while parent != null:
		if parent is Bucket:
			return false
		parent = parent.get_parent()
	return true


func _collect(node: Node, out: Array[Node], predicate: Callable) -> void:
	if predicate.call(node):
		out.append(node)
	for child in node.get_children():
		_collect(child, out, predicate)


## Radii are read off a fresh instance of the scene rather than off a node in
## the edited tree. The tree walk returned 0 for a peg that demonstrably has a
## CircleShape2D child in the editor — cause not established — while the same
## walk over a freshly instantiated scene works. If this ever returns 0 the
## error names the children it actually saw, which is the missing evidence.
func _scene_circle_radius(scene_path: String) -> float:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Spacing check: could not load %s." % scene_path)
		return 0.0
	var node := packed.instantiate()
	var r := _circle_radius(node)
	if r <= 0.0:
		var kinds: Array[String] = []
		for child in node.get_children():
			kinds.append("%s (%s)" % [child.name, child.get_class()])
		push_error("Spacing check: no CircleShape2D under %s - children were %s." % [scene_path, kinds])
	node.free()
	return r


## First CircleShape2D found on any CollisionShape2D at or below the node.
func _circle_radius(body: Node) -> float:
	for child in body.get_children():
		if child is CollisionShape2D:
			var shape := (child as CollisionShape2D).shape
			if shape is CircleShape2D:
				return (shape as CircleShape2D).radius
		var nested := _circle_radius(child)
		if nested > 0.0:
			return nested
	return 0.0


## Nearest point on the shape to a global point, or null if the shape type is
## not handled. Computed in shape-local space, then returned in global space, so
## the caller measures the distance in world units.
func _nearest_point(face: CollisionShape2D, global_point: Vector2) -> Variant:
	var xform := face.global_transform
	var local := xform.affine_inverse() * global_point
	var shape := face.shape
	var nearest_local: Vector2
	if shape is RectangleShape2D:
		var half: Vector2 = (shape as RectangleShape2D).size * 0.5
		nearest_local = Vector2(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y))
	elif shape is CircleShape2D:
		var r: float = (shape as CircleShape2D).radius
		nearest_local = local.normalized() * r if local.length() > 0.0 else Vector2(r, 0.0)
	else:
		return null
	return xform * nearest_local


func _mark(parent: Node2D, a: Vector2, b: Vector2, colour: Color) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = colour
	line.points = PackedVector2Array([parent.to_local(a), parent.to_local(b)])
	parent.add_child(line)


func _clear_markers(root: Node) -> void:
	for child in root.get_children(true):
		if child.name == MARKER_NAME:
			root.remove_child(child)
			child.free()
