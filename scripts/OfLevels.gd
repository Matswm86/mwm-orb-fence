class_name OfLevels
extends RefCounted

## World 1 "Månebanen" levels 1-5, exactly as GDD 6.4 / 6.3. Rows are 16
## strings of 14 cells: "." empty, "#" stone, "S" Snegl token on an empty
## cell. sparks 0 = unlimited (world 1 is unlimited in both settings).

const OPEN_ROW := ".............."

const LEVELS: Array[Dictionary] = [
	{
		"id": 1,
		"marks": {},
		"lett": {"balls": 1, "speed": 200.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 2, "speed": 320.0, "target": 0.75, "sparks": 0},
		"picture": "res://assets/textures/pictures/w1_l1_rocket.png",
	},
	{
		"id": 2,
		"marks": {},
		"lett": {"balls": 2, "speed": 200.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 3, "speed": 320.0, "target": 0.75, "sparks": 0},
		"picture": "res://assets/textures/pictures/w1_l2_satellite.png",
	},
	{
		"id": 3,
		"marks": {3: "...S..........", 12: "..........S..."},
		"lett": {"balls": 2, "speed": 200.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 3, "speed": 320.0, "target": 0.75, "sparks": 0},
		"picture": "res://assets/textures/pictures/w1_l3_ringplanet.png",
	},
	{
		"id": 4,
		"marks": {5: "...##....##...", 10: "...##....##..."},
		"lett": {"balls": 2, "speed": 200.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 3, "speed": 320.0, "target": 0.75, "sparks": 0},
		"picture": "res://assets/textures/pictures/w1_l4_rover.png",
	},
	{
		"id": 5,
		"marks": {},
		"lett": {"balls": 2, "speed": 200.0, "target": 0.60, "sparks": 0},
		"vanlig": {"balls": 2, "speed": 320.0, "target": 0.70, "sparks": 0},
		"picture": "res://assets/textures/pictures/w1_l5_sunrise.png",
	},
]


static func count() -> int:
	return LEVELS.size()


static func has_level(id: int) -> bool:
	return id >= 1 and id <= LEVELS.size()


static func get_level(id: int) -> Dictionary:
	return LEVELS[clampi(id, 1, LEVELS.size()) - 1]


static func rows(id: int) -> Array[String]:
	var lv: Dictionary = get_level(id)
	var marks: Dictionary = lv["marks"]
	var out: Array[String] = []
	for r: int in OfBalance.ROWS:
		out.append(String(marks.get(r, OPEN_ROW)))
	return out


static func params(id: int, easy: bool) -> Dictionary:
	return get_level(id)["lett" if easy else "vanlig"]


static func picture(id: int) -> Texture2D:
	return load(String(get_level(id)["picture"])) as Texture2D
