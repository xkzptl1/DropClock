# DropClock Product Specification

## Goal

Create a Windows application that behaves visually like a programmable water curtain rendered on a transparent display.

The target is not a conventional static clock.

Clock digits and decorative patterns should appear to emerge from falling water, remain readable only briefly, and then collapse as the water continues downward.

## Primary Hardware Target

- transparent display
- 1280 × 720
- 16:9
- Windows host
- 60 FPS

The exact transparent-display technology is currently unknown.

Therefore, background handling must be calibratable rather than assuming a specific OLED/LCD implementation.

## Background Calibration

Default to:

RGB(0, 0, 0)

but expose calibration so the user can choose the background value that produces the best apparent transparency on the actual panel.

Possible calibration screen:

- #000000
- #080808
- #101010
- white reference
- custom RGB

The chosen value should be persisted.

## Canonical Canvas

Simulation resolution is permanently:

1280 × 720

The simulation must remain identical when:

- window is resized
- window is maximized
- window is restored
- Windows DPI changes
- the application moves between displays
- output resolution changes

Only presentation scaling changes.

## Presentation Transform

Use:

scale = min(viewport_width / 1280.0, viewport_height / 720.0)

offset_x = (viewport_width - 1280 * scale) / 2
offset_y = (viewport_height - 720 * scale) / 2

Apply scale + offset only during final presentation.

## Fullscreen Behavior

Normal target mode:

- selected transparent display
- borderless fullscreen
- cursor hidden
- fixed simulation
- no persistent UI chrome

Settings can be shown through a hotkey or secondary settings window.

## Pattern Classes

### Clock Patterns

Examples:

- HH:MM
- weekday
- date

Clock patterns may be relatively centered and compact.

### Decorative Patterns

Examples:

- Sakura
- Ume
- Seigaiha
- autumn leaves
- musical motifs
- geometric patterns
- curtain / stripe sequences

These should generally use 90–96% of the canvas width when appropriate.

## Animation Rule

All patterns:

- originate at top emitter lanes
- are formed by falling water segments
- remain under gravity
- do not freeze
- continue falling after recognition
- naturally distort and exit the bottom

## MVP

### v0.1

- Windows application
- 1280×720 canonical canvas
- transparent-display target mode
- borderless fullscreen
- clock rendering
- falling-water segment renderer
- stable resize behavior
- 60 FPS target

### v0.2

- display/background calibration
- date/weekday patterns
- monitor selection persistence
- improved water shader
- splash support

### v0.3

- Sakura Shower
- additional seasonal motifs
- ambient pattern scheduler
- screensaver mode

## Definition of Done for Current Work

The current implementation should be considered acceptable only if:

- resizing does not destroy the composition
- Sakura uses the full curtain character rather than a small central icon
- visible flower geometry is produced by falling water
- multiple generations of Sakura motifs can coexist vertically
- the project remains 60 FPS at 1280×720 on the target Windows environment
