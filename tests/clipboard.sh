#!/bin/bash
# No Neovim or Windows process and no actual clipboard access.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 "$ROOT/tests/fixtures/clipboard.py" "$ROOT"
