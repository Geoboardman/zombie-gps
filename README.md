# ZombieGPS Demo Scene — GDScript Setup Guide

Same system as the C# version, ported to GDScript. Behavior and file
responsibilities are identical — just different syntax and node wiring
conventions (`@export` instead of `[Export]`, snake_case names, signals
instead of C# events).

## 1. Copy the scripts in

Drop the entire `Scripts/` folder into your Godot project (e.g.
`res://Scripts/`). No compile step needed — GDScript is interpreted, so
files just need to be present and error-free.

## 2. Set up the Input Map

**Project > Project Settings > Input Map**, add these four actions (used
for mock WASD movement in the editor):

| Action name    | Suggested key |
|-----------------|--------------|
| `move_left`     | A            |
| `move_right`    | D            |
| `move_forward`  | W            |
| `move_back`     | S            |

## 3. Build the scene hierarchy

Create a new 3D scene with this node structure:

```
Main (Node3D)
├── GPSManager (Node)                      [script: gps_manager.gd]
├── OverpassClient (HTTPRequest)           [script: overpass_client.gd]
├── MapBuilder (Node3D)                    [script: map_builder.gd]
├── MapManager (Node3D)                    [script: map_manager.gd]
├── Player (CharacterBody3D)               [script: player_controller.gd]
│   ├── CollisionShape3D                   (capsule shape, placeholder)
│   └── MeshInstance3D                     (capsule mesh, placeholder — swap for your survivor model later)
├── CameraRig (Node3D)                     [script: camera_rig.gd]
│   └── Camera3D
└── DirectionalLight3D                     (so Unshaded materials still read fine, and you have a light for later non-map objects)
```

### Wiring up exported fields (do this in the Inspector, after adding scripts):

- **MapBuilder**
  - `Gps Manager Path` → `../GPSManager`
  - `Style` → create a new `MapStyle` resource here (right-click the field →
	New Resource → MapStyle), then tweak the exported colors right in the
	Inspector. This is your main styling control — make more `.tres`
	presets later for different looks (e.g. `res://Styles/zombie.tres`).

- **MapManager**
  - `Gps Manager Path` → `../GPSManager`
  - `Overpass Client Path` → `../OverpassClient`
  - `Map Builder Path` → `../MapBuilder`

- **PlayerController**
  - `Gps Manager Path` → `../GPSManager`

- **CameraRig**
  - `Target Path` → `../Player`

- **GPSManager**
  - `Mock Start Lat` / `Mock Start Lon` → set to wherever you want to test
	(a real address near you works well, since real OSM data will
	actually render there)

## 4. Press Play

You should see:
1. The Output panel print `[MapManager] Fetching map data around (...)`
2. A moment later, `[OverpassClient] Parsed N features`
3. Flat colored roads/water/buildings/landuse appear around your player
4. WASD moves the player (and re-fetches new map data once you wander far
   enough from the last fetch point)

If nothing renders: check the Output panel for `[OverpassClient] Fetch
failed` — most likely cause is no internet access from the editor, or the
public Overpass API being temporarily overloaded (it's a shared community
service; retry after a minute if so).

## Differences from the C# version, if you're comparing

- `class_name X` at the top of each file is GDScript's equivalent of the
  C# class declaration — it also makes the type available globally without
  imports, same as before.
- `NodePath` exports work the same way — set them in the Inspector after
  wiring up the scene, exactly as described above.
- `GeoMath.local_to_lat_lon()` returns a `Vector2(lat, lon)` instead of a
  C# tuple, since GDScript doesn't have tuples — just read `.x` as lat and
  `.y` as lon wherever you see it used.
- Signals (`location_updated`, `features_loaded`, `fetch_failed`) replace
  C# events/delegates — functionally identical, just connected with
  `signal_name.connect(callable)` instead of `+=`.

## What's intentionally NOT here yet

Same as the C# version:

- **Real device GPS** — `GPSManager.use_mock_location` is your switch.
  Real GPS needs a native Android/iOS plugin calling
  `GPSManager.report_location(lat, lon)` instead of mock WASD movement.
- **Your survivor model** — the player is a placeholder capsule. Swap the
  `MeshInstance3D` child for your imported character model and animations
  whenever you're ready.
- **Zombies** — this demo is purely the map + player movement loop.
- **Tile caching / offline support** — every fetch hits Overpass live.
- **Production-scale Overpass usage** — the public instance has rate
  limits; look at self-hosting before shipping.
