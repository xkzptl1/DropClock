# Sakura Pattern Specification

## Objective

Implement a Sakura / spring sequence that feels like a dense, continuously flowing seasonal water-curtain pattern rather than a single flower icon.

## Visual Reference

Primary density / curtain-usage reference:

https://maido-storage.oss-cn-hongkong.aliyuncs.com/maido/uploads/2020/09/202008-meeting-location-04.jpg

Use this image as a reference for:

- full-width curtain usage
- motif density
- neighboring pattern rhythm
- avoiding a small centered visualizer composition

Do not trace copyrighted artwork from the reference.

Create original DropClock flower geometry.

## Current Problem to Avoid

Do NOT produce:

- one large Sakura centered on the screen
- 5–8 isolated flowers with huge empty gaps
- an icon grid
- a neat evenly spaced wallpaper
- a completed flower sprite moving downward

## Width and Density

Target canonical canvas:

1280 × 720

Decorative Sakura coverage:

- approximately 90–96% of usable width
- approximate X range: 25 ... 1255

Use many floral motifs.

Depending on motif size, approximately 10–20 recognizable or partially recognizable floral forms may participate in the active sequence at once.

This is not a strict numeric requirement.

Visual density is more important than an exact flower count.

## Spatial Arrangement

Use:

- slight size variation
- irregular horizontal spacing
- irregular vertical offsets
- partial overlap
- negative space in small pockets, not enormous empty fields
- multiple motif generations

Do not use a clean grid.

Conceptual density only:

```text
  🌸 🌸      🌸  🌸 🌸       🌸
      🌸 🌸        🌸     🌸
 🌸       🌸 🌸 🌸      🌸  🌸
    🌸 🌸       🌸   🌸
```

Emoji are reference-only and must never be production graphics.

## Continuous Flow

The sequence must not appear as one static full-field picture.

Behavior:

1. first flower group begins entering from the top
2. flowers become recognizable while falling
3. another group begins before the first has exited
4. earlier flowers continue accelerating downward
5. their geometry stretches and collapses
6. another group follows from above
7. multiple generations coexist vertically

The effect should feel like spring motifs are continuously pouring through the water curtain.

## Timing

Do not trigger every motif at the same timestamp.

Use staggered groups or per-motif phase offsets.

An example only:

- Group A
- +100–250ms Group B
- +100–250ms Group C
- start the next generation before Group C fully exits

Tune timing visually.

Do not hard-code the example numbers if a better rhythm is found.

## Physics Rules

All visible flower geometry:

- originates from top emitter lanes
- remains under vertical gravity
- is composed from water segments
- keeps moving while recognizable
- continues falling after recognition
- naturally distorts and disappears

Do not:

- freeze water
- animate completed flower sprites
- move petals arbitrarily sideways
- use normal floating-particle flower animation as the primary effect

Small water irregularities are allowed.

## Full-Width Rule

Do not solve the problem by scaling one flower to a huge size.

Solve it using:

- more motifs
- repeated motifs
- staggered phases
- overlapping generations
- varied scales
- wide emitter-lane usage

## Resize / Scaling Requirements

All Sakura geometry and timing must remain defined in canonical 1280×720 coordinates.

Window changes MUST NOT rearrange or regenerate Sakura.

Resizing only changes final display scaling.

Use:

```text
scale = min(viewport_width / 1280.0,
            viewport_height / 720.0)

offset_x = (viewport_width - 1280 * scale) / 2
offset_y = (viewport_height - 720 * scale) / 2
```

Never independently scale X and Y.

## Acceptance Criteria

A successful Sakura sequence should satisfy all of the following:

- visually occupies most of the water-curtain width
- does not look like a centered app icon
- multiple flowers are visible in overlapping timing generations
- no completed flower sprite is used
- flowers are produced by the falling-water renderer
- resizing does not change motif relationships
- at 1280×720, the sequence remains visually dense and readable
