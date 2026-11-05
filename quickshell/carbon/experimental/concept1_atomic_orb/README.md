# Concept 1: Atomic Valence / Quantum Orbital Shell

## Archived Components
- `AtomicOrb.qml`: Centerpiece screen-centered Quantum Nucleus with dual counter-rotating valence electron beads (no track lines, no seconds, pure time in center).
- `AtomicValenceBar.qml`: Full top-bar variation with quantum energy levels for workspaces, Bohr logo launcher, and quantum status nodes.

## How to Restore
1. Copy `AtomicOrb.qml` to `quickshell/carbon/modules/AtomicOrb.qml`.
2. Ensure `AtomicOrb AtomicOrb.qml` is listed in `quickshell/carbon/modules/qmldir`.
3. In `shell.qml`:
   - Set `root.barMode = "atomic"` in `~/.config/hypr/carbon-bar-mode.json`.
