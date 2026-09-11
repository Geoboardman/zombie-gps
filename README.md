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
5. A visible Field Kit drops where the zombie died; proximity reveals an
   **Open Field Kit** button, but nothing happens until the player taps it.
6. The player chooses Hollow Points, Quick Hands, or Field Dressing.
7. A nearby supply cache is revealed; the player must tap **Search Cache** to
   receive 35 gold and healing.
8. A survivor distress signal appears farther ahead and requires confirmation.
9. Recruiting that survivor reveals the boss altar.
10. Defeating the boss offers **Push Deeper** or **Extract Run**.

Proximity never spends currency, consumes rewards, recruits survivors, or
starts bosses. It only reveals a large contextual action button. Combat remains
automatic so the outdoor experience does not demand continuous screen focus.

Pushing deeper generates another supply → survivor → boss district with longer
distances, more heat, and a boss that scales each district. Extracting displays
a run summary for distance, kills, recruits, bosses, district, and recovered
gold. Meta-progression persistence is not implemented yet.

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
- `scripts/interactable_map_node.gd` — tap-confirm contract for world objects
- `scripts/interaction_controller.gd` — shared contextual action button
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
- Extracting banks carried gold, best district, and successful extraction count
  in `user://run_profile.json`; dying loses only the current run's carried gold.
- The public Overpass API is suitable for development, not production traffic.
- Generated map geometry is rebuilt as one area rather than streamed in chunks.
- Bosses intentionally resist Knockback Pulse, although ordinary damage, aura,
  and fighter-survivor attacks work through the shared `Enemy` base class.

## District risk and extraction

Clearing a boss creates the run's main decision. Extracting records the carried
gold and career best safely. Pushing deeper heals 25% max health, increases all
future gold rewards by 25%, and reveals the next district modifier, but carried
gold is lost if the player dies before reaching another extraction checkpoint.

District pressure rotates between Runner Surge (runner-heavy waves), Brute
Territory (brute-heavy waves), and The Horde (larger waves). This is deliberately
a small first modifier set for testing whether repeated districts feel different
before adding bespoke hazards or map events.

## Active abilities and builds

The current prototype ability kit is designed for one-tap, auto-targeted combat:

- Stasis Pulse freezes nearby normal zombies and slows bosses without pushing
  enemies outside weapon range.
- Field Dressing restores 35% maximum health over eight seconds.
- Frag Grenade targets the densest nearby enemy cluster, telegraphs its landing
  area, and deals visible area damage.

Every searched supply cache now pauses for a three-upgrade choice. Build-shaping
options include Double Tap, Piercing Rounds, Executioner, Burning Presence,
Adrenal Response, and Cluster Grenade alongside the original stat upgrades.
Acquired upgrades appear in the compact BUILD summary on the HUD.
