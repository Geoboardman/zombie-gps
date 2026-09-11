# ZombieGPS

ZombieGPS is a portrait-oriented GPS walking roguelite prototype built with
Godot 4.7. The player explores a lightweight 3D rendering of real OpenStreetMap
data, automatically fights zombies, assembles a survivor party, builds power,
and chooses when to challenge an outbreak boss.

## Current opening loop

Every run now begins with an authored chain rather than a random pile of
markers:

1. The local map loads from Overpass (or falls back gracefully if it fails).
2. An outbreak is detected six meters ahead.
3. Closing the distance triggers the player's automatic attack.
4. The first zombie dies in one hit and awards 15 gold.
5. The player chooses Hollow Points, Quick Hands, or Field Dressing.
6. A nearby supply cache is revealed and awards 35 gold plus healing.
7. A survivor distress signal appears farther ahead.
8. Recruiting that survivor reveals the boss altar.
9. Entering the altar radius reveals a touch-friendly **Summon Boss** button.
10. Defeating the boss presents the existing Bank-or-Continue decision.

Ambient waves remain gated until the first upgrade is selected. Their strength
is driven by run heat earned through movement and meaningful actions, rather
than increasing simply because the player stopped to rest.

## Desktop controls

| Action | Input |
| --- | --- |
| Mock GPS movement | WASD |
| Faster mock movement | Hold Shift |
| Knockback Pulse | Q or touch button |
| Second Wind | E or touch button |
| Overcharge | R or touch button |
| Summon boss | Enter/Space or on-screen button |
| Zoom | Mouse wheel |
| Pause safely | REST button |

The mock GPS starts near Redmond, Washington. Edit `mock_start_lat` and
`mock_start_lon` on `GPSManager` in `scenes/main.tscn` to test another area.

## Project structure

- `scripts/gps_manager.gd` — mock/real GPS integration boundary
- `scripts/geo_math.gd` — latitude/longitude and local-meter conversions
- `scripts/overpass_client.gd` — OSM request, parsing, and disk cache
- `scripts/map_manager.gd` — serialized map refresh coordination
- `scripts/map_builder.gd` — generated road and polygon meshes
- `scripts/run_director.gd` — guided opening, objectives, heat, and progression
- `scripts/player_controller.gd` — health, combat, abilities, and player stats
- `scripts/zombie_spawner.gd` — gated, heat-scaled ambient waves
- `scripts/zombie.gd`, `scripts/boss.gd` — enemy behavior
- `scripts/upgrades.gd`, `scripts/abilities.gd` — upgrade/effect definitions
- `scenes/main.tscn` — complete playable prototype

## Running the prototype

1. Open the folder containing `project.godot` in Godot 4.7.
2. Run the project.
3. Wait for the map scan to complete.
4. Follow the objective panel using WASD.

The public Overpass endpoint is shared and rate-limited. If it is unavailable,
the guided gameplay loop still starts over the plain ground area.

## Mobile and GPS status

The interface is configured around a 540×960 portrait viewport, but real device
GPS is not connected yet. A native Android/iOS location source should call:

```gdscript
gps_manager.report_location(latitude, longitude)
```

Before outdoor testing, add accuracy, timestamp, impossible-speed, permission,
and stale-fix handling. Do not use unfiltered device fixes to drive combat or
proximity rewards.

## Art integration path

Keep each `CharacterBody3D` scene root and collision shape stable. Replace the
placeholder mesh with a `VisualRoot` containing the imported glTF model,
`AnimationPlayer`/`AnimationTree`, and a `BoneAttachment3D` weapon socket. This
keeps gameplay independent from any particular asset hierarchy.

Recommended first art pass:

- One survivor model
- One normal zombie model
- Idle, walk, fire/attack, hit, and death animations
- One pistol or rifle
- Muzzle flash and hit feedback

Leave runners, brutes, buildings, and most props as primitives until this one
character pipeline is working on a phone.

## Known prototype limitations

- Guided objectives are placed on a consistent local bearing, not yet snapped
  to safe pedestrian paths.
- Real GPS and sensor heading are not implemented.
- Continuing after a boss does not generate a second guided district yet.
- The public Overpass API is suitable for development, not production traffic.
- Generated map geometry is rebuilt as one area rather than streamed in chunks.
- Bosses intentionally resist Knockback Pulse, although ordinary damage, aura,
  and fighter-survivor attacks work through the shared `Enemy` base class.
