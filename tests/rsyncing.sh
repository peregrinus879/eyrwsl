#!/bin/bash
# Detached local fixture watchers only, with fake inotifywait and rsync.
# RSW_FIXTURE_REALTIME=1 also exercises the unchanged production 60-second wait.
set -euo pipefail
ROOT=$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ${1:-} != --fixture-child ]]; then
  exec bash "$ROOT/tests/fixtures/rsw-tool" --run "${BASH_SOURCE[0]}"
fi
TMP=$2
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" XDG_RUNTIME_DIR="$TMP/runtime" RSW_FIXTURE="$TMP/transport"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$RSW_FIXTURE" "$TMP/bin" "$TMP/source with spaces"
source "$ROOT/bash/.config/bash/functions/rsyncing"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Stop at source resolution: this finite stub neither forks nor reports ready.
(
  setsid() { printf '%s\0' "${9}" >"$TMP/resolved"; return 91; }
  # shellcheck disable=SC2329 # These satisfy rsw's indirect command checks only.
  rsync() { return 99; }
  # shellcheck disable=SC2329
  inotifywait() { return 99; }
  mkdir -p "$TMP/colliding" "$TMP/colliding"$'\n\n'
  expected="$TMP/colliding"$'\n\n'
  if rsw "$expected" 'simulated destination with spaces'; then fail 'resolution stub reported ready'; fi
  IFS= read -r -d '' resolved <"$TMP/resolved"
  [[ $resolved == "$expected" ]] || fail 'trailing-newline source selected colliding directory'
  rm -- "$TMP/resolved"

  builtin cd -- "$TMP"
  if CDPATH=. rsw colliding 'simulated destination with spaces'; then fail 'CDPATH stub reported ready'; fi
  IFS= read -r -d '' resolved <"$TMP/resolved"
  [[ $resolved == "$TMP/colliding" ]] || fail 'CDPATH corrupted relative source resolution'
  rm -- "$TMP/resolved"

  # Load the actual deployed aliases before parsing the helper definitions.
  # shellcheck disable=SC2329 # Presence enables the production navigation alias.
  zoxide() { return 0; }
  # shellcheck disable=SC2329 # Called indirectly by the deployed zd function.
  z() { : >"$TMP/z-called"; return 1; }
  shopt -s expand_aliases
  source "$ROOT/bash/.config/bash/aliases"
  [[ $(alias cd) == "alias cd='zd'" ]] || fail 'production cd alias not loaded'
  source "$ROOT/bash/.config/bash/functions/rsyncing"
  if rsw "$expected" 'simulated destination with spaces'; then fail 'alias resolution stub reported ready'; fi
  [[ ! -e $TMP/z-called && -f $TMP/resolved ]] || fail 'production alias intercepted source resolution'
  IFS= read -r -d '' resolved <"$TMP/resolved"
  [[ $resolved == "$expected" ]] || fail 'aliased helper lost source pathname'
) || fail 'literal source resolution'
printf 'ok:   rsw preserves trailing-newline sources and bypasses deployed navigation aliases without launching watchers\n'

definition=$(declare -f _rsw_watch)
[[ $definition == *'SECONDS - last >= 60'* ]] || fail 'production reconciliation interval changed; review fixture timing'
if [[ ${RSW_FIXTURE_REALTIME:-0} != 1 ]]; then
  # Change only this shell's captured test function, never the deployed helper.
  eval "${definition/'SECONDS - last >= 60'/'SECONDS - last >= 10'}"
