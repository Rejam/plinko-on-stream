@tool
extends EditorScript

## Places a bowed peg field into the open board. File > Run.
##
## An alternative to the quincunx, for boards that were starting to read the
## same. Rows still span the full width at a constant SPACING with alternate
## rows half-offset — that part is load-bearing and unchanged. What curves is
## the row itself: each row is a dome, deepest at the edges, and the dome grows
## with depth down the board.
##
## True concentric rings were worked through and abandoned. A ring centred above
## the board meets the band along the bottom of its circle, so small radii only
## reach the middle and the top corners get no pegs; putting the focus below
## moves the same hole to the bottom corners. Either way the field leaves
## unpegged bands down the sides, which are the corridors a peg field exists to
## prevent. Bowing full-width rows gives the same fan read with no hole.
##
## The lattice can prove its tightest pair is the row diagonal because its rows
## are straight. These rows are not, so the vertical gap varies across x and
## there is no single pair to derive. This measures the real closest pair after
## laying the field out, and refuses to build if it is inside the trap limit.
##
## Nothing is avoided, same as the lattice: the field fills the band regardless
## of lettering, and existing pegs are not in the closest-pair check. Delete the
## clashes by hand, then run the spacing check, which audits the whole board.
##
## Self-contained, like the lattice script. The two duplicate their wall test;
## sharing it would cost a third file to save one function.

const PEG_SCENE := "res://scenes/game/peg/peg.tscn"
const BALL_SCENE := "res://scenes/game/ball/ball.tscn"
const FIELD_NAME := "Arcs"

## Node the field is parented under, relative to the scene root.
const PARENT_PATH := "Pegs"

## Constant horizontal spacing. Alternate rows are offset by half of it.
const SPACING := 90.0

## Vertical distance between row baselines, interpolated with depth. TOP <
## BOTTOM keeps the dense-top rule: a sparse top lets the ball reach full speed
## before its first contact, and fast contacts at 60Hz skitter.
const TOP_PITCH := 55.0
const BOTTOM_PITCH := 95.0

## Total height of a row's curve, edge to centre, interpolated with depth. The
## dome is centred on the baseline (u² - 0.5), so a row rises half a sag above
## its baseline in the middle and falls half below at the ends. Centred rather
## than hanging: same curvature for half the downward reach, which matters
## because a peg carried past BOTTOM_Y is dropped and thins the bottom corners.
##
## Read these as a fraction of the 1480px span. 80 was a 5% deviation and did
## not read as a curve at all; u² also concentrates the bend in the outer
## quarter, so halfway out you only see a quarter of the sag. Both numbers have
## to be large before the field stops looking like a slightly droopy lattice.
##
## SAG_BOTTOM must be the larger of the two. The gap between two rows at a given
## x is pitch + (sag_lower - sag_upper) * (u² - 0.5), so a sag that GROWS
## downward only ever opens the edges out, while a shrinking sag closes them and
## can pull a pair under the trap limit far from the centre. The closest-pair
## check catches it either way; this is why the constant is ordered, not free.
const SAG_TOP := 170.0
const SAG_BOTTOM := 260.0

## Band to fill, in the parent's coordinate space. A peg whose dome carries it
## past BOTTOM_Y is dropped rather than clamped — clamping would flatten the row
## ends back into a straight line, and below the band is bucket geometry, which
## is deliberately absent from the wall test.
const TOP_Y := 200.0
const BOTTOM_Y := 900.0
const LEFT_X := 60.0
const RIGHT_X := 1540.0


