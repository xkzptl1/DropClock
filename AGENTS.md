# AGENTS.md — DropClock Project Rules

These rules are mandatory for all implementation work in this repository.

## 1. Product Goal

DropClock is a Windows visual clock for a transparent display.

The visual concept is inspired by programmable gravity-driven water displays such as the Osaka Station water clock, but DropClock is a software-only renderer.

It does NOT control physical water valves, pumps, nozzles, PLCs, fountains, or other water-display hardware.

## 2. Target Display

The primary target is:

- OS: Windows
- Display: transparent display
- Native resolution: 1280 × 720
- Aspect ratio: 16:9
- Target frame rate: 60 FPS
- Presentation: borderless fullscreen
- Normal UI: hidden during playback
- Mouse cursor: hidden during playback

## 3. Canonical Simulation Resolution

All simulation logic MUST use a fixed virtual canvas of:

1280 × 720

This is the canonical coordinate system for:

- emitter positions
- pattern geometry
- motif positions
- formation heights
- gravity calculations
- water-segment geometry
- animation timing

Window size, DPI scaling, maximize/restore state, or moving the window between monitors MUST NOT alter simulation geometry.

Resize only affects the final presentation transform.

Use a uniform scale:

scale = min(viewport_width / 1280.0, viewport_height / 720.0)

Then center the canonical canvas:

offset_x = (viewport_width - 1280 * scale) / 2
offset_y = (viewport_height - 720 * scale) / 2

Use the same scale for X and Y.

For non-16:9 windows:

- letterbox or pillarbox
- do not crop
- do not stretch independently
- do not reflow motifs
- do not change emitter spacing

## 4. Software-Only Water Rendering

The internal model should be described as:

- emitter lanes
- emission intervals
- water segments
- gravity-driven rendering

Avoid designing the software as a controller for real-world solenoid valves.

Do not add:

- PLC output
- GPIO output
- Modbus water-valve control
- DMX-to-solenoid control
- physical nozzle-control APIs
- export formats intended to drive real water hardware

## 5. Water Behavior

Water originates from the top emitter region.

Visible elements are NOT completed sprites moving downward.

Every clock digit, word, and decorative motif must be formed by falling water geometry.

The water:

1. begins at the top emitter region
2. falls continuously
3. accelerates vertically under gravity
4. briefly becomes recognizable as a pattern
5. never freezes in place
6. continues falling after formation
7. naturally stretches, distorts, and disappears

## 6. Water Is Not Always a Droplet

Do not model every visual element as a round particle.

An emission interval may appear as:

- a tiny bead-like segment
- a short vertical capsule
- a medium water segment
- a long water thread
- a continuous curtain

The visual length depends on the emission duration and the falling-water model.

Primary pattern rendering should therefore use dynamic water segments or threads.

Particles may be used for:

- splash
- mist
- tiny breakup droplets
- highlight effects

Particles must not replace the primary water-thread renderer.

## 7. Decorative Pattern Scale

Decorative and seasonal patterns should generally use approximately 90–96% of the canonical 1280px width when repetition is appropriate.

Do not constrain decorative patterns to a small centered visualizer region.

A reasonable full-width decorative area is approximately:

X = 25 ... 1255

Do not solve density by making one motif enormous.

Prefer:

- repeated motifs
- staggered timing
- overlapping generations
- slight scale variation
- phase variation across emitter lanes

Clock text may remain more centered and compact.

## 8. No Sprite Cheats

Do NOT:

- render a finished flower sprite and move it downward
- render finished digits and move them downward
- freeze water to make a readable shape
- use emoji as production graphics
- use a single texture as the main seasonal pattern
- independently float petals sideways as the core effect

Reference diagrams using emoji are conceptual only.

## 9. GitHub Delivery Requirement

After implementation and local validation are complete:

1. keep the project in a clean Git repository
2. update README.md and documentation
3. ensure generated/build artifacts that should not be versioned are in .gitignore
4. commit the completed implementation with a descriptive commit message
5. push the branch to the configured GitHub remote
6. if the project is ready for end-user distribution, create or update a GitHub Release and attach the Windows build
7. include concise release notes describing the implementation and known limitations

If GitHub credentials, permissions, or a remote are unavailable, do NOT silently skip publication.

Instead, report:

- what is complete locally
- the exact remote/permission issue
- the exact remaining Git commands or GitHub actions required

Do not rewrite repository history or force-push unless explicitly instructed.

## 10. Regression Rule

When fixing one visual pattern, do not break:

- canonical 1280×720 simulation
- resize behavior
- gravity
- water-segment rendering
- other seasonal patterns
- clock rendering
- fullscreen target-display behavior

Run a regression check after visual changes.
