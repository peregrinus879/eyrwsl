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

# Deploy the old package inventory using real Stow, then simulate pull (or
# pending worktree deletions) before running the new preparation inventory.
make_retired_deployment() {
  local home=$1 repo=$2 layout=$3 state=$4
  make_clone "$repo"
  mkdir -p "$repo/bash/.config/bash/functions" "$repo/tmux/.config/tmux"
  printf '# old Herdr helpers\n' >"$repo/bash/.config/bash/functions/herdr"
  printf '# old tdw\n' >"$repo/bash/.config/bash/functions/tdw"
  printf '# old tmux helpers\n' >"$repo/bash/.config/bash/functions/tmux"
  printf '# old config\n' >"$repo/tmux/.config/tmux/tmux.conf"
  git -C "$repo" add bash tmux
  deploy "$home" "$repo"
  [[ -L $home/.config/bash/functions/herdr &&
    $(readlink -f -- "$home/.config/bash/functions/herdr") == "$repo/bash/.config/bash/functions/herdr" ]] ||
    fail 'old Stow did not deploy the copied Herdr helpers'
  if [[ $layout != leaf ]]; then
    stow -d "$repo" -t "$home" tmux
    [[ -L $home/.config/tmux ]] || fail 'old Stow did not fold tmux'
  else
    stow --no-folding -d "$repo" -t "$home" tmux
  fi
  if [[ $state != pending ]]; then
    git -C "$repo" rm -q --cached -- bash/.config/bash/functions/herdr bash/.config/bash/functions/tdw bash/.config/bash/functions/tmux tmux/.config/tmux/tmux.conf
  fi
  rm -- "$repo/bash/.config/bash/functions/herdr" "$repo/bash/.config/bash/functions/tdw" "$repo/bash/.config/bash/functions/tmux" "$repo/tmux/.config/tmux/tmux.conf"
  rmdir "$repo/tmux/.config/tmux" "$repo/tmux/.config" "$repo/tmux"
}

case_retired_links() {
  local layout state home repo path before active_packages=$PACKAGES PACKAGES=$PACKAGES
  for layout in leaf fold dangling-fold; do
    for state in pulled pending unlisted; do
      home="$TMP/retired-$layout-$state/home"; repo="$home/Projects/eyrwsl"
      mkdir -p "$home"
      PACKAGES=$active_packages
      make_retired_deployment "$home" "$repo" "$layout" "$state"
      # Exact retirement must not depend on bash remaining in PACKAGES either.
      [[ $state != unlisted ]] || PACKAGES='git nvim yazi'
      printf 'retained helper state\n' >"$home/.config/bash/functions/user-state"
      # State under real home directories and source content hidden by a fold
      # must survive. The latter also proves queued folds are never traversed.
      if [[ $layout == leaf ]]; then
        printf 'user state\n' >"$home/.config/tmux/state"
      elif [[ $layout == fold ]]; then
        mkdir -p "$repo/tmux/.config/tmux"
        printf 'source state\n' >"$repo/tmux/.config/tmux/state"
        ln -s "$TMP/foreign-config" "$repo/tmux/.config/tmux/user-link"
      fi
      before=$(snapshot "$repo")
      if HOME=$home EYRWSL_PACKAGES=$PACKAGES bash "$repo/scripts/prepare-stow.sh" --check-retired >/dev/null 2>&1; then
        fail 'read-only retirement check accepted deployed retired links'
      fi
      [[ -L $home/.config/bash/functions/herdr && -L $home/.config/bash/functions/tdw ]] || fail 'read-only check mutated a retired link'
      if prepare "$home" "$repo" linux-fixture >/dev/null 2>&1; then fail 'retirement accepted the wrong host'; fi
      [[ -L $home/.config/bash/functions/herdr && -L $home/.config/bash/functions/tdw ]] || fail 'wrong-host retirement mutated a link'
      HOME=$home EYRWSL_PACKAGES=$PACKAGES bash "$repo/scripts/prepare-stow.sh" --require-clone >/dev/null || fail 'retired links failed the clone guard'
      [[ -L $home/.config/bash/functions/herdr ]] || fail 'clone guard mutated the retired Herdr link'
      prepare "$home" "$repo" >/dev/null || fail "retirement failed: $layout $state"
      [[ $(snapshot "$repo") == "$before" ]] || fail 'retirement changed source content'
      for path in .config/bash/functions/herdr .config/bash/functions/tdw .config/bash/functions/tmux .config/tmux/tmux.conf; do
        [[ ! -e $home/$path && ! -L $home/$path ]] || fail "retired endpoint remains: $path"
      done
      [[ -d $home/.config/bash/functions && ! -L $home/.config/bash/functions &&
        $(<"$home/.config/bash/functions/user-state") == 'retained helper state' ]] || fail 'retirement changed unrelated helper state'
      if [[ $layout == leaf ]]; then
        [[ -d $home/.config/tmux && $(<"$home/.config/tmux/state") == 'user state' ]] || fail 'real tmux directory/state was removed'
      else
        [[ ! -L $home/.config/tmux ]] || fail 'retired fold remains'
        [[ $layout != fold || -L $repo/tmux/.config/tmux/user-link ]] || fail 'fold contents were traversed'
      fi
      prepare "$home" "$repo" >/dev/null || fail 'retirement is not idempotent'
      HOME=$home EYRWSL_PACKAGES=$PACKAGES bash "$repo/scripts/prepare-stow.sh" --check-retired >/dev/null || fail 'retirement verification failed after cleanup'
      deploy "$home" "$repo" >/dev/null 2>&1 || fail 'new package restow failed after retirement'
    done
  done
}

