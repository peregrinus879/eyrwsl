#!/usr/bin/env bash
# Fixtures for scripts/prepare-stow.sh: a fake HOME holding a fake clone with
# this repo's package shape, laid out as Stow links it. Leftover folded links
# and dangling links from a moved clone are removed; live leaf links, repo
# content, and unowned entries are untouched; a regular file or anything
# unrecognized aborts before any removal; the WSL gate holds; a no-folding
# deployment keeps every managed parent real so host-local files never reach
# a package source.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
PACKAGES='bash git nvim yazi'
WSL_KERNEL='6.6.0-microsoft-standard-WSL2'
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

# A clone at $home/Projects/eyrwsl with the package shape that matters, so
# relative link text resolves the way Stow writes it under $HOME.
make_clone() {
  local repo=$1
  mkdir -p "$repo/bash/.config/bash" "$repo/git/.config/git" "$repo/nvim/.config/nvim/lua/config" \
    "$repo/yazi/.config/yazi" "$repo/scripts"
  printf 'bashrc\n' >"$repo/bash/.bashrc"
  printf 'envs\n' >"$repo/bash/.config/bash/envs"
  printf '[init]\n\tdefaultBranch = main\n' >"$repo/git/.config/git/config"
  printf 'init\n' >"$repo/nvim/.config/nvim/init.lua"
  printf 'options\n' >"$repo/nvim/.config/nvim/lua/config/options.lua"
  printf 'yazi\n' >"$repo/yazi/.config/yazi/yazi.toml"
  cp -- "$ROOT/scripts/prepare-stow.sh" "$repo/scripts/prepare-stow.sh"
  cp -- "$ROOT/Makefile" "$repo/Makefile"
  git -C "$repo" init -q
  git -C "$repo" add -A
}

prepare() { # home repo [kernel]
  HOME=$1 EYRWSL_PACKAGES=$PACKAGES PREPARE_STOW_KERNEL_RELEASE=${3:-$WSL_KERNEL} bash "$2/scripts/prepare-stow.sh"
}
# shellcheck disable=SC2086
deploy() { HOME=$1 stow --no-folding -R -d "$2" -t "$1" $PACKAGES; }

snapshot() {
  (cd -- "$1" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha256sum)
}

case_fresh_home() {
  local home="$TMP/fresh/home" repo="$TMP/fresh/home/Projects/eyrwsl"
  mkdir -p "$home"
  make_clone "$repo"
  prepare "$home" "$repo" >/dev/null || fail "fresh home did not succeed"
  [[ $(ls -A "$home") == Projects ]] || fail "fresh home was changed"
}

case_owned_entries() {
  local home="$TMP/owned/home" repo="$TMP/owned/home/Projects/eyrwsl" before after path
  mkdir -p "$home/.config/git"
  make_clone "$repo"
  printf 'keymaps\n' >"$repo/nvim/.config/nvim/lua/config/keymaps.lua" # untracked package file
  ln -s Projects/eyrwsl/bash/.bashrc "$home/.bashrc"
  ln -s ../Projects/eyrwsl/bash/.config/bash "$home/.config/bash"
  ln -s ../Projects/eyrwsl/nvim/.config/nvim "$home/.config/nvim"
  ln -s ../Projects/eyrwsl/yazi/.config/yazi "$home/.config/yazi"
  ln -s ../../Projects/eyrwsl/git/.config/git/config "$home/.config/git/config"
  printf '[user]\n\tname = fixture\n' >"$home/.config/git/config.local"
  ln -s /usr/share/nothing/theme "$home/.config/git/theme"
  before=$(snapshot "$repo")
  prepare "$home" "$repo" >/dev/null || fail "owned entries did not succeed"
  after=$(snapshot "$repo")
  [[ $before == "$after" ]] || fail "owned-entry cleanup changed repo content"
  for path in .config/bash .config/nvim .config/yazi; do
    [[ ! -e $home/$path && ! -L $home/$path ]] || fail "leftover folded link remains: $path"
  done
  for path in .bashrc .config/git/config; do
    [[ -L $home/$path ]] || fail "live leaf link was removed: $path"
  done
  [[ -d $home/.config/git && ! -L $home/.config/git ]] || fail "real git parent was touched"
  [[ $(<"$home/.config/git/config.local") == *fixture ]] || fail "unowned regular file was changed"
  [[ -L $home/.config/git/theme ]] || fail "unowned link was removed"
  [[ -f $repo/nvim/.config/nvim/lua/config/keymaps.lua ]] || fail "content under a folded parent was removed from the repo"
}

