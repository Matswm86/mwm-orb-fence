class_name OfLevels
extends RefCounted

## The 30 levels (GDD 6.3, 6.4) and the Uendelig rounds (GDD 6.5). Each
## level names its field ("14x16" in worlds 1-3, "21x24" in worlds 4-6, see
## OfBalance.GRIDS) and lists only its non-empty rows in "marks" (row index
## -> one string per row, one character per cell):
##   "." empty, "#" stone, "x" outside a shaped field (L, plus), "/" and
##   "\\" mirrors, "S" Snegl, "L" Lyn, "H" Skjold (hexagon) token on an
##   empty cell. Maps for levels 6-30 are my placement of the counts in
## table 6.3 (the GDD fixes only world 1's maps). lett / vanlig: balls (the
## total, Stor and Kvikk count inside it), stor, kvikk, speed px/s, target,
## sparks (0 = unlimited). Pictures of worlds 2-6 are PLACEHOLDERS: one
## crystal-tint ramp per world until graphic-designer delivers the 25 real
## pictures ("placeholder": true).

## Worlds (DESIGN 2c): name, crystal tint, sky ramp (void + 3 nebula stops).
const WORLDS: Array[Dictionary] = [
	{
		"name": "Månebanen",
		"tint": Color(0.498, 0.714, 1.000),
		"sky": [Color(0.020, 0.031, 0.086), Color(0.055, 0.239, 0.400)],
	},
	{
		"name": "Ringplaneten",
		"tint": Color(0.369, 0.847, 0.816),
		"sky": [Color(0.016, 0.063, 0.102), Color(0.114, 0.420, 0.420)],
	},
	{
		"name": "Stormkjempen",
		"tint": Color(0.498, 0.910, 0.690),
		"sky": [Color(0.024, 0.039, 0.078), Color(0.173, 0.373, 0.431)],
	},
	{
		"name": "Kometveien",
		"tint": Color(0.706, 0.651, 1.000),
		"sky": [Color(0.027, 0.024, 0.102), Color(0.227, 0.173, 0.525)],
	},
	{
		"name": "Isspeilet",
		"tint": Color(0.624, 0.902, 0.949),
		"sky": [Color(0.016, 0.047, 0.078), Color(0.118, 0.416, 0.502)],
	},
	{
		"name": "Galaksehjertet",
		"tint": Color(0.612, 0.549, 1.000),
		"sky": [Color(0.012, 0.008, 0.039), Color(0.231, 0.165, 0.478)],
	},
]

## World 1 is the only world with its own backdrop art so far
## (assets/textures/world1_*.png). Worlds 2-6 reuse it tinted toward their
## sky ramp: a PLACEHOLDER until the world art exists.
const WORLD_ART_DONE: Array[int] = [1]

