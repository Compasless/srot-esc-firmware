"""Run the five-repository Git manager from the current SROT workbench."""
from pathlib import Path
import runpy
import sys

root = Path(__file__).resolve().parents[1]
manager = root / "repos/srot-esc-firmware/tools/manage_workspace.py"
if not manager.is_file():
    raise SystemExit("Missing repos/srot-esc-firmware checkout; see SROT_WORKSPACE.md")
sys.argv = [str(manager), "--workspace", str(root / "srot-workspace.json"), *sys.argv[1:]]
runpy.run_path(str(manager), run_name="__main__")
