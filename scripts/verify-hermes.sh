#!/bin/bash
# Non-installing Hermes/uv ownership and persisted-build-option verification.
# Called by full verification on WSL; isolated tests supply fake HOME and mise.
set -euo pipefail
fail() { printf 'FAIL: Hermes %s\n' "$1" >&2; exit 1; }
for item in uv hermes; do
  spec=$item
  [[ $item != hermes ]] || spec='pipx:hermes-agent[extras=all]'
  root=$(mise where "$spec" 2>/dev/null) || fail "$item is not installed through mise"
  executable=$(mise which "$item" --tool "$spec" 2>/dev/null) || fail "$item executable cannot be resolved"
  root=$(realpath -e -- "$root") || fail 'install directory is missing'
  executable=$(realpath -e -- "$executable") || fail 'installed executable is missing'
  [[ $root == "$HOME/.local/share/mise/installs/"* && $executable == "$root/"* && -x $executable ]] ||
    fail "$item executable is outside its mise installation"
  resolved=$(type -P "$item") || fail "$item is not on PATH"
  if [[ $item == hermes && $resolved == "$HOME/.local/bin/hermes" ]]; then
    wrapper=$(realpath -e -- "${BASH_SOURCE[0]%/*}/../mise/.local/bin/hermes") || fail 'managed wrapper is missing'
    [[ $(realpath -e -- "$resolved") == "$wrapper" ]] || fail 'Hermes wrapper is not deployed from this clone'
  else
    [[ $(realpath -e -- "$resolved") == "$executable" ]] ||
      fail "$item does not resolve to its selected installation; open a fresh mise-activated shell"
  fi
done
"$root/hermes-agent/bin/python" -I -S -B -c 'import sys; raise SystemExit(sys.version_info[:2] != (3, 13))' ||
  fail 'environment is not Python 3.13'
# Inspect only the named host-owned tool declaration, without printing values.
python3 - "$HOME/.config/mise/config.toml" <<'PY' || fail 'persistent Python 3.13 installation options are missing'
import sys, tomllib
try:
    with open(sys.argv[1], "rb") as source:
        tool = tomllib.load(source)["tools"]["pipx:hermes-agent"]
    assert isinstance(tool, dict)
    assert tool.get("extras") == "all"
    assert tool.get("uvx_args") == "--python 3.13"
    assert tool.get("pipx_args") == "--python 3.13"
except Exception:
    sys.exit(1)
PY
printf 'ok:   Hermes and uv resolve through mise; Python 3.13 build options persist\n'