case_retired_refusals() {
  local scenario home repo target path before out
  for scenario in foreign lookalike newline sibling-source regular fifo directory foreign-fold lookalike-fold newline-fold regular-parent fifo-parent foreign-parent redirected-source; do
    home="$TMP/retired-refuse-$scenario/home"; repo="$home/Projects/eyrwsl"
    mkdir -p "$home"
    make_retired_deployment "$home" "$repo" leaf pulled
    target="$home/.config/tmux/tmux.conf"
    rm -- "$target"
    case $scenario in
      foreign) ln -s "$TMP/other/tmux/.config/tmux/tmux.conf" "$target" ;;
      lookalike) ln -s "$repo-lookalike/tmux/.config/tmux/tmux.conf" "$target" ;;
      newline) ln -s "$repo/tmux/.config/tmux/tmux.conf"$'\n' "$target" ;;
      sibling-source) ln -s "$repo/bash/.config/bash/envs" "$target" ;;
      regular) printf 'keep\n' >"$target" ;;
      fifo) mkfifo "$target" ;;
      directory) mkdir "$target" ;;
      foreign-fold|lookalike-fold|newline-fold|regular-parent|fifo-parent)
        rmdir "$home/.config/tmux"
        case $scenario in
          foreign-fold) mkdir -p "$TMP/foreign-fold"; ln -s "$TMP/foreign-fold" "$home/.config/tmux" ;;
          lookalike-fold) ln -s "$repo-lookalike/tmux/.config/tmux" "$home/.config/tmux" ;;
          newline-fold) ln -s "$repo/tmux/.config/tmux"$'\n' "$home/.config/tmux" ;;
          regular-parent) printf 'keep\n' >"$home/.config/tmux" ;;
          fifo-parent) mkfifo "$home/.config/tmux" ;;
        esac ;;
      foreign-parent)
        rm -- "$home/.config/bash/functions/herdr" "$home/.config/bash/functions/tdw" "$home/.config/bash/functions/tmux"
        rmdir "$home/.config/bash/functions"
        ln -s "$TMP/other/bash/.config/bash/functions" "$home/.config/bash/functions" ;;
      redirected-source)
        mkdir -p "$repo/tmux/.config" "$TMP/redirected"
        ln -s "$TMP/redirected" "$repo/tmux/.config/tmux"
        ln -s "$repo/tmux/.config/tmux/tmux.conf" "$target" ;;
    esac
    # An independently removable active fold must survive every late refusal.
    rm -- "$home/.config/yazi/yazi.toml"
    rmdir "$home/.config/yazi"
    ln -s "$repo/yazi/.config/yazi" "$home/.config/yazi"
    before=$(find "$home/.config" -printf '%p %y %l\n' | sort)
    if prepare "$home" "$repo" >/dev/null 2>&1; then fail "retirement accepted $scenario"; fi
    [[ $(find "$home/.config" -printf '%p %y %l\n' | sort) == "$before" ]] || fail "retirement mutated before $scenario refusal"
    # Exercise real Make guard ordering for a retired-only wrong-clone link.
    if [[ $scenario == foreign ]]; then
      for path in clean stow restow unstow wt-push; do
        if out=$(HOME=$home PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL make --no-print-directory -C "$repo" "$path" 2>&1); then fail "$path accepted foreign retirement"; fi
        [[ $out == *'another clone'* ]] || fail "$path missed retired clone guard: $out"
      done
    fi
  done
}

