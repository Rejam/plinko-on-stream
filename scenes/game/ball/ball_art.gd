class_name BallArt

## One source of truth for a viewer's ball: a generated texture used both by the
## ball in play and by every list that shows their name. Generated rather than
## drawn so it can be handed to ItemList.add_item as an icon — a _draw cannot.
##
## Appearance is derived from user_id, so the same viewer gets the same ball
## every round and every session with nothing stored. Textures are cached per
## user_id; standings only ever grow, so the cache stays small.

const SIZE := 64
const PATTERN_COUNT := 4

enum Pattern { SOLID, HALVED, RING, QUARTERED }

static var _cache: Dictionary[String, ImageTexture] = {}

static func texture_for(user_id: String) -> ImageTexture:
	if _cache.has(user_id):
		return _cache[user_id]
	var texture := _build(user_id)
	_cache[user_id] = texture
	return texture

## Saturation and value are pinned so no hash lands on something that vanishes
## against a board background.
static func colours_for(user_id: String) -> Array[Color]:
	var h := absi(user_id.hash())
	var hue := float(h % 360) / 360.0
	var accent_hue := fposmod(hue + 0.5, 1.0)
	return [Color.from_hsv(hue, 0.68, 0.92), Color.from_hsv(accent_hue, 0.45, 0.98)]

static func pattern_for(user_id: String) -> Pattern:
	return ((absi(user_id.hash()) / 360) % PATTERN_COUNT) as Pattern

static func _build(user_id: String) -> ImageTexture:
	var pair := colours_for(user_id)
	var base: Color = pair[0]
	var accent: Color = pair[1]
	var pattern := pattern_for(user_id)
	var outline := Color(0.05, 0.05, 0.07)

	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var centre := float(SIZE) * 0.5 - 0.5
	var outer := float(SIZE) * 0.5
	var inner := outer * 0.86

	for y in SIZE:
		for x in SIZE:
			var dx := float(x) - centre
			var dy := float(y) - centre
			var dist := sqrt(dx * dx + dy * dy)
			if dist > outer:
				continue
			if dist > inner:
				image.set_pixel(x, y, outline)
				continue
			image.set_pixel(x, y, _body_colour(pattern, dx, dy, dist, inner, base, accent))

	return ImageTexture.create_from_image(image)

static func _body_colour(pattern: Pattern, dx: float, dy: float, dist: float,
		inner: float, base: Color, accent: Color) -> Color:
	match pattern:
		Pattern.HALVED:
			return accent if dy < 0.0 else base
		Pattern.RING:
			return accent if dist < inner * 0.55 else base
		Pattern.QUARTERED:
			return accent if (dx < 0.0) == (dy < 0.0) else base
		_:
			return base