case_no_folding() {
  local home="$TMP/nofold/home" repo="$TMP/nofold/home/Projects/eyrwsl" path
  mkdir -p "$home/.config/git"
  make_clone "$repo"
  printf '[user]\n\tname = fixture\n' >"$home/.config/git/config.local"
  # Folded links as a folding deployment created them: relative, so Stow still
  # recognizes them as its own.
  ln -s ../Projects/eyrwsl/nvim/.config/nvim "$home/.config/nvim"
  ln -s ../Projects/eyrwsl/yazi/.config/yazi "$home/.config/yazi"
  prepare "$home" "$repo" >/dev/null || fail "leftover folds did not succeed"
  deploy "$home" "$repo" >/dev/null 2>&1 || fail "no-folding stow failed after cleanup"
  for path in .config/bash .config/git .config/nvim .config/nvim/lua/config .config/yazi; do
    [[ -d $home/$path && ! -L $home/$path ]] || fail "$path is not a real directory after no-folding stow"
  done
  [[ $(readlink -f -- "$home/.config/nvim/lua/config/options.lua") == "$repo/nvim/.config/nvim/lua/config/options.lua" ]] ||
    fail "leaf link does not resolve into the clone"
  printf 'host-local\n' >"$home/.config/yazi/package.toml"
  prepare "$home" "$repo" >/dev/null || fail "cleanup with live links failed"
  [[ -L $home/.bashrc && -L $home/.config/yazi/yazi.toml ]] || fail "cleanup removed a live leaf link"
  deploy "$home" "$repo" >/dev/null 2>&1 || fail "restow failed with host-local state present"
  [[ $(<"$home/.config/yazi/package.toml") == host-local && $(<"$home/.config/git/config.local") == *fixture ]] ||
    fail "restow changed host-local state"
  [[ ! -e $repo/yazi/.config/yazi/package.toml && ! -e $repo/git/.config/git/config.local ]] ||
    fail "host-local state reached the package source"
}

case_regular_file() {
  local home="$TMP/regular/home" repo="$TMP/regular/home/Projects/eyrwsl"
  mkdir -p "$home/.config"
  make_clone "$repo"
  printf 'skel\n' >"$home/.bashrc"
  ln -s ../Projects/eyrwsl/yazi/.config/yazi "$home/.config/yazi"
  if prepare "$home" "$repo" >/dev/null 2>&1; then fail "regular file at an owned path did not abort"; fi
  [[ $(<"$home/.bashrc") == skel ]] || fail "regular file was changed"
  [[ -L $home/.config/yazi ]] || fail "abort was not atomic: a folded link was removed first"
}

case_moved_clone() {
  local home="$TMP/moved/home" repo="$TMP/moved/home/Projects/eyrwsl" path
  mkdir -p "$home/.config/git"
  make_clone "$repo"
  ln -s Projects/old/eyrwsl/bash/.bashrc "$home/.bashrc"
  ln -s ../Projects/old/eyrwsl/yazi/.config/yazi "$home/.config/yazi"
  ln -s "$TMP/moved/elsewhere/eyrwsl/git/.config/git/config" "$home/.config/git/config"
  prepare "$home" "$repo" >/dev/null || fail "moved-clone links did not succeed"
  for path in .bashrc .config/yazi .config/git/config; do
    [[ ! -L $home/$path ]] || fail "dangling link from a moved clone remains: $path"
  done
}

case_dangling_unrelated() {
  local home="$TMP/dangling/home" repo="$TMP/dangling/home/Projects/eyrwsl"
  mkdir -p "$home/.config/git"
  make_clone "$repo"
  ln -s Projects/old/eyrwsl/bash/.bashrc "$home/.bashrc"
  ln -s /usr/share/git/config "$home/.config/git/config"
  if prepare "$home" "$repo" >/dev/null 2>&1; then fail "dangling link outside the package layout did not abort"; fi
  [[ -L $home/.config/git/config ]] || fail "dangling unrelated link was removed"
  [[ -L $home/.bashrc ]] || fail "abort was not atomic: a dangling clone link was removed first"
}

case_foreign_link() {
  local home="$TMP/foreign/home" repo="$TMP/foreign/home/Projects/eyrwsl" foreign="$TMP/foreign/user-config"
  mkdir -p "$home/.config/git"
  make_clone "$repo"
  printf 'foreign\n' >"$foreign"
  ln -s Projects/old/eyrwsl/bash/.bashrc "$home/.bashrc"
  ln -s "$foreign" "$home/.config/git/config"
  if prepare "$home" "$repo" >/dev/null 2>&1; then fail "foreign link did not abort"; fi
  [[ -L $home/.config/git/config && $(<"$foreign") == foreign ]] || fail "foreign link or its target was changed"
  [[ -L $home/.bashrc ]] || fail "abort was not atomic: a dangling clone link was removed first"
}