case_retired_herdr_refusals() {
  local scenario home repo target source='bash/.config/bash/functions/herdr' before flag out
  for scenario in foreign live-foreign lookalike newline sibling-source regular fifo directory foreign-parent redirected-source; do
    home="$TMP/herdr-refuse-$scenario/home"; repo="$home/Projects/eyrwsl"
    mkdir -p "$home"
    make_retired_deployment "$home" "$repo" leaf pulled
    target="$home/.config/bash/functions/herdr"
    rm -- "$target"
    case $scenario in
      foreign) ln -s "$TMP/other/$source" "$target" ;;
      live-foreign)
        printf 'foreign helper\n' >"$TMP/foreign-herdr"
        ln -s "$TMP/foreign-herdr" "$target" ;;
      lookalike) ln -s "$repo-lookalike/$source" "$target" ;;
      newline) ln -s "$repo/$source"$'\n' "$target" ;;
      sibling-source) ln -s "$repo/bash/.config/bash/envs" "$target" ;;
      regular) printf 'keep helper\n' >"$target" ;;
      fifo) mkfifo "$target" ;;
      directory) mkdir "$target" ;;
      foreign-parent)
        rm -- "$home/.config/bash/functions/tdw" "$home/.config/bash/functions/tmux"
        rmdir "$home/.config/bash/functions"
        ln -s "$TMP/other/bash/.config/bash/functions" "$home/.config/bash/functions" ;;
      redirected-source)
        # Isolate this endpoint; associative-map iteration need not report it first.
        rm -- "$home/.config/bash/functions/tdw" "$home/.config/bash/functions/tmux"
        mv -- "$repo/bash/.config/bash/functions" "$TMP/redirected-herdr"
        ln -s "$TMP/redirected-herdr" "$repo/bash/.config/bash/functions"
        ln -s "$repo/$source" "$target" ;;
    esac
    rm -- "$home/.config/yazi/yazi.toml"
    rmdir "$home/.config/yazi"
    ln -s "$repo/yazi/.config/yazi" "$home/.config/yazi"
    before=$(find "$home/.config" -printf '%p %y %l\0' | sort -z | sha256sum)
    for flag in '' --require-clone --check-retired; do
      if out=$(HOME=$home EYRWSL_PACKAGES=$PACKAGES PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL bash "$repo/scripts/prepare-stow.sh" ${flag:+"$flag"} 2>&1); then
        fail "$flag accepted retired Herdr $scenario"
      fi
      [[ $out == *"$target "* || $out == *"${target%/*} "* ]] || fail "wrong Herdr refusal: $out"
      [[ $(find "$home/.config" -printf '%p %y %l\0' | sort -z | sha256sum) == "$before" ]] || fail "Herdr $scenario refusal changed deployed entries"
      [[ $scenario != regular || $(<"$target") == 'keep helper' ]] || fail 'Herdr refusal changed a regular helper'
      [[ $scenario != live-foreign || $(<"$TMP/foreign-herdr") == 'foreign helper' ]] || fail 'Herdr refusal changed foreign content'
    done
    if [[ $scenario == foreign ]]; then
      for flag in clean stow restow unstow wt-push; do
        if out=$(HOME=$home PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL make --no-print-directory -C "$repo" "$flag" 2>&1); then
          fail "$flag accepted a foreign retired Herdr link"
        fi
        [[ $out == *"$target is not the exact retired link"* ]] || fail "wrong Herdr Make guard refusal: $out"
        [[ $(find "$home/.config" -printf '%p %y %l\0' | sort -z | sha256sum) == "$before" ]] || fail 'Herdr Make refusal changed deployed entries'
      done
    fi
  done
}

