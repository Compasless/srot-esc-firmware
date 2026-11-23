# SROT ESC changes

## 0.2.0 — active Compasless firmware source refactor

- Added src/SrotEsc.asm as the active compiler entry.
- Reorganized firmware into 60 source files by core, control, protocol, driver,
  hardware, memory, settings, storage, interrupts and boot responsibilities.
- Split the previous main program into 12 ordered units.
- Namespaced 535 code/data labels without changing instruction/data ordering.
- Added all-branch source equivalence checks and mutation tests.
- Pointed the build at the active source; retained the original source as reference.
- Added a central four-repository Git manager for the existing local workbench.

Behavior/defaults/protocols are preserved. Fresh compilation and hardware
qualification are recorded separately and must not be implied by source checks.

## 0.1.0-reference — upstream reference import

Imported unmodified Bluejay v0.21.0 source and all 1,008 release assets with hashes,
license, packaging and build wrappers. This was a reference distribution, not a
firmware source rewrite.
