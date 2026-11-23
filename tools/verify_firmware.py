# SPDX-License-Identifier: GPL-3.0-or-later
import argparse
import json
from firmware_equivalence import verify
from srot import save_json

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Verify the active Compasless firmware refactor")
    parser.add_argument("--report")
    args = parser.parse_args()
    result = verify()
    if args.report:
        save_json(args.report, result)
    print(json.dumps(result, indent=2))
