#!/bin/bash
# Isolated installer argv/failure and non-installing verifier fixtures.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
umask 077
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" XDG_DATA_HOME="$TMP/home/.local/share"
export XDG_CACHE_HOME="$TMP/cache" HISTFILE=/dev/null
unset UV_PYTHON HERMES_HOME MISE_PIN
mkdir -p "$HOME/.local/bin" "$TMP/bin" "$HOME/.config/mise"
export HERMES_FIXTURE_ROOT="$HOME/.local/share/mise/installs/pipx-hermes-agent/0.19.0"
export HERMES_FIXTURE_LOG="$TMP/calls"
mkdir -p "$HERMES_FIXTURE_ROOT/hermes-agent/bin" "$HOME/.local/share/mise/installs/uv/0.12.11/bin"
ln -s "$ROOT/mise/.local/bin/hermes" "$HOME/.local/bin/hermes"
cat >"$TMP/bin/mise" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$HERMES_FIXTURE_LOG"
case "$*" in
  'use -g --quiet --fuzzy uv') [[ ${HERMES_FIXTURE_FAIL:-} != uv ]] ;;
  'use -g --quiet --fuzzy pipx:hermes-agent[extras=all,uvx_args="--python 3.13",pipx_args="--python 3.13"]') [[ ${HERMES_FIXTURE_FAIL:-} != hermes ]] ;;
  'where pipx:hermes-agent[extras=all]') printf '%s\n' "$HERMES_FIXTURE_ROOT" ;;
  'which hermes --tool pipx:hermes-agent[extras=all]') printf '%s/hermes-agent/bin/hermes\n' "$HERMES_FIXTURE_ROOT" ;;
  'where uv') printf '%s/.local/share/mise/installs/uv/0.12.11\n' "$HOME" ;;
  'which uv --tool uv') printf '%s/.local/share/mise/installs/uv/0.12.11/bin/uv\n' "$HOME" ;;
  'x pipx:hermes-agent[extras=all] -- hermes '*| 'x pipx:hermes-agent[extras=all] -- hermes')
    [[ ${UV_PYTHON+x} != x ]] || exit 94
    shift 4
    printf '%s\0' "$@" >"$HERMES_FIXTURE_LOG.args" ;;
  *) exit 95 ;;
esac
SH
cat >"$HERMES_FIXTURE_ROOT/hermes-agent/bin/python" <<'SH'
#!/bin/bash
[[ $* == '-I -S -B -c import sys; raise SystemExit(sys.version_info[:2] != (3, 13))' ]] || exit 96
[[ ${HERMES_FIXTURE_FAIL:-} != python ]]
SH
printf '#!/bin/bash\nexit 97\n' >"$HERMES_FIXTURE_ROOT/hermes-agent/bin/hermes"
printf '#!/bin/bash\nexit 98\n' >"$HOME/.local/share/mise/installs/uv/0.12.11/bin/uv"
chmod +x "$TMP/bin/mise" "$HERMES_FIXTURE_ROOT/hermes-agent/bin/"* "$HOME/.local/share/mise/installs/uv/0.12.11/bin/uv"
export PATH="$TMP/bin:$HOME/.local/bin:$HOME/.local/share/mise/installs/uv/0.12.11/bin:$PATH"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
"$HOME/.local/bin/hermes" --model 'a model' -c
python3 - "$HERMES_FIXTURE_LOG" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
lines = p.read_text().splitlines()
assert lines[0] == "use -g --quiet --fuzzy uv"
assert 'uvx_args="--python 3.13"' in lines[1]
assert p.with_suffix(".args").read_bytes() == b"--model\0a model\0-c\0"
PY
for stage in uv hermes python; do
  : >"$HERMES_FIXTURE_LOG"
  if HERMES_FIXTURE_FAIL=$stage "$HOME/.local/bin/hermes" --version >/dev/null 2>&1; then
    fail "$stage failure did not stop installation"
  fi
  ! grep -q '^x ' "$HERMES_FIXTURE_LOG" || fail "$stage failure still launched Hermes"
done
cat >"$HOME/.config/mise/config.toml" <<'TOML'
[tools]
"pipx:hermes-agent" = { version = "latest", extras = "all", uvx_args = "--python 3.13", pipx_args = "--python 3.13" }
TOML
: >"$HERMES_FIXTURE_LOG"
bash "$ROOT/scripts/verify-hermes.sh"
! grep -qE '^(use|x) ' "$HERMES_FIXTURE_LOG" || fail 'verification installed or launched a tool'
printf '#!/bin/bash\nexit 98\n' >"$HOME/.local/bin/uv"
chmod +x "$HOME/.local/bin/uv"
if bash "$ROOT/scripts/verify-hermes.sh" >/dev/null 2>&1; then fail 'foreign local uv passed ownership verification'; fi
rm "$HOME/.local/bin/uv"
rm "$HOME/.local/bin/hermes"
cp "$ROOT/mise/.local/bin/hermes" "$HOME/.local/bin/hermes"
if bash "$ROOT/scripts/verify-hermes.sh" >/dev/null 2>&1; then fail 'foreign Hermes wrapper passed ownership verification'; fi
rm "$HOME/.local/bin/hermes"
ln -s "$ROOT/mise/.local/bin/hermes" "$HOME/.local/bin/hermes"
HERMES_FIXTURE_FAIL=python bash "$ROOT/scripts/verify-hermes.sh" >/dev/null 2>&1 && fail 'wrong Python passed verification'
printf '[tools]\n' >"$HOME/.config/mise/config.toml"
if bash "$ROOT/scripts/verify-hermes.sh" >/dev/null 2>&1; then fail 'missing persistent options passed'; fi
printf 'ok:   Hermes mise installation ordering, argv, failures and read-only verification\n'
