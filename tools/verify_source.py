# SPDX-License-Identifier: GPL-3.0-or-later
from srot import lock, verify_source

if __name__ == "__main__":
    count = verify_source()
    print(f"Verified {count} unchanged Bluejay source files at {lock()['commit']}.")