case_retired_source_present() {
  local source kind layout home repo path before out flag
  for source in bash/.config/bash/functions/herdr bash/.config/bash/functions/tdw bash/.config/bash/functions/tmux tmux/.config/tmux/tmux.conf; do
    for kind in regular dangling-symlink live-symlink fifo; do
      for layout in leaf fold; do
        home="$TMP/source-present-${source##*/}-$kind-$layout/home"; repo="$home/Projects/eyrwsl"
        mkdir -p "$home"
        make_retired_deployment "$home" "$repo" "$layout" pulled
        path="$repo/$source"
        mkdir -p "${path%/*}"
        case $kind in
          regular) printf 'restored source\n' >"$path" ;;
          dangling-symlink) ln -s "$TMP/absent"$'\n' "$path" ;;
          live-symlink) ln -s "$repo/bash/.config/bash/envs" "$path" ;;
          fifo) mkfifo "$path" ;;
        esac
        before=$(find "$home/.config" -printf '%p %y %l\n' | sort)
        for flag in '' --require-clone --check-retired; do
          if out=$(HOME=$home EYRWSL_PACKAGES=$PACKAGES PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL bash "$repo/scripts/prepare-stow.sh" ${flag:+"$flag"} 2>&1); then
            fail "$flag accepted restored retired $source ($kind, $layout)"
          fi
          [[ $out == *'retired source still exists:'* ]] || fail "wrong source refusal: $out"
          [[ $(find "$home/.config" -printf '%p %y %l\n' | sort) == "$before" ]] || fail 'source refusal unlinked deployed entries'
          [[ -e $path || -L $path ]] || fail 'source refusal removed source content'
        done
      done
    done
  done
}

case_retired_parent_metadata() {
  local home="$TMP/parent-metadata/home" repo="$TMP/parent-metadata/repo" dir mode out flag unsafe status observed_mode
  mkdir -p "$home"
  make_retired_deployment "$home" "$repo" leaf pulled
  rm -- "$home/.config/nvim/init.lua" "$home/.config/nvim/lua/config/options.lua"
  rmdir "$home/.config/nvim/lua/config" "$home/.config/nvim/lua" "$home/.config/nvim"
  ln -s "$repo/nvim/.config/nvim" "$home/.config/nvim"
  # Use actual permissions; model a different owner through stat rather than
  # requiring chown privileges or adding a production fixture override.
  mkdir "$TMP/metadata-bin"
  cat >"$TMP/metadata-bin/stat" <<'SH'
#!/bin/bash
if [[ ${*: -1} == "$EYR_TEST_UNSAFE_DIR" ]]; then
  printf '%s 755\n' "$((EUID + 1))"
else
  exec "$EYR_TEST_REAL_STAT" "$@"
fi
SH
  chmod +x "$TMP/metadata-bin/stat"
  for dir in "$home" "$home/.config" "$home/.config/bash" "$home/.config/bash/functions" "$home/.config/tmux"; do
    for mode in 775 757 500 300 600 owner; do
      if [[ $mode != owner ]]; then chmod "$mode" "$dir"; fi
      for flag in '' --require-clone --check-retired; do
        status=0
        if [[ $mode == owner ]]; then
          out=$(HOME=$home EYRWSL_PACKAGES=$PACKAGES PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL EYR_TEST_UNSAFE_DIR=$dir EYR_TEST_REAL_STAT="$(command -v stat)" PATH="$TMP/metadata-bin:$PATH" bash "$repo/scripts/prepare-stow.sh" ${flag:+"$flag"} 2>&1) || status=$?
        else
          out=$(HOME=$home EYRWSL_PACKAGES=$PACKAGES PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL bash "$repo/scripts/prepare-stow.sh" ${flag:+"$flag"} 2>&1) || status=$?
        fi
        # Restore access before asserting or allowing EXIT cleanup to run.
        observed_mode=$(stat -c %a -- "$dir")
        chmod 755 "$dir"
        ((status != 0)) || fail "$flag accepted retirement parent $dir ($mode)"
        [[ $out == *'unsafe retirement directory'* ]] || fail "wrong metadata refusal: $out"
        [[ $mode == owner || $observed_mode == "$mode" ]] || fail 'metadata refusal repaired permissions'
        [[ -L $home/.config/nvim ]] || fail 'metadata refusal unlinked the earlier queued fold'
        for unsafe in .config/bash/functions/herdr .config/bash/functions/tdw .config/bash/functions/tmux .config/tmux/tmux.conf; do
          [[ -L $home/$unsafe ]] || fail "metadata refusal unlinked $unsafe"
        done
        if [[ $mode != owner ]]; then chmod "$mode" "$dir"; fi
      done
      chmod 755 "$dir"
    done
  done
  # The boundary is retirement-specific, not a new active-parent policy.
  chmod 777 "$home/.config/yazi"
  prepare "$home" "$repo" >/dev/null || fail 'retirement metadata checks broadened to unrelated active parents'
  [[ -L $home/.config/yazi/yazi.toml ]] || fail 'unrelated active leaf was removed'
  ln -s "$home" "$TMP/parent-metadata/home-alias"
  if out=$(HOME="$TMP/parent-metadata/home-alias/" EYRWSL_PACKAGES=$PACKAGES bash "$repo/scripts/prepare-stow.sh" --check-retired 2>&1); then
    fail 'retirement accepted a symlinked HOME'
  fi
  [[ $out == *'HOME must use a real'* ]] || fail "wrong HOME alias refusal: $out"
}