case_foreign_fold() {
  local home="$TMP/fold/home" repo="$TMP/fold/home/Projects/eyrwsl" other="$TMP/fold/other-yazi"
  mkdir -p "$home/.config" "$other"
  make_clone "$repo"
  printf 'other\n' >"$other/yazi.toml"
  ln -s ../Projects/eyrwsl/bash/.config/bash "$home/.config/bash"
  ln -s "$other" "$home/.config/yazi"
  if prepare "$home" "$repo" >/dev/null 2>&1; then fail "foreign directory link did not abort"; fi
  [[ -L $home/.config/yazi && $(<"$other/yazi.toml") == other ]] || fail "foreign directory link or its content was changed"
  [[ -L $home/.config/bash ]] || fail "abort was not atomic: a folded link was removed first"
}

case_special_file() {
  local home="$TMP/special/home" repo="$TMP/special/home/Projects/eyrwsl"
  mkdir -p "$home"
  make_clone "$repo"
  mkfifo "$home/.bashrc"
  if prepare "$home" "$repo" >/dev/null 2>&1; then fail "special file did not abort"; fi
  [[ -p $home/.bashrc ]] || fail "special file was removed"
}

case_directory_at_leaf() {
  local home="$TMP/dirleaf/home" repo="$TMP/dirleaf/home/Projects/eyrwsl"
  mkdir -p "$home/.bashrc"
  make_clone "$repo"
  if prepare "$home" "$repo" >/dev/null 2>&1; then fail "directory at a leaf path did not abort"; fi
  [[ -d $home/.bashrc ]] || fail "directory at a leaf path was removed"
}

case_missing_packages() {
  local home="$TMP/nopkg/home" repo="$TMP/nopkg/home/Projects/eyrwsl"
  mkdir -p "$home"
  make_clone "$repo"
  if HOME=$home EYRWSL_PACKAGES='' PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL bash "$repo/scripts/prepare-stow.sh" >/dev/null 2>&1; then
    fail "empty EYRWSL_PACKAGES did not abort"
  fi
}

case_wsl_gate() {
  local home="$TMP/gate/home" repo="$TMP/gate/home/Projects/eyrwsl" scenario kernel target out
  mkdir -p "$home/.config"
  make_clone "$repo"
  ln -s ../Projects/eyrwsl/yazi/.config/yazi "$home/.config/yazi"
  for scenario in linux wsl1 disabled-handler disabled-binfmt failed-probe; do
    kernel=$WSL_KERNEL
    printf 'enabled\n' >"$PREPARE_STOW_INTEROP_ROOT/status"
    printf 'enabled\n' >"$PREPARE_STOW_INTEROP_ROOT/WSLInterop"
    printf '#!/bin/bash\nexit 0\n' >"$TMP/interop-bin/powershell.exe"
    case $scenario in
      linux) kernel=linux-fixture ;;
      wsl1) kernel=4.4.0-19041-Microsoft ;;
      disabled-handler) printf 'disabled\n' >"$PREPARE_STOW_INTEROP_ROOT/WSLInterop" ;;
      disabled-binfmt) printf 'disabled\n' >"$PREPARE_STOW_INTEROP_ROOT/status" ;;
      failed-probe) printf '#!/bin/bash\nexit 1\n' >"$TMP/interop-bin/powershell.exe" ;;
    esac
    if prepare "$home" "$repo" "$kernel" >/dev/null 2>&1; then fail "direct preparation accepted $scenario"; fi
    for target in stow unstow restow clean wt-push; do
      if out=$(HOME=$home PREPARE_STOW_KERNEL_RELEASE=$kernel make --no-print-directory -C "$repo" -j8 "$target" 2>&1); then fail "$target accepted $scenario"; fi
      [[ $out == *WSL2* || $out == *interop* || $out == *WSLInterop* ]] || fail "wrong host-refusal reason: $out"
      [[ -L $home/.config/yazi ]] || fail "$target mutated before $scenario refusal"
    done
  done
  # A soft timeout cannot stop this probe; it eventually exits to bound the test.
  cat >"$TMP/interop-bin/powershell.exe" <<'SH'