fi
cp "$ROOT/tests/fixtures/rsw-tool" "$TMP/bin/inotifywait"
chmod +x "$TMP/bin/inotifywait"
ln -s inotifywait "$TMP/bin/rsync"
export PATH="$TMP/bin:$PATH"
printf 'first\n' >"$TMP/source with spaces/value"
# Delay the PID write after redirection opens its file, exposing partial publication.
# shellcheck disable=SC2329 # Imported by the detached watcher Bash.
printf() {
  if [[ $0 == rsw-watch && $# == 2 && $1 == '%s\n' && $2 == "$$" ]]; then
    : >"$RSW_FIXTURE/readiness-paused"
    sleep 0.5
  fi
  # shellcheck disable=SC2059 # Forward the original fixture call unchanged.
  builtin printf "$@"
}
export -f printf
rsw "$TMP/source with spaces" 'simulated destination with spaces' >"$TMP/start.log" || fail 'watcher startup'
unset -f printf
[[ -f $RSW_FIXTURE/readiness-paused ]] || fail 'readiness publication delay not exercised'
for ((i = 0; i < 100; i++)); do [[ ! -f $RSW_FIXTURE/transferring ]] || break; sleep 0.1; done
((i < 100)) || fail 'initial transfer did not start'
lsw >"$TMP/list.log"
grep -qF "$TMP/source with spaces -> simulated destination with spaces" "$TMP/list.log" || fail 'lsw lost argv/path spaces'
read -r monitor <"$RSW_FIXTURE/monitor.pid"
kill -0 "$monitor" || fail 'monitor absent during initial transfer'
printf 'during-transfer\n' >"$TMP/source with spaces/value"
: >"$RSW_FIXTURE/events"
for ((i = 0; i < 100; i++)); do [[ -f $RSW_FIXTURE/events ]] || break; sleep 0.1; done
((i < 100)) || fail 'monitor did not consume events during rsync'
: >"$RSW_FIXTURE/release"
for ((i = 0; i < 40; i++)); do
  [[ $(<"$RSW_FIXTURE/count") == 1 ]] || break
  sleep 0.1
done
((i < 40)) || fail 'successful transfer lost events; follow-up must precede reconciliation'
for ((i = 0; i < 150; i++)); do
  [[ $(<"$RSW_FIXTURE/count") != 3 ]] || break
  sleep 0.1
done
((i < 150)) || fail 'failed transfer was not retried with changes during transfer'
[[ $(<"$RSW_FIXTURE/copied") == during-transfer ]] || fail 'retry lost updated contents'
sleep 2
[[ $(<"$RSW_FIXTURE/count") == 3 ]] || fail 'event burst was not coalesced'
grep -q 'transfer failed' "$XDG_STATE_HOME"/rsw/watch.*/watch.log || fail 'transfer error hidden'

# Deliberately omit an event; the normal fixture shortens only the wait interval.
printf 'missed-event\n' >"$TMP/source with spaces/value"
for ((i = 0; i < 700; i++)); do
  [[ $(<"$RSW_FIXTURE/copied") != missed-event ]] || break
  sleep 0.1
done
((i < 700)) || fail 'periodic reconciliation did not recover missed event'
dsw >"$TMP/stop.log"
for ((i = 0; i < 100; i++)); do [[ -n $(_rsw_pids) ]] || break; sleep 0.1; done
((i < 100)) || fail 'dsw did not stop watcher'
[[ $(lsw) == 'No active watches' ]] || fail 'lsw retained stopped watcher'

if RSW_WATCH_FAIL=1 rsw "$TMP/source with spaces" 'simulated destination with spaces' >"$TMP/error" 2>&1; then fail 'failed monitor reported ready'; fi
grep -q 'fixture watch limit reached' "$TMP/error" || fail 'watcher readiness error hidden'
read -r cleanup_pid cleanup_start <"$RSW_FIXTURE/cleanup-child"
IFS= read -r identity <"/proc/$cleanup_pid/stat"
read -r -a fields <<<"${identity##*) }"
[[ ${fields[19]} == "$cleanup_start" && ${fields[0]} != Z ]] || fail 'cleanup regression child did not outlive failed watcher'
printf 'ok:   rsw keeps a persistent monitor, coalesces transfer-time events, retries, reconciles missed events and reports readiness/errors\n'