case_config_ancestor() {
  local scenario base home repo target before flag out
  for scenario in foreign foreign-newline clone-newline source-redirect source-newline owned-bash owned-tmux; do
    base="$TMP/config-ancestor-$scenario"; home="$base/home"; repo="$base/repo"
    mkdir -p "$home"
    make_clone "$repo"
    mkdir -p "$repo/bash/.local/bin"
    printf 'retained\n' >"$repo/bash/.local/bin/fixture"
    ln -s "$base/old/bash/.bashrc" "$home/.bashrc"
    ln -s "$repo/bash/.local" "$home/.local"
    case $scenario in
      foreign) target="$base/other-clone/bash/.config" ;;
      foreign-newline) target="$base/other-clone/bash/.config"$'\n' ;;
      clone-newline) target="$repo/bash/.config"$'\n' ;;
      source-redirect|source-newline)
        target="$base/retained-config"
        [[ $scenario != source-newline ]] || target+=$'\n'
        mv -- "$repo/bash/.config" "$target"
        ln -s "$target" "$repo/bash/.config"
        target="$repo/bash/.config" ;;
      owned-bash) target='../repo/bash/.config' ;;
      owned-tmux)
        mkdir -p "$repo/tmux/.config"
        printf 'retained\n' >"$repo/tmux/.config/user-state"
        target="$repo/tmux/.config" ;;
    esac
    ln -s "$target" "$home/.config"
    if [[ $scenario == owned-* ]]; then
      prepare "$home" "$repo" >/dev/null || fail 'exact owned .config fold was refused'
      [[ ! -L $home/.config && -f $repo/bash/.local/bin/fixture ]] || fail 'owned .config retirement changed source data'
      [[ $scenario != owned-tmux || -f $repo/tmux/.config/user-state ]] || fail 'tmux ancestor retirement removed state'
      continue
    fi
    before=$(find "$home" -printf '%p %y %l\0' | sort -z | sha256sum)
    for flag in '' --require-clone --check-retired; do
      if out=$(HOME=$home EYRWSL_PACKAGES=$PACKAGES PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL bash "$repo/scripts/prepare-stow.sh" ${flag:+"$flag"} 2>&1); then
        fail "$flag accepted unsafe .config ancestor: $scenario"
      fi
      [[ $out == *'not an exact retirement ancestor fold'* ]] || fail "wrong .config refusal: $out"
      [[ $(find "$home" -printf '%p %y %l\0' | sort -z | sha256sum) == "$before" ]] || fail '.config refusal changed other pending removals'
    done
  done
}

