#!/usr/bin/env bash
# Guarded stow preparation for EyrWSL (make clean).
#
# Stow runs with --no-folding, so live deployments are real parent directories
# holding leaf links that Stow itself manages. This script removes only what
# Stow cannot reconcile and never deletes user data. Owned paths are derived
# from the Git-visible package files (tracked plus untracked, minus ignored)
# plus exact retired mappings, retained independently of Git and PACKAGES:
# each file maps to its stow target under $HOME, and every directory between
# $HOME and that target is a managed parent. Every owned path is classified
# before anything is removed, so an unrecognized entry aborts the run untouched:
#   - a managed parent that is a symlink resolving into this repo is removed:
#     a folded directory link left by a folding deployment
#   - a leaf link that resolves into this repo is left alone: Stow owns it
#     except an exact retired link into this clone, which is removed
#   - a dangling active-package link whose text names a package path this
#     repo has (a moved or deleted clone) is removed; retired endpoints and
#     all their ancestor folds require an exact mapping into this clone
#   - an entry beneath a folded parent queued for removal is skipped: it is
#     repo working-tree content and disappears with the fold
#   - a regular file at an owned path (a fresh user's /etc/skel .bashrc, say)
#     aborts: compare and move or merge it, then rerun
#   - anything else (a symlink that resolves elsewhere, a directory or special
#     file at a leaf path) aborts
# EYRWSL_PACKAGES carries the package list; the Makefile owns it. The
# WSL2/interop gate accepts paired PREPARE_STOW_KERNEL_RELEASE and
# PREPARE_STOW_INTEROP_ROOT fixtures only when HOME, this clone, and the fake
# binfmt root are below TMPDIR, never the login home. Windows commands must
# still resolve; the no-profile PowerShell probe is bounded and read-only.
# --require-host and --require-clone are read-only guards used by every
# host-writing Make target. --check-retired is a host-independent, read-only
# retired-endpoint check for verify; it does not require the deleted sources.
# --check-home validates only the original HOME spelling, without host probes
# or endpoint scans. Root paths with control characters are unsupported;
# NUL-delimited canonicalization must not turn them into another root.
# Exact retired source entries must be absent; their containing directories
# may retain unrelated state. HOME and real retired-path ancestors must be
# caller-owned, readable/writable/searchable and not group/world-writable.
# This metadata boundary does not extend to unrelated active-package parents.
set -euo pipefail

abort() {
  printf 'prepare-stow: %s\n' "$1" >&2
  exit 1
}

for root_input in "${BASH_SOURCE[0]}" "${HOME:-}"; do
  [[ ! $root_input =~ [[:cntrl:]] ]] || abort 'control characters in root/HOME paths are unsupported'
done
IFS= read -r -d '' script_dir < <(dirname -z -- "${BASH_SOURCE[0]}") || abort 'cannot resolve the script directory'
IFS= read -r -d '' repo < <(realpath -ez -- "$script_dir/..") || abort 'cannot resolve the repository root'
[[ -n ${HOME:-} && $HOME != / && -d $HOME ]] || abort 'HOME must name an existing non-root directory'
IFS= read -r -d '' home_path < <(realpath -msz -- "$HOME") || abort 'cannot resolve the HOME pathname'
IFS= read -r -d '' HOME < <(realpath -ez -- "$HOME") || abort 'cannot resolve HOME'
for root_path in "$repo" "$home_path" "$HOME"; do
  [[ ! $root_path =~ [[:cntrl:]] ]] || abort 'control characters in canonical root/HOME paths are unsupported'
