# Maintaining the reference and future changes

## Normal checks

Run source verification and the unit checks before a change. CI runs those checks
on Windows and Linux and fetches two hardware-family reference samples. The manual
source-build workflow requires a licensed self-hosted Keil runner; no such runner
is provisioned by this repository.

The upstream-check workflow reports whether the latest non-prerelease upstream
tag still matches upstream.lock.json. It reports status in its run summary and
never modifies or auto-publishes firmware.

## Upstream updates

Use an explicit reviewed change:

1. Read the new upstream release notes, especially 3D mode, startup protection,
   layouts, settings and bootloader changes.
2. Pin the new source commit and release ID.
3. Import the source snapshot with its original notices and license.
4. Refresh the complete source and release-asset manifests from that exact release.
5. Verify every reference HEX and compare licensed source builds with the references.
6. Record hardware qualification separately from byte equality.
7. Publish with release notes that distinguish upstream work from Compasless work.

Keep the other three repositories unchanged unless a separately authorized
integration change needs them. Coordinate any runtime protocol change across the
affected repositories and preserve existing parameter tuning.

## Release provenance

Reference packages retain original upstream HEX filenames and include their
SHA-256 hashes. The verification report states whether source was rebuilt.
Publish reference imports as prereleases until the intended use is qualified.
Never relabel a downloaded binary as freshly compiled or claim an unmeasured
performance improvement.
