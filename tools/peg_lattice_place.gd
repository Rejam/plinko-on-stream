@tool
extends EditorScript

## Places a triangular lattice of pegs into the open board. File > Run.
##
## Columns are fixed: every row uses the same SPACING and alternate rows are
## offset by exactly half of it, which is what makes this a quincunx. The
## density gradient lives entirely in the row pitch.
##
## An earlier version interpolated the horizontal spacing instead. That was
## wrong: rows stepping by different spacings from a common left edge accumulate
## different offsets, so they drift out of phase across the board and line up
## into vertical columns wherever they happen to coincide — the exact corridors
## a lattice is meant to make impossible. Row pitch is also the better knob:
## rows are what set how many deflections the ball gets, while horizontal
## spacing only sets how far each one moves it.
##
## Nothing is avoided. The lattice fills the band regardless of what is already
## there; deleting the pegs that clash with the lettering is an authoring
## decision, not one this script should be making. Run the spacing check after
## to catch anything the deletions left too close.
##
## Output lives in a single owned child node, rebuilt from scratch on every run.
## Owned, unlike the spacing check's markers, because these pegs are meant to be
## saved. Re-running discards the previous lattice and nothing else.

const PEG_SCENE := "res://scenes/game/peg/peg.tscn"
const BALL_SCENE := "res://scenes/game/ball/ball.tscn"
const LATTICE_NAME := "Lattice"

## Node the lattice is parented under, relative to the scene root.
const PARENT_PATH := "Pegs"

## Constant horizontal spacing. Alternate rows are offset by half of it.
const SPACING := 90.0

## Vertical distance between rows, interpolated with depth. TOP < BOTTOM gives
## a dense field at the top opening out toward the buckets. Equal values give a
## uniform lattice. 0.866 * SPACING reproduces the equilateral case.
const TOP_PITCH := 55.0
const BOTTOM_PITCH := 95.0

## Band to fill, in the parent's coordinate space.
const TOP_Y := 200.0
const BOTTOM_Y := 900.0
const LEFT_X := 60.0
const RIGHT_X := 1540.0

const ROW_PITCH_RATIO := 0.8660254


func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("Lattice: no scene open.")
		return

	var parent := root.get_node_or_null(PARENT_PATH) as Node2D
	if parent == null:
		push_error("Lattice: no Node2D at '%s' under %s." % [PARENT_PATH, root.name])
		return

	var ball_r := _scene_circle_radius(BALL_SCENE)
	var peg_r := _scene_circle_radius(PEG_SCENE)
	if ball_r <= 0.0 or peg_r <= 0.0:
		push_error("Lattice: could not read radii (ball %.1f, peg %.1f)." % [ball_r, peg_r])
		return

	var peg_limit := 2.0 * (ball_r + peg_r)
	var wall_limit := 2.0 * ball_r + peg_r
	var tightest_pitch := minf(TOP_PITCH, BOTTOM_PITCH)
	var tightest_diagonal := Vector2(SPACING * 0.5, tightest_pitch).length()
	if SPACING <= peg_limit:
		push_error("Lattice: SPACING %.1f is at or below the trap limit %.1f - every neighbour in a row would hold a ball." % [SPACING, peg_limit])
		return
	if tightest_diagonal <= peg_limit:
		push_error("Lattice: diagonal %.1f at pitch %.1f is at or below the trap limit %.1f - rows are too close for this spacing." % [tightest_diagonal, tightest_pitch, peg_limit])
		return

	var packed := load(PEG_SCENE) as PackedScene
	if packed == null:
		push_error("Lattice: could not load %s." % PEG_SCENE)
		return

	var old := parent.get_node_or_null(LATTICE_NAME)
	if old != null:
		parent.remove_child(old)
		old.free()

	var faces := _wall_faces(root)

	var lattice := Node2D.new()
	lattice.name = LATTICE_NAME
	parent.add_child(lattice)
	lattice.owner = root

	var placed := 0
	var skipped_walls := 0
	var row := 0
	var y := TOP_Y

	while y <= BOTTOM_Y:
		var t := 0.0 if is_equal_approx(BOTTOM_Y, TOP_Y) else clampf((y - TOP_Y) / (BOTTOM_Y - TOP_Y), 0.0, 1.0)
		var pitch := lerpf(TOP_PITCH, BOTTOM_PITCH, t)
		var x := LEFT_X + (0.0 if row % 2 == 0 else SPACING * 0.5)
		while x <= RIGHT_X:
			var local := Vector2(x, y)
			var global_point := lattice.to_global(local)
			if _too_close_to_wall(global_point, faces, wall_limit):
				skipped_walls += 1
			else:
				var peg := packed.instantiate() as Node2D
				peg.position = local
				lattice.add_child(peg)
				peg.owner = root
				placed += 1
			x += SPACING
		y += pitch
		row += 1

	print("Lattice - %s" % root.name)
	print("  spacing %.1f, pitch %.1f to %.1f, diagonal %.1f (trap limit %.1f), %d rows" % [SPACING, TOP_PITCH, BOTTOM_PITCH, tightest_diagonal, peg_limit, row])
	print("  placed %d, skipped %d near walls" % [placed, skipped_walls])
	print("  save the scene to keep them")


func _too_close_to_peg(point: Vector2, existing: Array[Vector2], keep_out: float) -> bool:
	for other in existing:
		if point.distance_to(other) < keep_out:
			return true
	return false


func _too_close_to_wall(point: Vector2, faces: Array[CollisionShape2D], limit: float) -> bool:
	for face in faces:
		var found: Variant = _nearest_point(face, point)
		if found == null:
			continue
		var nearest: Vector2 = found
		if point.distance_to(nearest) < limit:
			return true
	return false


func _collect_peg_positions(node: Node, out: Array[Vector2]) -> void:
	if node is Peg:
		out.append((node as Node2D).global_position)
	for child in node.get_children():
		_collect_peg_positions(child, out)


## Board walls only: a PhysicsBody2D that is not a Peg and not inside a Bucket.
func _wall_faces(root: Node) -> Array[CollisionShape2D]:
	var faces: Array[CollisionShape2D] = []
	_gather_faces(root, faces)
	return faces


func _gather_faces(node: Node, faces: Array[CollisionShape2D]) -> void:
	if node is PhysicsBody2D and not node is Peg and not _inside_bucket(node):
		for child in node.get_children():
			if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
				faces.append(child)
	for child in node.get_children():
		_gather_faces(child, faces)


func _inside_bucket(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is Bucket:
			return true
		parent = parent.get_parent()
	return false


func _scene_circle_radius(scene_path: String) -> float:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return 0.0
	var node := packed.instantiate()
	var r := _circle_radius(node)
	node.free()
	return r


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