const LEVELS: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Første strek",
		"field": "14x16",
		"marks": {},
		"lett": {"balls": 1, "stor": 0, "kvikk": 0, "speed": 200.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 2, "stor": 0, "kvikk": 0, "speed": 320.0, "target": 0.75, "sparks": 0},
		"cage": false,
		"picture": "res://assets/textures/pictures/w1_l1_rocket.png",
		"placeholder": false,
	},
	{
		"id": 2,
		"name": "Snu veggen",
		"field": "14x16",
		"marks": {},
		"lett": {"balls": 2, "stor": 0, "kvikk": 0, "speed": 200.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 3, "stor": 0, "kvikk": 0, "speed": 320.0, "target": 0.75, "sparks": 0},
		"cage": false,
		"picture": "res://assets/textures/pictures/w1_l2_satellite.png",
		"placeholder": false,
	},
	{
		"id": 3,
		"name": "Sneglen",
		"field": "14x16",
		"marks":
		{
			3: "...S..........",
			12: "..........S...",
		},
		"lett": {"balls": 2, "stor": 0, "kvikk": 0, "speed": 200.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 3, "stor": 0, "kvikk": 0, "speed": 320.0, "target": 0.75, "sparks": 0},
		"cage": false,
		"picture": "res://assets/textures/pictures/w1_l3_ringplanet.png",
		"placeholder": false,
	},
	{
		"id": 4,
		"name": "Steinene",
		"field": "14x16",
		"marks":
		{
			5: "...##....##...",
			10: "...##....##...",
		},
		"lett": {"balls": 2, "stor": 0, "kvikk": 0, "speed": 200.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 4, "stor": 0, "kvikk": 0, "speed": 320.0, "target": 0.75, "sparks": 0},
		"cage": false,
		"picture": "res://assets/textures/pictures/w1_l4_rover.png",
		"placeholder": false,
	},
	{
		"id": 5,
		"name": "Soloppgang",
		"field": "14x16",
		"marks": {},
		"lett": {"balls": 2, "stor": 0, "kvikk": 0, "speed": 200.0, "target": 0.60, "sparks": 0},
		"vanlig": {"balls": 4, "stor": 0, "kvikk": 0, "speed": 320.0, "target": 0.70, "sparks": 0},
		"cage": false,
		"picture": "res://assets/textures/pictures/w1_l5_sunrise.png",
		"placeholder": false,
	},
	{
		"id": 6,
		"name": "Buret",
		"field": "14x16",
		"marks":
		{
			3: "...#......#...",
			12: "...#......#...",
		},
		"lett": {"balls": 2, "stor": 0, "kvikk": 0, "speed": 210.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 5, "stor": 0, "kvikk": 0, "speed": 340.0, "target": 0.75, "sparks": 15},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w2.png",
		"placeholder": true,
	},
	{
		"id": 7,
		"name": "Tre i buret",
		"field": "14x16",
		"marks":
		{
			12: "...S..........",
		},
		"lett": {"balls": 2, "stor": 0, "kvikk": 0, "speed": 215.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 5, "stor": 0, "kvikk": 0, "speed": 350.0, "target": 0.75, "sparks": 15},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w2.png",
		"placeholder": true,
	},
	{
		"id": 8,
		"name": "Kjempen",
		"field": "14x16",
		"marks": {},
		"lett": {"balls": 3, "stor": 1, "kvikk": 0, "speed": 220.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 6, "stor": 1, "kvikk": 0, "speed": 360.0, "target": 0.75, "sparks": 18},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w2.png",
		"placeholder": true,
	},
	{
		"id": 9,
		"name": "Kjempene",
		"field": "14x16",
		"marks":
		{
			4: "...#......#...",
			8: "......##......",
			11: "...#......#...",
			13: "......S.......",
		},
		"lett": {"balls": 3, "stor": 2, "kvikk": 0, "speed": 225.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 6, "stor": 2, "kvikk": 0, "speed": 370.0, "target": 0.75, "sparks": 18},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w2.png",
		"placeholder": true,
	},
	{
		"id": 10,
		"name": "Ringraketten",
		"field": "14x16",
		"marks":
		{
			3: "..........S...",
		},
		"lett": {"balls": 3, "stor": 0, "kvikk": 0, "speed": 210.0, "target": 0.60, "sparks": 0},
		"vanlig": {"balls": 6, "stor": 0, "kvikk": 0, "speed": 340.0, "target": 0.70, "sparks": 0},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w2.png",
		"placeholder": true,
	},
	{
		"id": 11,
		"name": "Lynet",
		"field": "14x16",
		"marks":
		{
			3: "...L..........",
			12: "..........L...",
		},
		"lett": {"balls": 3, "stor": 0, "kvikk": 0, "speed": 220.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 7, "stor": 0, "kvikk": 0, "speed": 360.0, "target": 0.75, "sparks": 21},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w3.png",
		"placeholder": true,
	},
	{
		"id": 12,
		"name": "Lynrask",
		"field": "14x16",
		"marks":
		{
			3: ".......L......",
			7: "..##......##..",
			12: "......L.......",
		},
		"lett": {"balls": 3, "stor": 0, "kvikk": 0, "speed": 225.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 7, "stor": 0, "kvikk": 0, "speed": 370.0, "target": 0.75, "sparks": 21},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w3.png",
		"placeholder": true,
	},
	{
		"id": 13,
		"name": "Hjørnet",
		"field": "14x16",
		"marks":
		{
			0: "........xxxxxx",
			1: "........xxxxxx",
			2: "........xxxxxx",
			3: "........xxxxxx",
			4: "........xxxxxx",
			5: "........xxxxxx",
			12: "...S..........",
		},
		"lett": {"balls": 4, "stor": 0, "kvikk": 0, "speed": 230.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 8, "stor": 0, "kvikk": 0, "speed": 380.0, "target": 0.75, "sparks": 24},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w3.png",
		"placeholder": true,
	},
	{
		"id": 14,
		"name": "Lyn i hjørnet",
		"field": "14x16",
		"marks":
		{
			0: "........xxxxxx",
			1: "........xxxxxx",
			2: "........xxxxxx",
			3: "...L....xxxxxx",
			4: "........xxxxxx",
			5: "........xxxxxx",
			9: "..##......##..",
			13: "..........S...",
		},
		"lett": {"balls": 4, "stor": 1, "kvikk": 0, "speed": 235.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 8, "stor": 1, "kvikk": 0, "speed": 390.0, "target": 0.75, "sparks": 24},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w3.png",
		"placeholder": true,
	},
	{
		"id": 15,
		"name": "Stormøyet",
		"field": "14x16",
		"marks":
		{
			8: "..........L...",
		},
		"lett": {"balls": 4, "stor": 0, "kvikk": 0, "speed": 220.0, "target": 0.60, "sparks": 0},
		"vanlig": {"balls": 8, "stor": 0, "kvikk": 0, "speed": 360.0, "target": 0.70, "sparks": 0},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w3.png",
		"placeholder": true,
	},
	{
		"id": 16,
		"name": "Kvikke",
		"field": "21x24",
		"marks":
		{
			5: ".....S...............",
		},
		"lett": {"balls": 4, "stor": 0, "kvikk": 1, "speed": 230.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 9, "stor": 0, "kvikk": 1, "speed": 380.0, "target": 0.75, "sparks": 27},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w4.png",
		"placeholder": true,
	},
	{
		"id": 17,
		"name": "Kvikk og stor",
		"field": "21x24",
		"marks":
		{
			3: "..........S..........",
			6: ".....##.......##.....",
			7: ".....##.......##.....",
			16: ".....##.......##.....",
			17: ".....##.......##.....",
		},
		"lett": {"balls": 4, "stor": 1, "kvikk": 1, "speed": 235.0, "target": 0.65, "sparks": 0},
		"vanlig": {"balls": 9, "stor": 1, "kvikk": 2, "speed": 390.0, "target": 0.75, "sparks": 27},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w4.png",
		"placeholder": true,
	},
	{
		"id": 18,
		"name": "Korset",
		"field": "21x24",
		"marks":
		{
			0: "xxxxxx.........xxxxxx",
			1: "xxxxxx.........xxxxxx",
			2: "xxxxxx.........xxxxxx",
			3: "xxxxxx.........xxxxxx",
			4: "xxxxxx.........xxxxxx",
			5: "xxxxxx.........xxxxxx",
			11: "...L.................",
			18: "xxxxxx.........xxxxxx",
			19: "xxxxxx.........xxxxxx",
			20: "xxxxxx.........xxxxxx",
			21: "xxxxxx.........xxxxxx",
			22: "xxxxxx.........xxxxxx",
			23: "xxxxxx.........xxxxxx",
		},
		"lett": {"balls": 5, "stor": 0, "kvikk": 0, "speed": 240.0, "target": 0.65, "sparks": 0},
		"vanlig":
		{"balls": 10, "stor": 0, "kvikk": 0, "speed": 400.0, "target": 0.75, "sparks": 30},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w4.png",
		"placeholder": true,
	},
	{
		"id": 19,
		"name": "Beltet",
		"field": "21x24",
		"marks":
		{
			0: "xxxxxx.........xxxxxx",
			1: "xxxxxx.........xxxxxx",
			2: "xxxxxx....L....xxxxxx",
			3: "xxxxxx.........xxxxxx",
			4: "xxxxxx.........xxxxxx",
			5: "xxxxxx.........xxxxxx",
			8: ".......##...##.......",
			9: ".......##...##.......",
			14: ".......##...##.......",
			15: ".......##...##.......",
			18: "xxxxxx.........xxxxxx",
			19: "xxxxxx.........xxxxxx",
			20: "xxxxxx.........xxxxxx",
			21: "xxxxxx....S....xxxxxx",
			22: "xxxxxx.........xxxxxx",
			23: "xxxxxx.........xxxxxx",
		},
		"lett": {"balls": 5, "stor": 0, "kvikk": 1, "speed": 245.0, "target": 0.65, "sparks": 0},
		"vanlig":
		{"balls": 10, "stor": 0, "kvikk": 2, "speed": 410.0, "target": 0.75, "sparks": 30},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w4.png",
		"placeholder": true,
	},
	{
		"id": 20,
		"name": "Kometen",
		"field": "21x24",
		"marks":
		{
			18: "...............S.....",
		},
		"lett": {"balls": 5, "stor": 0, "kvikk": 0, "speed": 230.0, "target": 0.60, "sparks": 0},
		"vanlig": {"balls": 10, "stor": 0, "kvikk": 0, "speed": 380.0, "target": 0.70, "sparks": 0},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w4.png",
		"placeholder": true,
	},
	{
		"id": 21,
		"name": "Speilet",
		"field": "21x24",
		"marks":
		{
			6: "...../.........\\.....",
			11: "...S.................",
			17: ".....\\........./.....",
		},
		"lett": {"balls": 5, "stor": 0, "kvikk": 0, "speed": 240.0, "target": 0.65, "sparks": 0},
		"vanlig":
		{"balls": 11, "stor": 0, "kvikk": 0, "speed": 400.0, "target": 0.75, "sparks": 33},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w5.png",
		"placeholder": true,
	},
	{
		"id": 22,
		"name": "Speilsal",
		"field": "21x24",
		"marks":
		{
			4: "........../..........",
			6: "...../.........\\.....",
			8: "..........L..........",
			11: "...\\.................",
			12: "................./...",
			17: ".....\\........./.....",
			19: "..........\\..........",
		},
		"lett": {"balls": 5, "stor": 0, "kvikk": 0, "speed": 245.0, "target": 0.65, "sparks": 0},
		"vanlig":
		{"balls": 11, "stor": 0, "kvikk": 0, "speed": 410.0, "target": 0.75, "sparks": 33},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w5.png",
		"placeholder": true,
	},
	{
		"id": 23,
		"name": "Isflakene",
		"field": "21x24",
		"marks":
		{
			3: "....###.......###....",
			4: "....###.......###....",
			5: "....###.......###....",
			8: "..........S..........",
			10: "....###.......###....",
			11: "....###.......###....",
			12: "....###.......###....",
			15: "..........L..........",
			18: "....###.......###....",
			19: "....###.......###....",
			20: "....###.......###....",
		},
		"lett": {"balls": 6, "stor": 0, "kvikk": 0, "speed": 250.0, "target": 0.65, "sparks": 0},
		"vanlig":
		{"balls": 12, "stor": 0, "kvikk": 0, "speed": 420.0, "target": 0.75, "sparks": 36},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w5.png",
		"placeholder": true,
	},
	{
		"id": 24,
		"name": "Isspeil",
		"field": "21x24",
		"marks":
		{
			3: "....###.......###....",
			4: "....###.../...###....",
			5: "....###.......###....",
			8: "..\\.......L..........",
			10: "....###.......###....",
			11: "....###.......###....",
			12: "....###.......###....",
			15: "..........S......./..",
			18: "....###.......###....",
			19: "....###...\\...###....",
			20: "....###.......###....",
		},
		"lett": {"balls": 6, "stor": 1, "kvikk": 1, "speed": 255.0, "target": 0.65, "sparks": 0},
		"vanlig":
		{"balls": 12, "stor": 1, "kvikk": 2, "speed": 430.0, "target": 0.75, "sparks": 36},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w5.png",
		"placeholder": true,
	},
	{
		"id": 25,
		"name": "Ismånen",
		"field": "21x24",
		"marks":
		{
			4: "....S................",
			19: "................S....",
		},
		"lett": {"balls": 6, "stor": 0, "kvikk": 0, "speed": 240.0, "target": 0.60, "sparks": 0},
		"vanlig": {"balls": 12, "stor": 0, "kvikk": 0, "speed": 400.0, "target": 0.70, "sparks": 0},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w5.png",
		"placeholder": true,
	},
	{
		"id": 26,
		"name": "Skjoldet",
		"field": "21x24",
		"marks":
		{
			4: "....H................",
			19: "................H....",
		},
		"lett": {"balls": 6, "stor": 0, "kvikk": 0, "speed": 250.0, "target": 0.65, "sparks": 0},
		"vanlig":
		{"balls": 13, "stor": 0, "kvikk": 0, "speed": 420.0, "target": 0.75, "sparks": 39},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w6.png",
		"placeholder": true,
	},
	{
		"id": 27,
		"name": "Skjold og lyn",
		"field": "21x24",
		"marks":
		{
			3: "..........H..........",
			6: ".....##.......##.....",
			7: ".....##.......##.....",
			16: ".....##.......##.....",
			17: ".....##.......##.....",
			20: "..........L..........",
		},
		"lett": {"balls": 6, "stor": 0, "kvikk": 1, "speed": 255.0, "target": 0.65, "sparks": 0},
		"vanlig":
		{"balls": 13, "stor": 0, "kvikk": 2, "speed": 430.0, "target": 0.75, "sparks": 39},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w6.png",
		"placeholder": true,
	},
	{
		"id": 28,
		"name": "Labyrinten",
		"field": "21x24",
		"marks":
		{
			0: "xxxxxx.........xxxxxx",
			1: "xxxxxx.........xxxxxx",
			2: "xxxxxx.........xxxxxx",
			3: "xxxxxx....H....xxxxxx",
			4: "xxxxxx.........xxxxxx",
			5: "xxxxxx.........xxxxxx",
			8: "......../...\\........",
			15: "........\\.../........",
			18: "xxxxxx.........xxxxxx",
			19: "xxxxxx.........xxxxxx",
			20: "xxxxxx....S....xxxxxx",
			21: "xxxxxx.........xxxxxx",
			22: "xxxxxx.........xxxxxx",
			23: "xxxxxx.........xxxxxx",
		},
		"lett": {"balls": 7, "stor": 1, "kvikk": 0, "speed": 260.0, "target": 0.65, "sparks": 0},
		"vanlig":
		{"balls": 14, "stor": 1, "kvikk": 1, "speed": 440.0, "target": 0.75, "sparks": 42},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w6.png",
		"placeholder": true,
	},
	{
		"id": 29,
		"name": "Alt på en gang",
		"field": "21x24",
		"marks":
		{
			0: "............xxxxxxxxx",
			1: "............xxxxxxxxx",
			2: "............xxxxxxxxx",
			3: "...###...L..xxxxxxxxx",
			4: "...###......xxxxxxxxx",
			5: "...###......xxxxxxxxx",
			6: "............xxxxxxxxx",
			7: "............xxxxxxxxx",
			8: "............xxxxxxxxx",
			10: "........../..........",
			12: ".........S...........",
			13: "..............###....",
			14: "..............###....",
			15: "..............###....",
			18: ".....###.............",
			19: ".....###.............",
			20: ".....###.........\\...",
			21: "............H........",
		},
		"lett": {"balls": 7, "stor": 1, "kvikk": 1, "speed": 265.0, "target": 0.65, "sparks": 0},
		"vanlig":
		{"balls": 14, "stor": 2, "kvikk": 2, "speed": 450.0, "target": 0.75, "sparks": 42},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w6.png",
		"placeholder": true,
	},
	{
		"id": 30,
		"name": "Galaksen",
		"field": "21x24",
		"marks":
		{
			4: "....H................",
			19: "................H....",
		},
		"lett": {"balls": 7, "stor": 0, "kvikk": 0, "speed": 250.0, "target": 0.60, "sparks": 0},
		"vanlig": {"balls": 14, "stor": 0, "kvikk": 0, "speed": 420.0, "target": 0.70, "sparks": 0},
		"cage": true,
		"picture": "res://assets/textures/pictures/placeholder_w6.png",
		"placeholder": true,
	},
]


