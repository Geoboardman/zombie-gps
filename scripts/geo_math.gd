class_name GeoMath
extends RefCounted

# Converts between real-world lat/lon coordinates and local flat XZ meters
# around a chosen origin point. Uses an equirectangular approximation --
# accurate enough for city-block/neighborhood scale (walking/jogging range).
# Breaks down over very large distances (hundreds of km), which we don't need.
#
# All local variables here use explicit type annotations (":float" instead
# of ":=") rather than relying on inference. GDScript's static analyzer
# can sometimes fail to infer a concrete type through chains of global
# math functions (floor, sin, cos, atan2, sqrt...) combined with
# constants, and flags it as an "inferred as Variant" warning -- which is
# a hard parse error if your project has "treat warnings as errors" on.
# Explicit types sidestep that entirely.

const EARTH_RADIUS_METERS: float = 6378137.0 # WGS84 equatorial radius

# World lat/lon -> local meters (X = east/west, Z = north/south).
# North is -Z so Godot's default forward direction reads intuitively;
# flip the sign here if you'd rather have north be +Z.
static func lat_lon_to_local(lat: float, lon: float, origin_lat: float, origin_lon: float) -> Vector3:
	var origin_lat_rad: float = deg_to_rad(origin_lat)
	var d_lat_rad: float = deg_to_rad(lat - origin_lat)
	var d_lon_rad: float = deg_to_rad(lon - origin_lon)

	var x: float = d_lon_rad * EARTH_RADIUS_METERS * cos(origin_lat_rad)
	var z: float = -d_lat_rad * EARTH_RADIUS_METERS

	return Vector3(x, 0.0, z)

# Local meters -> world lat/lon, given the same origin used to create them.
# Returns a Dictionary {"lat": ..., "lon": ...} rather than a Vector2 --
# Vector2's components are 32-bit floats in Godot, which don't have enough
# precision to represent meter-scale movement in lat/lon degrees (a Vector2
# here would silently round away anything under roughly a meter of change).
static func local_to_lat_lon(local: Vector3, origin_lat: float, origin_lon: float) -> Dictionary:
	var origin_lat_rad: float = deg_to_rad(origin_lat)

	var d_lon_rad: float = local.x / (EARTH_RADIUS_METERS * cos(origin_lat_rad))
	var d_lat_rad: float = -local.z / EARTH_RADIUS_METERS

	var lat: float = origin_lat + rad_to_deg(d_lat_rad)
	var lon: float = origin_lon + rad_to_deg(d_lon_rad)

	return {"lat": lat, "lon": lon}

# Great-circle distance in meters between two lat/lon points (Haversine).
static func haversine_distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var lat1_rad: float = deg_to_rad(lat1)
	var lat2_rad: float = deg_to_rad(lat2)
	var d_lat: float = deg_to_rad(lat2 - lat1)
	var d_lon: float = deg_to_rad(lon2 - lon1)

	var a: float = sin(d_lat / 2.0) * sin(d_lat / 2.0) \
		+ cos(lat1_rad) * cos(lat2_rad) * sin(d_lon / 2.0) * sin(d_lon / 2.0)
	var c: float = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))

	return EARTH_RADIUS_METERS * c

# Compass bearing in degrees (0 = north, 90 = east) from point 1 to point 2.
static func bearing_degrees(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var lat1_rad: float = deg_to_rad(lat1)
	var lat2_rad: float = deg_to_rad(lat2)
	var d_lon: float = deg_to_rad(lon2 - lon1)

	var y: float = sin(d_lon) * cos(lat2_rad)
	var x: float = cos(lat1_rad) * sin(lat2_rad) - sin(lat1_rad) * cos(lat2_rad) * cos(d_lon)

	var bearing: float = rad_to_deg(atan2(y, x))
	return fmod(bearing + 360.0, 360.0)