func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("Arcs: no scene open.")
		return

	var parent := root.get_node_or_null(PARENT_PATH) as Node2D
	if parent == null:
		push_error("Arcs: no Node2D at '%s' under %s." % [PARENT_PATH, root.name])
		return

	if SAG_BOTTOM < SAG_TOP:
		push_error("Arcs: SAG_BOTTOM %.1f is below SAG_TOP %.1f - rows would close toward the edges." % [SAG_BOTTOM, SAG_TOP])
		return

	var ball_r := _scene_circle_radius(BALL_SCENE)
	var peg_r := _scene_circle_radius(PEG_SCENE)
	if ball_r <= 0.0 or peg_r <= 0.0:
		push_error("Arcs: could not read radii (ball %.1f, peg %.1f)." % [ball_r, peg_r])
		return

	var peg_limit := 2.0 * (ball_r + peg_r)
	var wall_limit := 2.0 * ball_r + peg_r

	var faces := _wall_faces(root)
	var kept: Array[Vector2] = []
	var skipped_walls := 0
	for local in _layout():
		if _too_close_to_wall(parent.to_global(local), faces, wall_limit):
			skipped_walls += 1
		else:
			kept.append(local)

	if kept.size() < 2:
		push_error("Arcs: only %d pegs survived the wall test - check the band constants." % kept.size())
		return

	var closest := _closest_pair(kept)
	var tightest: float = closest["distance"]
	if tightest <= peg_limit:
		var a: Vector2 = closest["a"]
		var b: Vector2 = closest["b"]
		push_error("Arcs: closest pair %.1f is at or below the trap limit %.1f, at (%.0f, %.0f) and (%.0f, %.0f). Nothing placed." % [tightest, peg_limit, a.x, a.y, b.x, b.y])
		return

	var packed := load(PEG_SCENE) as PackedScene
	if packed == null:
		push_error("Arcs: could not load %s." % PEG_SCENE)
		return

	var old := parent.get_node_or_null(FIELD_NAME)
	if old != null:
		parent.remove_child(old)
		old.free()

	var field := Node2D.new()
	field.name = FIELD_NAME
	parent.add_child(field)
	field.owner = root

	for local in kept:
		var peg := packed.instantiate() as Node2D
		peg.position = local
		field.add_child(peg)
		peg.owner = root

	print("Arcs - %s" % root.name)
	print("  spacing %.1f, pitch %.1f to %.1f, sag %.1f to %.1f" % [SPACING, TOP_PITCH, BOTTOM_PITCH, SAG_TOP, SAG_BOTTOM])
	print("  closest pair %.1f (trap limit %.1f, headroom %.1f)" % [tightest, peg_limit, tightest - peg_limit])
	print("  placed %d, skipped %d near walls" % [kept.size(), skipped_walls])
	print("  lettering is not avoided - delete clashes, then run the spacing check")
	print("  save the scene to keep them")


## Row baselines walk the band by the interpolated pitch; the dome is applied
## per peg. Returns positions in the parent's space, unfiltered.
## Row baselines are inset from the band by half a sag at each end, because the
## dome is centred: a row's middle sits sag/2 above its baseline and its ends
## sag/2 below. Without the inset the first row's centre climbs past TOP_Y and
## the last row's ends fall past BOTTOM_Y, and the band guard below drops them —
## which reads as thin corners and a thin top rather than as an error. With it,
## the band means what it says and sag can be raised without losing pegs.
func _layout() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var centre_x := (LEFT_X + RIGHT_X) * 0.5
	var half_width := (RIGHT_X - LEFT_X) * 0.5
	if half_width <= 0.0:
		return out

	var first_base := TOP_Y + SAG_TOP * 0.5
	var last_base := BOTTOM_Y - SAG_BOTTOM * 0.5
	if last_base < first_base:
		push_error("Arcs: sag %.1f/%.1f leaves no room in the band %.1f to %.1f." % [SAG_TOP, SAG_BOTTOM, TOP_Y, BOTTOM_Y])
		return out

	var row := 0
	var base_y := first_base
	while base_y <= last_base:
		var t := 0.0 if is_equal_approx(last_base, first_base) else clampf((base_y - first_base) / (last_base - first_base), 0.0, 1.0)
		var pitch := lerpf(TOP_PITCH, BOTTOM_PITCH, t)
		var sag := lerpf(SAG_TOP, SAG_BOTTOM, t)
		var x := LEFT_X + (0.0 if row % 2 == 0 else SPACING * 0.5)
		while x <= RIGHT_X:
			var u := (x - centre_x) / half_width
			var y := base_y + sag * (u * u - 0.5)
			if y >= TOP_Y and y <= BOTTOM_Y:
				out.append(Vector2(x, y))
			x += SPACING
		base_y += pitch
		row += 1
	return out


## Brute-force closest pair. Returns {distance, a, b}; distance is INF below two
## points. A few hundred pegs is a few tens of thousands of comparisons, which
## costs nothing here and removes any need to reason about which pair is worst.
func _closest_pair(points: Array[Vector2]) -> Dictionary:
	var best := INF
	var best_a := Vector2.ZERO
	var best_b := Vector2.ZERO
	for i in points.size():
		for j in range(i + 1, points.size()):
			var d := points[i].distance_to(points[j])
			if d < best:
				best = d
				best_a = points[i]
				best_b = points[j]
	return {"distance": best, "a": best_a, "b": best_b}


func _too_close_to_wall(point: Vector2, faces: Array[CollisionShape2D], limit: float) -> bool:
	for face in faces:
		var found: Variant = _nearest_point(face, point)
		if found == null:
			continue
		var nearest: Vector2 = found
		if point.distance_to(nearest) < limit:
			return true
	return false


## Board walls only: a PhysicsBody2D that is not a Peg and not inside a Bucket.
## Bucket mouths are Area2D and drop out of the PhysicsBody2D test on their own;
## dividers do not, hence the parent-chain check.
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


## Radii come from a fresh instantiate of the scene file rather than a walk of
## the edited tree: a tree walk returned 0 for a peg demonstrably carrying a
## CircleShape2D. Cost is that per-instance radius overrides are invisible here.
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
