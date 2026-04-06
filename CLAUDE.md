# Clockwork Epicycles

## State of the project

Two simulation cores that don't share code. This is the main architectural debt.

### Core 1: mechanism_model.gd (2D, main.tscn)
- Iterative velocity projection with compliance fudge factors
- 7 subsystems: epicyclic, escapement, belt, cam, hammer/bell, ratchet, Geneva
- Parameters are empirical (magic numbers, not derived from geometry)
- All variables explicitly typed for WASM compatibility
- Tested by: physics_test_runner.gd + tests/test_suite.gd

### Core 2: mechanism/exact/ (3D, armillary.tscn)
- Everything derived from tooth counts + module
- GearGeometry: pitch radius, contact ratio, inertia from mass
- ContactSolver: velocity-level Baumgarte stabilization
- BevelGeometry: cone angle law for right-angle transfer
- OrreryMechanism: 12 bodies, Willis equation enforced
- Tested by: tests/test_exact_epicyclic.gd + tests/test_orrery_mechanism.gd

### What's missing
- No shared code between the two cores
- OrreryMechanism duplicates ExactEpicyclic's epicyclic solver
- 3D gear meshes are visual cylinders, not involute profiles
- No coherent design principle connecting the 2D and 3D presentations

## Quick reference

```bash
# All tests
godot --headless --path . --script res://scripts/tests/test_suite.gd
godot --headless --path . --script res://scripts/tests/test_exact_epicyclic.gd
godot --headless --path . --script res://scripts/tests/test_orrery_mechanism.gd
```

## WASM rules
- Every local variable needs explicit type (`: float =` not `:=`)
- Use `preload()` not `class_name` for cross-file references
- Renderer must be `gl_compatibility` for web (patched in deploy workflow)
- `script_export_mode=2` (text, not compiled) in web export preset

## CI
- build.yml: linux tests → macOS export
- deploy-web.yml: linux test → web export → GitHub Pages (armillary scene)
- Service worker at web/coi-serviceworker.js for COOP/COEP
