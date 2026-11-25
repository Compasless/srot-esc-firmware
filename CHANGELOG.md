# Changelog

## 0.4.0 — 2026-11-25

- Make 3D the sole compiled motor operating mode.
- Normalize legacy direction bytes on settings load, decode and save.
- Remove one-way branches, selectable orientation and turtle-mode handlers.
- Ignore direction/mode commands 7, 8, 9, 10, 20 and 21.
- Preserve beep, settings-save, EDT, 3D reversal and signal-loss behavior.
- Use the 16-byte runtime identity Compasless 3D and revision 0.4.
- Check compiled policy paths, protected source modules and complete image hashes.
- Rebuild all separate hardware targets; hardware qualification remains pending.
- The inherited 3D performance issue is unresolved.

## 0.3.0 — 2026-11-24

- Compasless runtime firmware identity and revision.
- Bidirectional direction default for reversible thruster development.
- Actual source-built HEX releases, with separate images for 1,008 targets.
- Native Windows build using an original frontend and ASEM-51.
- All original targets validated byte-for-byte before the declared firmware changes.
- Baseline flash checks restrict changes to name, revision and direction.
- Removed duplicate vendor source, reference-only packaging and Keil-only workflow.
- Retained complete active source, original copyright notices, license and credit.
- Development prerelease: hardware qualification and inherited 3D-mode issue remain.

Earlier releases contained upstream reference binaries or a source refactor without
fresh compiled Compasless firmware. The 0.3.0 release supersedes those artifacts.
