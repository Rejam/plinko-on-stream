@tool
extends EditorScript

## Clears the per-peg colour override on every Peg in the open scene.
## File > Run with a board open, then save the scene.
##
## Exists because the inspector's revert arrow is per-node: a multi-selection
## can be given a value but cannot be reverted, so bulk-clearing overrides has
## no path through the UI.
##
## The target colour is read off peg.gd's declared default rather than
## hardcoded here, so this restores whatever the default currently is instead
## of a copy that goes stale the moment the default changes.

const PEG_SCRIPT := "uid://bjkdgdavgadce"


func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("Colour reset: no scene open.")
		return

	var default_colour := _default_colour()
	var pegs: Array[Node] = []
	_collect(root, pegs)

	if pegs.is_empty():
		push_warning("Colour reset: no Peg nodes under %s." % root.name)
		return

	var changed := 0
	for peg in pegs:
		var current: Color = peg.colour
		if current != default_colour:
			peg.colour = default_colour
			changed += 1

	push_warning("Colour reset - %s: %d pegs, %d cleared, default %s, first now %s" % [
		root.name,
		pegs.size(),
		changed,
		default_colour,
		(pegs[0] as Node).get("colour"),
	])


func _default_colour() -> Color:
	var script := load(PEG_SCRIPT) as GDScript
	if script == null:
		push_error("Colour reset: could not load %s - falling back to white." % PEG_SCRIPT)
		return Color.WHITE
	for property in script.get_script_property_list():
		if property.name == "colour":
			return script.get_property_default_value("colour")
	push_error("Colour reset: peg.gd has no 'colour' export - falling back to white.")
	return Color.WHITE


func _collect(node: Node, out: Array[Node]) -> void:
	if node is Peg:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)