done
[[ $HOME != / ]] || abort 'HOME must name an existing non-root directory'
[[ $# -le 1 && ( ${1:-} == '' || ${1:-} == --require-host || ${1:-} == --require-clone || ${1:-} == --check-retired || ${1:-} == --check-home ) ]] || abort "unsupported arguments: $*"
if [[ ${1:-} == '' || ${1:-} == --require-host ]]; then
  interop_root=/proc/sys/fs/binfmt_misc
  if [[ -v PREPARE_STOW_KERNEL_RELEASE || -v PREPARE_STOW_INTEROP_ROOT ]]; then
    [[ -n ${PREPARE_STOW_KERNEL_RELEASE:-} && -n ${PREPARE_STOW_INTEROP_ROOT:-} ]] ||
      abort 'fixture host overrides require both PREPARE_STOW_KERNEL_RELEASE and PREPARE_STOW_INTEROP_ROOT'
    for root_input in "${TMPDIR:-/tmp}" "$PREPARE_STOW_INTEROP_ROOT"; do
      [[ ! $root_input =~ [[:cntrl:]] ]] || abort 'control characters in fixture root paths are unsupported'
    done
    login_home=$(getent passwd "$(id -un)" | cut -d: -f6)
    [[ -n $login_home ]] || abort 'cannot identify the login home'
    IFS= read -r -d '' login_home < <(realpath -mz -- "$login_home") || abort 'cannot resolve the login home'
    IFS= read -r -d '' temp_root < <(realpath -ez -- "${TMPDIR:-/tmp}") || abort 'cannot resolve the fixture temporary root'
    IFS= read -r -d '' interop_root < <(realpath -ez -- "$PREPARE_STOW_INTEROP_ROOT") || abort 'cannot resolve the fixture interop root'
    for root_path in "$login_home" "$temp_root" "$interop_root"; do
      [[ ! $root_path =~ [[:cntrl:]] ]] || abort 'control characters in canonical fixture root paths are unsupported'
    done
    [[ ( $temp_root == /tmp || $temp_root == /tmp/* || $temp_root == /var/tmp || $temp_root == /var/tmp/* ) &&
      $HOME != "$login_home" && $HOME == "$temp_root"/* && $repo == "$temp_root"/* &&
      -d $PREPARE_STOW_INTEROP_ROOT && ! -L $PREPARE_STOW_INTEROP_ROOT &&
      $interop_root == "$temp_root"/* ]] ||
      abort 'fixture host overrides require a temporary clone, non-live HOME, and interop root under TMPDIR'
    kernel=$PREPARE_STOW_KERNEL_RELEASE
  else
    kernel=$(uname -r)
  fi
  [[ ${kernel,,} == *microsoft* && ${kernel,,} == *wsl2* ]] || abort 'WSL2 is required for deployment preparation'
  state=''
  if [[ -f $interop_root/status && ! -L $interop_root/status ]]; then
    IFS= read -r state <"$interop_root/status" || state=''
  fi
  [[ $state == enabled ]] || abort 'Windows interoperability requires enabled binfmt_misc'
  interop_enabled=0
  for entry in "$interop_root/WSLInterop" "$interop_root/WSLInterop-late"; do
    [[ -f $entry && ! -L $entry ]] || continue
    state=''
    IFS= read -r state <"$entry" || continue
    [[ $state != enabled ]] || interop_enabled=1
  done
  ((interop_enabled)) || abort 'an enabled WSLInterop or WSLInterop-late handler is required'
  for tool in clip.exe powershell.exe timeout; do
    command -v "$tool" >/dev/null || abort "Windows interoperability requires $tool"
  done
  timeout --signal=KILL 5s powershell.exe -NoProfile -NonInteractive -Command 'exit 0' >/dev/null 2>&1 ||
    abort 'Windows interoperability probe failed or timed out'
fi
[[ ${1:-} != --require-host ]] || exit 0
[[ $home_path == "$HOME" ]] || abort 'HOME must use a real, non-symlinked path for retirement'
[[ ${1:-} != --check-home ]] || exit 0
[[ -n ${EYRWSL_PACKAGES:-} ]] || abort 'EYRWSL_PACKAGES is required'
read -r -a packages <<<"$EYRWSL_PACKAGES"
((${#packages[@]})) || abort 'package list is empty'
command -v git >/dev/null || abort 'git is required'

resolves_into_repo() {
  local resolved
  IFS= read -r -d '' resolved < <(readlink -fz -- "$1") || return 1
  [[ $resolved == "$repo"/* ]]
}

# Link text that names a package entry this repo really has: the package name
# followed by a top-level entry of that package, whatever clone path precedes
# it. Only dangling links are ever judged by their text.
managed_link_text() {
  local text=$1 package tail
  for package in "${packages[@]}"; do
    [[ $text == *"/$package/"* ]] || continue
    tail=${text#*"/$package/"}
    [[ -n $tail && -e "$repo/$package/${tail%%/*}" ]] && return 0
  done
  return 1
}

declare -a remove_folds=() remove_links=()

# Only these former endpoints are retired. Do not infer ownership from a
# package-shaped suffix in another clone, or follow a redirected source parent.
declare -A retired=(
  ["$HOME/.config/bash/functions/herdr"]='bash/.config/bash/functions/herdr'
  ["$HOME/.config/bash/functions/tdw"]='bash/.config/bash/functions/tdw'
  ["$HOME/.config/bash/functions/tmux"]='bash/.config/bash/functions/tmux'
  ["$HOME/.config/tmux/tmux.conf"]='tmux/.config/tmux/tmux.conf'
)
retired_fold="$HOME/.config/tmux"
declare -A retired_parents=(
  ["$HOME/.config/bash"]='bash/.config/bash'
  ["$HOME/.config/bash/functions"]='bash/.config/bash/functions'
  ["$retired_fold"]='tmux/.config/tmux'
)
for source in "${retired[@]}"; do
  [[ ! -e $repo/$source && ! -L $repo/$source ]] ||
    abort "retired source still exists: $repo/$source; resolve it before retirement or deployment"
done

exact_retired_link() {
  local path=$1 source=$2 text lexical resolved
  IFS= read -r -d '' text < <(readlink -z -- "$path") || return 1
  [[ $text == /* ]] || text="${path%/*}/$text"
  IFS= read -r -d '' lexical < <(realpath -zms -- "$text") || return 1
  [[ $lexical == "$repo/$source" ]] || return 1
  IFS= read -r -d '' resolved < <(realpath -zm -- "$text") || return 1
  [[ $resolved == "$repo/$source" ]]
}

# A dangling link is judged by its text alone; it aborts unless the text names
# a package path this repo has.
queue_dangling_link() {
  local path=$1 text
  text=$(readlink -- "$path")
  managed_link_text "$text" ||
    abort "$path is a dangling symlink to $text, which names no package path of this repo; refusing to remove it"
  remove_links+=("$path")
}

under_queued_fold() {
  local path=$1 fold
  for fold in "${remove_folds[@]}"; do
    [[ $path == "$fold"/* ]] && return 0
  done
  return 1
}

# Owned leaves and their parents, from the Git-visible package files.
declare -a leaves=() parents=("$HOME") sources=()
if [[ ${1:-} != --check-retired ]]; then
  mapfile -d '' -t sources < <(git -C "$repo" ls-files -z --cached --others --exclude-standard -- "${packages[@]}")
  scan=$!; wait "$scan" || abort 'cannot enumerate package files'
  ((${#sources[@]})) || abort 'no Git-visible package files found'
fi
for source in "${sources[@]}"; do
  rel=${source#*/}
  [[ ! -v retired["$HOME/$rel"] ]] || continue
  leaves+=("$HOME/$rel")
done
leaves+=("${!retired[@]}")
for leaf in "${leaves[@]}"; do
  rel=${leaf#"$HOME/"}
  dir=$rel
  while [[ $dir == */* ]]; do
    dir=${dir%/*}
    parents+=("$HOME/$dir")
  done
done
if ((${#parents[@]})); then
  mapfile -d '' -t parents < <(printf '%s\0' "${parents[@]}" | sort -z -u)
fi

# Parents shallowest first, so a fold is queued before anything beneath it is
# looked at; entries under a queued fold are repo content and are skipped.
for dir in "${parents[@]}"; do
  under_queued_fold "$dir" && continue
  if [[ -L $dir ]]; then
    if [[ $dir == "$HOME/.config" ]]; then
      if ! exact_retired_link "$dir" bash/.config && ! exact_retired_link "$dir" tmux/.config; then
        abort "$dir is not an exact retirement ancestor fold from this clone; refusing another clone or unmanaged location"
      fi
      remove_folds+=("$dir")
    elif [[ -v retired_parents["$dir"] ]]; then
      exact_retired_link "$dir" "${retired_parents[$dir]}" ||
        abort "$dir is not the exact retired fold from this clone; refusing another clone or unmanaged location"
      remove_folds+=("$dir")
    elif resolves_into_repo "$dir"; then
      remove_folds+=("$dir")
    elif [[ ! -e $dir ]]; then
      managed_link_text "$(readlink -- "$dir")" ||
        abort "$dir is a dangling parent from another clone or unmanaged location; refusing to continue"
      remove_folds+=("$dir")
    else
      abort "$dir is linked from another clone or an unmanaged location; run from the deployed clone"
    fi
  elif [[ -e $dir && ! -d $dir ]]; then
    abort "$dir is neither a directory nor a symlink; refusing to continue"
  elif [[ -d $dir && ( $dir == "$HOME" || $dir == "$HOME/.config" || -v retired_parents["$dir"] ) ]]; then
    metadata=$(stat -c '%u %a' -- "$dir") || abort "cannot inspect retirement directory: $dir"
    read -r owner mode <<<"$metadata"
    if ! [[ $owner == "$EUID" && $mode =~ ^[0-7]{1,4}$ && -r $dir && -w $dir && -x $dir ]] ||
      (( (8#$mode & 0022) != 0 )); then
      abort "$dir is an unsafe retirement directory; require caller ownership, read/write/search access and no group/world write permission"
    fi
  fi
done

for leaf in "${leaves[@]}"; do
  under_queued_fold "$leaf" && continue
  [[ -e $leaf || -L $leaf ]] || continue
  if [[ -L $leaf ]]; then
    if [[ -v retired["$leaf"] ]]; then
      exact_retired_link "$leaf" "${retired[$leaf]}" ||
        abort "$leaf is not the exact retired link from this clone; refusing another clone or unmanaged location"
      remove_links+=("$leaf")
    elif resolves_into_repo "$leaf"; then
      continue
    elif [[ ! -e $leaf ]]; then
      queue_dangling_link "$leaf"
    else
      abort "$leaf is linked from another clone or an unmanaged location; run from the deployed clone"
    fi
  elif [[ -f $leaf ]]; then
    abort "$leaf is a regular file; compare and move or merge it before retrying"
  else
    abort "$leaf is neither a symlink nor a regular file; refusing to remove it"
  fi
done

# Guards share classification, never cleanup. Verification requires absence,
# including absence of folds that hide the retired endpoints.
if [[ ${1:-} == --check-retired ]]; then
  ((${#remove_folds[@]} + ${#remove_links[@]} == 0)) ||
    abort 'retired endpoints or folded parents remain; review make clean before restow'
  printf 'prepare-stow: retired endpoints are absent\n'
  exit 0
fi
[[ ${1:-} != --require-clone ]] || exit 0

# Mutation begins only after every owned path is classified.
if ((${#remove_folds[@]} + ${#remove_links[@]} == 0)); then
  printf 'prepare-stow: nothing to remove\n'
  exit 0
fi
for path in "${remove_folds[@]}"; do
  rm -- "$path"
  printf 'removed: %s (owned or recognized dangling folded directory link)\n' "$path"
done
for path in "${remove_links[@]}"; do
  rm -- "$path"
  printf 'removed: %s (recognized dangling or exact retired symlink)\n' "$path"
done
