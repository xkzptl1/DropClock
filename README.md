# DropClock

*日本語: [README.ja.md](README.ja.md)*

DropClock is a Windows visual clock for a **1280×720 transparent display**.

Clock digits, words and seasonal motifs are not drawn as sprites. They are formed
by water falling under gravity from emitter lanes along the top edge: the water
becomes briefly recognisable as a shape at one instant, then keeps accelerating,
stretches, and disappears. The time when nothing is on screen is part of the piece.

It is a **software-only renderer**. It does not control physical water hardware.

## Status

Working prototype.

- clock (`HH:MM`), weekday and date
- six decorative patterns: 青海波 (seigaiha), 桜 (sakura), 梅 (ume), stripes, curtain,
  music staff
- sequenced playback that interleaves the clock with motifs and deliberate pauses
- borderless fullscreen, multi-monitor selection, settings overlay, Windows autostart
- 60 FPS at 1280×720

Not yet done: the remaining seasonal motifs (autumn/winter/summer), splash effects,
and screensaver mode. See `TODO.md`.

## Requirements

- Windows 10/11
- [Godot 4.7](https://godotengine.org/) to run from source (no runtime dependency
  for the exported build)

## Running

```bash
godot --path . -- --dev
```

Useful flags:

| flag | meaning |
|---|---|
| `--dev` / `--dev=WxH` | windowed with a visible cursor |
| `--screen=N` | which monitor to use fullscreen |
| `--list-screens` | print connected monitors and quit |
| `--pattern=ID` / `--live` | preview one pattern, frozen or in motion |
| `--list-patterns` | print the pattern library and quit |
| `--glyph-test=TEXT` | hold text still at its formation height |
| `--season=NAME` | force spring/summer/autumn/winter |
| `--mode=NAME` | renderer: `segments` (default) or `drops` |
| `--cycle=SECONDS` | length of one full rotation |
| `--capture=FILE` | save a PNG and quit |
| `--autostart=on\|off\|status` | Windows autostart (exported build only) |

`Esc` quits. `Ctrl+Alt+D` opens the settings overlay.

## Building

```bash
godot --headless --path . --export-release "Windows Desktop" export/DropClock.exe
```

Requires the Godot 4.7 Windows export templates. `export_presets.cfg` is not
versioned (see `.gitignore`), so the preset must be recreated locally: a
`Windows Desktop` preset with an embedded PCK, the console wrapper enabled, and
`include_filter="assets/patterns/*.txt"` so the pattern files reach the build.

## How it works

The unit of water is not a droplet. Each emitter lane has a valve; what it emits
between OPEN and CLOSE is one continuous body of water — a bead if the pulse is
short, a thread if it is long, a curtain if it never closes.

A pattern is a mask. Vertically contiguous cells in one lane are **merged into a
single pulse** rather than becoming separate droplets, which is what makes beads,
threads and curtains fall out of one mechanism. Merging is substantial in practice:
the curtain pattern collapses 47,040 mask cells into 336 pulses.

Emission times are inverted from the intended formation moment:

```
open_time  = formation − time_to_fall(bottom of the run)
close_time = formation − time_to_fall(top of the run)
```

After formation the leading end is falling faster than the trailing end, so the
shape stretches apart on its own. There is no collapse animation.

## Canonical canvas

All simulation uses a fixed **1280×720** coordinate system. Window size, DPI,
maximise/restore and monitor changes affect only the final presentation transform
(uniform scale, letterboxed). They never change emitter spacing, motif layout,
gravity or timing.

## Documentation

- `AGENTS.md` — mandatory project rules
- `docs/DROP_CLOCK_SPEC.md` — product and display specification
- `docs/WATER_RENDERING.md` — falling-water rendering behaviour
- `docs/SAKURA_PATTERN.md` — Sakura / spring specification
- `docs/REFERENCE.md` — public reference material
- `docs/IP_NOTES.md` — software-only project boundary
- `docs/GITHUB_RELEASE.md` — publication requirements
- `CLAUDE.md`, `PLAN.md`, `TODO.md`, `DONE.md` — working design notes (Japanese)

## Independence / Attribution

DropClock is an independent software-only visual simulation inspired by
programmable water curtains and gravity-driven water displays. It does not control
physical water-display hardware and is not affiliated with, endorsed by, or derived
from the proprietary control software or assets of JR West, Osaka Station City,
or KOEI.

All motif geometry is original and generated procedurally. No third-party artwork
is traced or bundled.

## License

[MIT](LICENSE).
