#!/usr/bin/env bash
# Diff the tracked Windows Terminal settings.json against the deployed
# Windows-side file. Run from the repo root on the WSL machine.
#
# Usage: scripts/wt-diff.sh [--push]
#   --push  back up changed deployed settings, then replace them from the repo
#
# Set WT_SETTINGS to the deployed file path to skip auto-detection.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tracked="${repo_root}/windows-terminal/settings.json"

abort() {
  printf 'wt-diff: %s\n' "$1" >&2
  exit 2
}

mode=${1:-diff}
(( $# <= 1 )) || abort "usage: scripts/wt-diff.sh [--push]"
[[ $mode == diff || $mode == --push ]] || abort "usage: scripts/wt-diff.sh [--push]"

if [[ $mode == --push ]]; then
  make --no-print-directory -C "$repo_root" require-clone || abort 'host or deployed-clone guard refused the push'
fi

deployed="${WT_SETTINGS:-}"
if [[ -z "${deployed}" ]]; then
  command -v powershell.exe >/dev/null 2>&1 || abort "powershell.exe is required to locate Windows Terminal settings"
  command -v wslpath >/dev/null 2>&1 || abort "wslpath is required to locate Windows Terminal settings"
  windows_local_app_data=$(powershell.exe -NoProfile -NonInteractive -Command \
    '[Environment]::GetFolderPath("LocalApplicationData")') ||
    abort "PowerShell could not resolve the active Windows account"
  windows_local_app_data=${windows_local_app_data//$'\r'/}
  [[ -n $windows_local_app_data ]] || abort "PowerShell returned an empty LocalApplicationData path"
  deployed="$(wslpath -u -- "$windows_local_app_data")/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
fi

[[ -f $tracked ]] || abort "tracked settings.json not found: $tracked"
[[ -n $deployed && -f $deployed ]] || abort "deployed settings.json not found; set WT_SETTINGS to its path"

strip_bom() {
  sed '1s/^\xEF\xBB\xBF//' "$1"
}

validate_json() {
  strip_bom "$1" | jq -e . >/dev/null || abort "invalid JSON: $1"
}

# Normalize before diffing: Windows Terminal rewrites the deployed file with
# its own key order and may prepend a UTF-8 BOM, so a plain checksum would
# always report drift.
normalize() {
  strip_bom "$1" | jq -S .
}

same_settings() {
  diff -q <(normalize "$tracked") <(normalize "$deployed") >/dev/null
}

tmp=""
cleanup() {
  [[ -z $tmp || ! -e $tmp ]] || rm -f -- "$tmp"
}
trap cleanup EXIT

stage_json() {
  local source=$1 destination=$2 destination_dir
  destination_dir=$(dirname -- "$destination")
  tmp=$(mktemp "$destination_dir/.settings.json.tmp.XXXXXX")
  strip_bom "$source" >"$tmp"
  validate_json "$tmp"
  chmod --reference="$destination" "$tmp"
}

validate_json "$deployed"
validate_json "$tracked"

if [[ $mode == --push ]]; then
  if same_settings; then
    echo "no changes: tracked and deployed settings already match"
    exit 0
  fi

  timestamp=$(date +%Y%m%d-%H%M%S)
  backup="${deployed}.backup-${timestamp}"
  [[ ! -e $backup ]] || abort "backup already exists: $backup"
  stage_json "$tracked" "$deployed"
  cp -p -- "$deployed" "$backup"
  mv -f -- "$tmp" "$deployed"
  tmp=""
  printf 'backed up deployed settings: %s\n' "$backup"
  printf 'pushed tracked settings: %s\n' "$deployed"
  exit 0
fi

echo "tracked:  ${tracked}"
echo "deployed: ${deployed}"

if diff -u <(normalize "${tracked}") <(normalize "${deployed}"); then
  echo "no drift: tracked and deployed settings match"
else
  echo
  echo "drift detected ('+' lines are the deployed side); reconcile manually"
  exit 1
fi
