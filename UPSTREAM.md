# Upstream provenance and Compasless maintenance

The firmware in this repository comes from
[bird-sanctuary/bluejay](https://github.com/bird-sanctuary/bluejay), release
[v0.21.0](https://github.com/bird-sanctuary/bluejay/releases/tag/v0.21.0), commit
`93bf3e1a081ee87357aface06e535480dcc191d8`.

The complete 71-file release source snapshot is under `vendor/bluejay`. File sizes
and SHA-256 hashes are recorded in `provenance/source-manifest.json`. The snapshot
includes the upstream README, license, Makefile, tools, source and notices.
Vendored GitHub workflows are reference material; they are not active workflows
of this repository.

Bluejay's source notices credit Daniel Mosquera, Mathias Rasmussen and Steffen
Skaug, alongside the contributors to their projects. Bluejay descends from
[BLHeli_S](https://github.com/bitdump/BLHeli) revision 16.7 and the original
[mathiasvr/bluejay](https://github.com/mathiasvr/bluejay) project. Preserve the
original per-file notices and [COPYING](COPYING) when redistributing.

Compasless authored the surrounding SROT integration documentation, Python build
and validation tools, release manifests and four-repository workspace setup.
Compasless does not claim original authorship of Bluejay's control algorithms.

The reference release makes no firmware source or default-setting changes.
Original HEX filenames, firmware signatures and configuration layouts are
preserved. Downloaded release binaries are distinguished from source-rebuilt
artifacts by their verification reports.

Upstream v0.21.0 describes a known performance problem with 3D mode and advises
against its use. This unchanged reference inherits that limitation. No improvement
in AUV thrust, efficiency, startup or reversal has been demonstrated here.
Qualification work is described in [docs/QUALIFICATION.md](docs/QUALIFICATION.md).