static func count() -> int:
	return LEVELS.size()


static func has_level(id: int) -> bool:
	return id >= 1 and id <= LEVELS.size()


static func get_level(id: int) -> Dictionary:
	return LEVELS[clampi(id, 1, LEVELS.size()) - 1]


static func world_of(id: int) -> int:
	return (clampi(id, 1, LEVELS.size()) - 1) / OfBalance.LEVELS_PER_WORLD + 1


static func world(w: int) -> Dictionary:
	return WORLDS[clampi(w, 1, WORLDS.size()) - 1]


static func field_of(id: int) -> String:
	return String(get_level(id)["field"])


static func rows(id: int) -> Array[String]:
	var lv: Dictionary = get_level(id)
	return expand_rows(String(lv["field"]), lv["marks"])


## Full row strings of a field from its marks (missing rows are open).
static func expand_rows(field: String, marks: Dictionary) -> Array[String]:
	var g: Dictionary = OfBalance.grid(field)
	var open_row: String = ".".repeat(int(g["cols"]))
	var out: Array[String] = []
	for r: int in int(g["rows"]):
		out.append(String(marks.get(r, open_row)))
	return out


static func params(id: int, easy: bool) -> Dictionary:
	return get_level(id)["lett" if easy else "vanlig"]


static func picture_path(id: int) -> String:
	return String(get_level(id)["picture"])


