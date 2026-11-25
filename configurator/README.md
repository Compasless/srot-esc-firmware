# Compasless SROT ESC Configurator

A browser bench tool for the existing SROT ESP32 USB flasher and Compasless 3D ESC firmware.

Hosted interface: https://compasless-srot-esc-configurator.plainlatte33.chatgpt.site
The hosted Site uses the owner's default private access. The standalone release
can also be served locally without a Sites account.

Connect in desktop Chrome or Edge, read the channels, select an ESC, then flash its
matching firmware. The app reads up to four independent channels over MSP/4-way at
115200 baud. The SROT flasher's hardware firmware is unchanged.

The interface recognizes Compasless layout 208, exposes a bounded set of tuning
fields, forces direction field 3 when saving, verifies firmware SHA-256 before
flashing, preserves hardware-layout checks and uses the upstream erase/write/readback
logic. There are no motor-test controls and no MCU-layout override.

The firmware library includes all 1,008 verified v0.4.0 HEX targets. Download a
matching file here for local-file flashing in esc-configurator.com. The public
site can flash/reflash these images but does not recognize their settings family;
it may display BLHeli_S 0.4 or UNKNOWN. Use this interface for settings.

## Development

Use Node 22 or later:

    npm ci
    npm run build
    npm test
    npm run qa
    npm run preview

The preview is http://127.0.0.1:4173. Browser QA uses installed Chrome/Edge when
available; otherwise install the Playwright Chromium browser with
`npx playwright install chromium`.

Build inputs are pinned in upstream.lock.json. The build downloads and verifies
the original configurator source archive and the already-published firmware ZIP.
It adds a Compasless firmware source and detection branch; serial/MSP/4-way drivers,
hardware checks and flash/readback routines are reused. No firmware bytes change.

Tests cover every target's detection and checksums, forbidden mode edits, H/X
flashing and settings through a simulated native Web Serial port, stock-site
flashing/reflashing, and blocked mismatches. Browser QA exercises connection,
four-channel scanning, flashing, settings save, checksum rejection, downloads,
mobile/desktop layout and disconnect. No physical device is accessed by tests.

## Standalone release

Extract the configurator ZIP, then serve that directory:

    python -m http.server 4173 --bind 127.0.0.1

Open http://127.0.0.1:4173 in Chrome or Edge. Opening index.html directly as a file
does not provide the same-origin fetch environment the app needs.

## License and qualification

This interface is an AGPL-3.0 derivative of ESC Configurator; see LICENSE, NOTICE
and the pinned source recipe. Firmware remains under its own GPL license.
Corresponding source and build inputs are published in this repository.

All verification is software-based. ESC hardware and underwater qualification
remain pending, and the inherited 3D performance issue is unresolved.
