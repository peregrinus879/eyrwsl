#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
shopt -s nullglob

# Exercise the real deployment guards in a disposable clone and home only.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
git clone -q --shared -- "$ROOT" "$TMP/repo"
for path in Makefile scripts/prepare-stow.sh scripts/wt-diff.sh windows-terminal/settings.json; do
  cp -- "$ROOT/$path" "$TMP/repo/$path"
done
# Keep the guard's fixture tree consistent with pending source retirements.
for path in bash/.config/bash/functions/herdr bash/.config/bash/functions/tdw bash/.config/bash/functions/tmux tmux/.config/tmux/tmux.conf; do
  if [[ ! -e $ROOT/$path && ! -L $ROOT/$path && ( -e $TMP/repo/$path || -L $TMP/repo/$path ) ]]; then
    git -C "$TMP/repo" rm -q -- "$path"
  fi
done
SOURCE_ROOT=$ROOT
ROOT="$TMP/repo"
export HOME="$TMP/home" PREPARE_STOW_KERNEL_RELEASE=6.6.0-microsoft-standard-WSL2
mkdir "$HOME"
export PREPARE_STOW_INTEROP_ROOT="$TMP/interop"
mkdir -p "$PREPARE_STOW_INTEROP_ROOT" "$TMP/interop-bin"
printf 'enabled\n' >"$PREPARE_STOW_INTEROP_ROOT/status"
printf 'enabled\n' >"$PREPARE_STOW_INTEROP_ROOT/WSLInterop"
printf '#!/bin/bash\nexit 0\n' >"$TMP/interop-bin/powershell.exe"
printf '#!/bin/bash\nexit 99\n' >"$TMP/interop-bin/clip.exe"
chmod +x "$TMP/interop-bin/"*.exe
export PATH="$TMP/interop-bin:$PATH"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

deployed="$TMP/settings.json"
original="$TMP/original.json"
printf '{"profiles":{"defaults":{}},"schemes":[]}\n' >"$deployed"
cp -- "$deployed" "$original"

if WT_SETTINGS="$deployed" "$SOURCE_ROOT/scripts/wt-diff.sh" --push >"$TMP/wrong-clone.out" 2>&1; then
  fail "direct push from the real clone accepted fixture host overrides"
fi
cmp -s "$original" "$deployed" || fail "guard refusal changed the destination"
mkdir -p "$HOME/.config"
ln -s "$SOURCE_ROOT/bash/.bashrc" "$HOME/.bashrc"
if WT_SETTINGS="$deployed" "$ROOT/scripts/wt-diff.sh" --push >"$TMP/foreign.out" 2>&1; then
  fail "direct push accepted a foreign deployed clone"
fi
cmp -s "$original" "$deployed" || fail "clone guard refusal changed the destination"
rm "$HOME/.bashrc"

WT_SETTINGS="$deployed" "$ROOT/scripts/wt-diff.sh" --push >/dev/null
cmp -s "$ROOT/windows-terminal/settings.json" "$deployed" || fail "push did not deploy tracked settings"

backups=("$deployed".backup-*)
(( ${#backups[@]} == 1 )) || fail "push did not create exactly one backup"
cmp -s "$original" "${backups[0]}" || fail "backup does not preserve deployed settings"

jq -S . "$deployed" >"$TMP/reordered.json"
mv -- "$TMP/reordered.json" "$deployed"
cmp -s "$ROOT/windows-terminal/settings.json" "$deployed" && fail "normalized fixture did not change file order"
WT_SETTINGS="$deployed" "$ROOT/scripts/wt-diff.sh" --push >/dev/null
backups=("$deployed".backup-*)
(( ${#backups[@]} == 1 )) || fail "normalized no-op push created another backup"
WT_SETTINGS="$deployed" "$ROOT/scripts/wt-diff.sh" >/dev/null || fail "deployed settings drift after push"

invalid="$TMP/invalid.json"
printf '{\n' >"$invalid"
if WT_SETTINGS="$invalid" "$ROOT/scripts/wt-diff.sh" --push >/dev/null 2>&1; then
  fail "invalid deployed JSON did not fail"
fi
invalid_backups=("$invalid".backup-*)
(( ${#invalid_backups[@]} == 0 )) || fail "invalid deployed JSON created a backup"

unstageable="$TMP/unstageable.json"
cp -- "$original" "$unstageable"
mkdir "$TMP/fail-bin"
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/fail-bin/chmod"
chmod +x "$TMP/fail-bin/chmod"
if PATH="$TMP/fail-bin:$PATH" WT_SETTINGS="$unstageable" \
  "$ROOT/scripts/wt-diff.sh" --push >/dev/null 2>&1; then
  fail "unstageable deployment did not fail"
fi
unstageable_backups=("$unstageable".backup-*)
(( ${#unstageable_backups[@]} == 0 )) || fail "staging failure created a backup"
cmp -s "$original" "$unstageable" || fail "staging failure changed deployed settings"

set +e
"$ROOT/scripts/wt-diff.sh" --pull >/dev/null 2>&1
status=$?
set -e
[[ $status == 2 ]] || fail "unsupported mode did not return usage status"

printf 'ok: Windows Terminal push is validated, backup-first, and idempotent\n'