static func picture(id: int) -> Texture2D:
	return load(picture_path(id)) as Texture2D


## Everything OfSim needs for one level in one setting.
static func config(id: int, easy: bool) -> Dictionary:
	var lv: Dictionary = get_level(id)
	var p: Dictionary = params(id, easy)
	return {
		"level": id,
		"world": world_of(id),
		"field": String(lv["field"]),
		"rows": rows(id),
		"balls": int(p["balls"]),
		"stor": int(p["stor"]),
		"kvikk": int(p["kvikk"]),
		"speed": float(p["speed"]),
		"target": float(p["target"]),
		"sparks": int(p["sparks"]),
		"cage": bool(lv["cage"]),
		"random_snegl": 0,
		"picture": String(lv["picture"]),
	}


## Uendelig round k (GDD 6.5): open field, plain balls, k (Lett) or k + 1
## (Vanlig) balls up to the cap, a speed step per round up to the cap,
## 14 x 16 until 9 balls then 21 x 24, one random Snegl from round 3, cage on,
## sparks 3 x balls (Vanlig) every round, the breather picture of world
## ((k - 1) mod 6) + 1.
static func endless_config(k: int, easy: bool) -> Dictionary:
	var balls: int = OfBalance.endless_balls(easy, k)
	var field: String = "21x24" if balls >= OfBalance.ENDLESS_FIELD_SWITCH_BALLS else "14x16"
	var w: int = (k - 1) % OfBalance.WORLDS + 1
	var breather: int = w * OfBalance.LEVELS_PER_WORLD
	return {
		"level": 0,
		"round": k,
		"world": w,
		"field": field,
		"rows": expand_rows(field, {}),
		"balls": balls,
		"stor": 0,
		"kvikk": 0,
		"speed": OfBalance.endless_speed(easy, k),
		"target": OfBalance.TARGET_LETT if easy else OfBalance.TARGET_VANLIG,
		"sparks": 0 if easy else OfBalance.default_budget(balls),
		"cage": true,
		"random_snegl": 1 if k >= OfBalance.ENDLESS_SNEGL_FROM_ROUND else 0,
		"picture": picture_path(breather),
	}
