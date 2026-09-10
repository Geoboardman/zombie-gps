class_name MapFeature
extends RefCounted

# One real-world feature (a road segment, a lake outline, a building
# footprint...) parsed out of OSM data, before it's turned into a mesh.
# points are stored as Vector3(lat, 0, lon) by the parser -- MapBuilder
# converts them to real local-space meters using the current GPS origin
# at build time.

enum Kind {
	ROAD,
	WATER,
	BUILDING,
	LANDUSE,
	UNKNOWN,
}

var kind: Kind = Kind.UNKNOWN
var points: Array[Vector3] = []
var is_polygon := false # true = filled area (water/building/landuse), false = line (road)
var tags: Dictionary = {}
