# Water Rendering Specification

## Core Idea

The visual model is not "spawn one circular droplet per image pixel."

Instead, use fixed horizontal **emitter lanes**.

Each emitter lane may produce a finite water segment over a time interval.

Conceptual data:

```text
emitter_index
segment_start_time
segment_end_time
width
brightness
seed
```

## Falling Motion

Use a tunable falling function such as:

```text
y(t) = v0 * t + 0.5 * g * t^2
```

`v0` and `g` are visual parameters.

They do not need to reproduce real-world SI units.

They should produce convincing gravity on the 1280×720 display.

## Segment Geometry

For an emission interval:

```text
start_time = t0
end_time   = t1
```

At current time `T`:

```text
front_age = T - t0
back_age  = max(0, T - t1)

front_y = fall(front_age)
back_y  = fall(back_age)
```

Render the region between `back_y` and `front_y` as the visible water segment.

If the segment is still emitting, the back can remain connected to the top emitter area.

## Why This Matters

This single model can produce:

- bead-like short pieces
- short vertical strokes
- longer threads
- curtain-like continuous streams

It better matches the visual character of a timed water curtain than treating all output as circular particles.

## Pattern Conversion

Input:

- text mask
- monochrome image
- vector silhouette
- procedural motif

Convert to canonical emitter-lane space.

Conceptual process:

```text
pattern
→ monochrome mask
→ sample across emitter lanes
→ identify vertical occupied regions
→ convert target vertical positions to formation timing
→ merge contiguous occupied regions
→ create emission segments
```

Do not emit six separate droplets when six vertically adjacent pattern cells can be represented as one finite water segment.

## Formation Time

A pattern is readable at a selected formation time.

Emission times must be calculated so falling water aligns with the target geometry at that moment.

The water is never stationary at the formation time.

After formation:

- lower geometry continues downward
- water accelerates
- vertical geometry stretches
- the pattern becomes unreadable
- water exits the canvas

## Emitter Density

Use a logical emitter grid appropriate for the 1280px width.

A 384-lane profile may be used as an implementation reference:

1280 / 384 ≈ 3.33 px per logical lane

The renderer should still be structured so this can be tuned.

## Shader / Rendering Suggestions

Possible implementation:

- MultiMesh2D or equivalent batched segment rendering
- CanvasItem shader for highlight / width modulation / softness
- particles only for splash / mist / breakup

Avoid making GPUParticles2D the primary representation of the full pattern.

## Water Appearance

Prefer:

- white to blue-white
- subtle transparency
- bright edge/highlight
- slight width irregularity
- slight motion softness
- vertical continuity

Do not over-blue the entire effect.

On a transparent display, high-contrast luminous water against a calibrated dark/transparent background is desirable.
