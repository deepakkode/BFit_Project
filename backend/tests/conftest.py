import sys
from pathlib import Path

project_root = Path(__file__).resolve().parents[2]
for import_root in (project_root, project_root / "backend"):
    if str(import_root) not in sys.path:
        sys.path.insert(0, str(import_root))