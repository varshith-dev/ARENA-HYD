# Visual fidelity â€” 7 November 2026

This is a playable reconstruction in progress, not a surveyed digital twin. The current map contains 13,635 prepared building features. Most still have inferred heights and generic local facades. Cyber Towers and the metro remain in their user-approved form. The new corridor pass adds Trident's grey podium and glazing, Deccan Park's brick fins, Cyber Pearl's white bands, and the HDFC Bank / Whiteboard Cafe frontage. These are photo-informed reconstructions, not exact surveyed replicas of every property.

## Reference and scale

- Engine: Godot 4.7.2, Compatibility renderer for Windows, Android and WebGL 2.
- World units: metres. OSM origin 17.4485 N, 78.3825 E.
- Cyber Towers footprint: OSM way 68883448. Curved perimeter interpolates the original outline. Ten storeys use an estimated 3.4 m floor height, not a surveyed elevation.
- Primary visual reference: user-supplied `hyd-images/cyber towers-bottom view.png`; additional side view and metro-pillar photographs. These Google Street View screenshots are modelling references and are not included as game textures.
- Reference camera 1: latitude 17.4509238, longitude 78.3818386, heading 240.88Â°, tilt 115.26Â°. Camera height 2.5 m and vertical FOV 75Â° are estimates. The lens convention and panorama registration have not been surveyed.
- Actual window mullions are 35â€“45 mm wide; crown members 130â€“240 mm; outer diagonal braces 220â€“240 mm. These dimensions are visual estimates.
- Frontage planting, fence, metro deck height, pillar locations, and landscaping are estimated. The exact pillar spacing, signage, traffic mix, entrances, road elevations, and neighbouring facades remain incomplete.

## Rendering

Native window resolution, 4Ã— MSAA in High / 2Ã— in Balanced, no temporal AA, motion blur or depth-of-field blur. Mipmaps and anisotropic filtering keep detailed surfaces stable at a distance. Concrete, sandstone and asphalt use 2048 px material maps, with physical tiling sizes and restrained normal strength. Foliage uses alpha-cutout leaf textures instead of solid polygon crowns. Daylight and reflections use an HDR sky.

The city batches surfaces into 250 m cells. Foliage has a shorter visibility range. A versioned local mesh cache avoids rebuilding the entire district on every launch; changed source geometry invalidates the cache. The first launch shows construction progress. This cache is derived data, not a replacement for the OSM source.

## Assets and attribution

Texture and HDR sources, download URLs and SHA-256 hashes are recorded in `asset-provenance.json`; foliage sources are in `foliage-provenance.json`. Poly Haven assets are CC0: https://polyhaven.com/license . Powered by Poly Haven.

The shrub glTF is imported as a candidate asset and is not yet placed in the city. The leaf and bark textures are active assets. Generic terrain materials remain reusable source candidates where not assigned.

Map data: Â© OpenStreetMap contributors, ODbL, https://www.openstreetmap.org/copyright . Geometry and roads derive from the saved local Overpass snapshot. Game modelling code and original reconstruction details are in `game/scripts/cyber_towers.gd` and `city.gd`.

## Inspecting the result

F6 cycles through five fixed reference views and returns to gameplay. Escape opens the menu; Resume leaves inspection mode. C cycles third-person, distant and first-person cameras. Native comparisons are written to `build/reference-N.png` by `-- --capture --reference=N` (0â€“4).

The render is an engine screenshot, not a generated image or a composited promise of future graphics. Remaining mismatches should be judged against the original reference at the same camera location.

## Map revision and limitations

The refreshed Overpass snapshot is dated 2026-11-07 11:04:19 UTC and contains 18,080 elements. Relative to the prior snapshot, 19 mapped entities were added and no new building footprints were supplied. These are not claimed as newly constructed buildings.

`scripts/prepare_map.py` assembles building multipolygons, preserves 68 courtyard holes, and excludes seven duplicate relation-member ways and the Raidurg metro station footprint already represented by the elevated station. Roof triangulation preserves holes. Min-height tags keep canopies elevated. Legitimate OSM footprints are retained; unverified deletion is avoided. `game/data/building-profiles.json` provides inspectable per-building style overrides and an exclusion list.

Projection uses double-precision WGS84 ECEF calculations followed by local east/north coordinates. Independent PROJ control-point checks agree within 1 mm numerically; this does **not** mean the OSM survey or the photographs have millimetre accuracy. Road centre lines are unchanged geographic inputs. Joined road surfaces remove segment gaps, negative one-way tags reverse travel direction, and sidewalk offsets use road width. Junction widths without tags, road elevation, terrain and missing mapping remain estimates.

Height sources: 11 explicit OSM heights, 159 OSM level counts, seven reference estimates, and 13,458 conservative estimates. Unknown buildings use modest 1â€“4-floor defaults according to mapped use, replacing arbitrary tall-block heights. Nearby buildings add window recesses, slender mullions, balconies and roof tanks; distant facades use a simpler shader. Generic details and estimated planting are not claims about individual properties. The NIFT photo association remains tentative.

Five adult character variants use Quaternius CC0 rigged models, smooth vertex normals, clothing palettes and blended source animations. They are stylized, not photorealistic people. NPCs alternate walking, waiting, looking around and browsing activities and react to danger; their routines are not full daily-life simulation. Sedan, hatchback, SUV, auto-rickshaw and bus meshes are original approximate designs, not exact replicas of specific brands. Wheel animation and size-specific colliders are implemented. No new third-party vehicle models were imported.
