# Clockwork Epicycles

A Godot 4.2 mechanical simulation with two rendering modes: a 2D clockwork visualization and a 3D armillary orrery.

## What this is

A constraint-based mechanism simulator where gear motion emerges from contact forces and velocity constraints, not animation. Two simulation cores:

- **mechanism_model.gd** — 7 interacting subsystems (epicyclic gears, escapement, belt, cam/follower, hammer/bell, ratchet, Geneva) using iterative velocity projection
- **mechanism/exact/** — tooth-count-derived epicyclic train with bevel gear chain, where all geometry follows from module and tooth counts

Both enforce physically motivated constraints. The exact model validates the Willis equation to 3 decimal places through contact dynamics.

## Running

```bash
# Godot editor
godot --path .

# Headless tests
godot --headless --path . --script res://scripts/tests/test_suite.gd
godot --headless --path . --script res://scripts/tests/test_exact_epicyclic.gd
godot --headless --path . --script res://scripts/tests/test_orrery_mechanism.gd
```

## Controls

| Key | Action |
|-----|--------|
| Space | Pause / resume |
| Up / Down | Adjust drive torque |
| R | Reset |
| O | Toggle camera orbit (3D) |

## Live

https://uprootiny.github.io/clockwork-epicycles/

## Known limitations

- Two simulation cores share no code (mechanism_model.gd and orrery_mechanism.gd duplicate concepts independently)
- Web export requires service worker for SharedArrayBuffer; first visit may require reload
- The 2D model's tuning parameters are empirical, not derived from geometry
- The 3D armillary's visual gear meshes are decorative cylinders, not involute profiles