#!/bin/bash
trap '' TERM
sleep 7
: >"${0%/*}/probe-survived"
exit 1
SH
  if out=$(HOME=$home PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL make --no-print-directory -C "$repo" clean 2>&1); then fail "nonterminating probe was accepted"; fi
  [[ $out == *'probe failed or timed out'* ]] || fail "wrong timeout refusal: $out"
  [[ ! -e $TMP/interop-bin/probe-survived ]] || fail "probe survived the termination deadline"
  [[ -L $home/.config/yazi ]] || fail "cleanup ran after a timed-out probe"
  printf '#!/bin/bash\nexit 0\n' >"$TMP/interop-bin/powershell.exe"
  printf 'enabled\n' >"$PREPARE_STOW_INTEROP_ROOT/status"
  printf 'disabled\n' >"$PREPARE_STOW_INTEROP_ROOT/WSLInterop"
  printf 'enabled\n' >"$PREPARE_STOW_INTEROP_ROOT/WSLInterop-late"
  HOME=$home PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL make --no-print-directory -C "$repo" require-host >/dev/null || fail "active WSLInterop-late was not recognized"
  rm -- "$PREPARE_STOW_INTEROP_ROOT/WSLInterop-late"
  printf 'enabled\n' >"$PREPARE_STOW_INTEROP_ROOT/WSLInterop"
  if HOME=$home PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL PREPARE_STOW_INTEROP_ROOT=/proc/sys/fs/binfmt_misc make --no-print-directory -C "$repo" clean >/dev/null 2>&1; then fail "interop fixture escaped TMPDIR"; fi
  if HOME=$home PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL PREPARE_STOW_INTEROP_ROOT='' make --no-print-directory -C "$repo" clean >/dev/null 2>&1; then fail "incomplete fixture override was accepted"; fi
  [[ -L $home/.config/yazi ]] || fail "invalid fixture overrides changed the layout"
}

case_make_guards() {
  local home="$TMP/make/home" repo="$TMP/make/eyrwsl" other="$TMP/make/deployed" bin="$TMP/make/bin" target out
  mkdir -p "$home/.config" "$bin"
  make_clone "$repo"
  make_clone "$other"
  ln -s "$other/bash/.bashrc" "$home/.bashrc"
  ln -s "$TMP/make/old/yazi/.config/yazi" "$home/.config/yazi"
  # Observe the actual Make recipes, delaying the clone guard to expose -j races.
  cat >"$bin/bash" <<'SH'
#!/bin/bash
if [[ ${1:-} == scripts/prepare-stow.sh ]]; then
  case ${2:-} in
    --require-clone) printf 'guard\n' >>"$EYR_TEST_EVENTS"; sleep 0.05 ;;
    --require-host) ;;
    *) printf 'write\n' >>"$EYR_TEST_EVENTS" ;;
  esac
fi
exec /bin/bash "$@"
SH
  chmod +x "$bin/bash"
  for target in stow unstow restow clean wt-push 'clean restow' 'restow clean'; do
    : >"$TMP/make/events"
    local -a goals=()
    read -r -a goals <<<"$target"
    if out=$(HOME=$home PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL PATH="$bin:$PATH" EYR_TEST_EVENTS="$TMP/make/events" make --no-print-directory -C "$repo" -j8 "${goals[@]}" 2>&1); then
      fail "Make accepted a wrong deployed clone: $target"
    fi
    [[ $out == *'another clone'* ]] || fail "Make failed for the wrong reason ($target): $out"
    [[ $(<"$TMP/make/events") != *write* ]] || fail "cleanup started before the clone guard refused: $target"
    [[ -L $home/.config/yazi && $(readlink -- "$home/.bashrc") == "$other/bash/.bashrc" ]] || fail "Make changed links before refusal: $target"
  done
  rm -- "$home/.bashrc"
  ln -s "$repo/bash/.bashrc" "$home/.bashrc"
  : >"$TMP/make/events"
  HOME=$home PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL PATH="$bin:$PATH" EYR_TEST_EVENTS="$TMP/make/events" make --no-print-directory -C "$repo" -j8 clean >/dev/null || fail "guarded Make clean failed in the deployed fixture"
  [[ $(<"$TMP/make/events") == $'guard\nwrite' && ! -L $home/.config/yazi ]] || fail "guard and cleanup were not ordered"
  ln -s "$TMP/make/old/yazi/.config/yazi" "$home/.config/yazi"
  if HOME=$home PREPARE_STOW_KERNEL_RELEASE=linux-fixture make --no-print-directory -C "$repo" -j8 clean restow >/dev/null 2>&1; then
    fail "Make accepted a non-WSL host"
  fi
  [[ -L $home/.config/yazi ]] || fail "host refusal happened after cleanup"
}

case_fresh_home
case_owned_entries
case_no_folding
case_regular_file
case_moved_clone
case_dangling_unrelated
case_foreign_link
case_foreign_fold
case_special_file
case_directory_at_leaf
case_missing_packages
case_wsl_gate
case_make_guards
printf 'ok:   prepare-stow preserves regular files and foreign entries; actual Make deployment targets guard before cleanup, including -j\n'
