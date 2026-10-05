#!/usr/bin/env bash
# Exercise Windows Terminal deployment in an indexed scratch source/home,
# including a source with no commits. Git-visible working files are the input;
# missing files remain missing, including pending source retirements.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
# The source stays outside this newly allocated fixture root even when the
# source itself is a staged-file export somewhere under /tmp.
export TMPDIR="$TMP"
shopt -s nullglob

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# Keep fixture Git operations and the guard subprocesses off caller-selected
# repositories and configuration. Every Windows destination stays in scratch.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
unset GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
git() {
  command env -i PATH="$PATH" HOME="$TMP/git-home" XDG_CONFIG_HOME="$TMP/git-home/.config" \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git "$@"
}
[[ -n ${EYRWSL_PACKAGES:-} ]] || fail 'EYRWSL_PACKAGES is required'
read -r -a packages <<<"$EYRWSL_PACKAGES"
(( ${#packages[@]} )) || fail 'package list is empty'

mapfile -d '' -t sources < <(git -C "$ROOT" ls-files -z --cached --others --exclude-standard -- \
  .gitignore Makefile scripts/prepare-stow.sh scripts/wt-diff.sh tests/wt-diff.sh \
  windows-terminal/settings.json "${packages[@]}")
scan=$!; wait "$scan" || fail 'cannot enumerate source files'
mkdir "$TMP/repo"
for path in "${sources[@]}"; do
  [[ -e $ROOT/$path || -L $ROOT/$path ]] || continue
  mkdir -p "$TMP/repo/$(dirname -- "$path")"
  cp -a -- "$ROOT/$path" "$TMP/repo/$path"
done
git -C "$TMP/repo" init -q
git -C "$TMP/repo" add -A
SOURCE_ROOT=$ROOT
ROOT="$TMP/repo"
if [[ ${WT_DIFF_INDEX_CHILD:-0} == 1 ]]; then
  [[ -f $ROOT/bash/.config/bash/functions/wt-fixture-untracked ]] || fail 'untracked source was lost'
  [[ ! -e $ROOT/bash/.config/bash/functions/tdw && ! -L $ROOT/bash/.config/bash/functions/tdw ]] ||
    fail 'pending source retirement was resurrected'
fi
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

if [[ ${WT_DIFF_INDEX_CHILD:-0} == 0 ]]; then
  if git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
    fail 'indexed source unexpectedly has a commit'
  fi
  # The child source also has a pending tracked deletion and a new untracked
  # package leaf. Its working files, not a commit or the index alone, must win.
  printf '# retired fixture\n' >"$ROOT/bash/.config/bash/functions/tdw"
  git -C "$ROOT" add -- bash/.config/bash/functions/tdw
  rm -- "$ROOT/bash/.config/bash/functions/tdw"
  printf '# untracked fixture\n' >"$ROOT/bash/.config/bash/functions/wt-fixture-untracked"
  mkdir "$TMP/child-tmp"
  WT_DIFF_INDEX_CHILD=1 TMPDIR="$TMP/child-tmp" bash "$ROOT/tests/wt-diff.sh"
  printf 'ok: Windows Terminal fixture also passes from an uncommitted indexed source\n'
fi

printf 'ok: Windows Terminal push is validated, backup-first, and idempotent\n'