case_root_identities() {
  local base="$TMP/root-identities" home repo other_home other_repo scenario selected_home script out flag neighbor
  home="$base/home"; other_home="$home"$'\n'
  repo="$base/repo"; other_repo="$repo"$'\n'
  mkdir -p "$home/.config/bash/functions" "$other_home/.config/bash/functions"
  make_clone "$repo"
  make_clone "$other_repo"
  for neighbor in "$home" "$other_home"; do
    ln -s "$repo/bash/.config/bash/functions/herdr" "$neighbor/.config/bash/functions/herdr"
    ln -s "$repo/bash/.config/bash/functions/tdw" "$neighbor/.config/bash/functions/tdw"
    ln -s "$base/old/bash/.bashrc" "$neighbor/.bashrc"
  done
  ln -s "$other_home" "$base/home-alias"
  ln -s "$other_repo" "$base/repo-alias"
  mkdir "$repo/scripts"$'\n'
  cp -- "$ROOT/scripts/prepare-stow.sh" "$repo/scripts"$'\n/prepare-stow.sh'
  # A trimmed dirname would follow this neighboring directory to another root.
  mv -- "$repo/scripts" "$repo/saved-scripts"
  ln -s "$other_repo/scripts" "$repo/scripts"
  for scenario in home clone both home-alias clone-alias relative-clone dirname; do
    selected_home=$home; script="$repo/saved-scripts/prepare-stow.sh"
    case $scenario in
      home) selected_home=$other_home ;;
      clone) script="$other_repo/scripts/prepare-stow.sh" ;;
      both) selected_home=$other_home; script="$other_repo/scripts/prepare-stow.sh" ;;
      home-alias) selected_home="$base/home-alias" ;;
      clone-alias) script="$base/repo-alias/scripts/prepare-stow.sh" ;;
      dirname) script="$repo/scripts"$'\n/prepare-stow.sh' ;;
    esac
    for flag in '' --require-clone --check-retired --check-home; do
      if [[ $scenario == relative-clone ]]; then
        if out=$(builtin cd -- "$other_repo" && HOME=$home EYRWSL_PACKAGES=$PACKAGES PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL bash scripts/prepare-stow.sh ${flag:+"$flag"} 2>&1); then
          fail 'relative invocation accepted a newline canonical clone root'
        fi
      elif out=$(HOME=$selected_home EYRWSL_PACKAGES=$PACKAGES PREPARE_STOW_KERNEL_RELEASE=$WSL_KERNEL bash "$script" ${flag:+"$flag"} 2>&1); then
        fail "$flag accepted root lookalike: $scenario"
      fi
      [[ $out == *'control characters'* ]] || fail "wrong root-identity refusal: $out"
      for neighbor in "$home" "$other_home"; do
        [[ -L $neighbor/.config/bash/functions/herdr && -L $neighbor/.config/bash/functions/tdw && -L $neighbor/.bashrc ]] || fail 'root refusal changed a neighboring HOME'
      done
    done
  done
  rm -- "$repo/scripts"
  mv -- "$repo/saved-scripts" "$repo/scripts"
  mkdir "$base/temp" "$base/temp"$'\n' "$base/interop"$'\n'
  ln -s "$base/temp"$'\n' "$base/temp-alias"
  for scenario in temporary interop; do
    if [[ $scenario == temporary ]]; then
      if out=$(TMPDIR="$base/temp-alias" prepare "$home" "$repo" 2>&1); then fail 'newline canonical temporary root was accepted'; fi
    else
      if out=$(PREPARE_STOW_INTEROP_ROOT="$base/interop"$'\n' prepare "$home" "$repo" 2>&1); then fail 'newline interop root was accepted'; fi
    fi
    [[ $out == *'control characters'* ]] || fail "wrong fixture-root refusal: $out"
    [[ -L $home/.config/bash/functions/herdr && -L $home/.config/bash/functions/tdw && -L $home/.bashrc ]] || fail 'fixture-root refusal removed links'
  done
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
case_retired_links
case_retired_refusals
case_retired_herdr_refusals
case_retired_source_present
case_retired_parent_metadata
case_config_ancestor
case_root_identities
printf 'ok:   prepare-stow preserves regular files and foreign entries; actual Make deployment targets guard before cleanup, including -j\n'
