#!/bin/bash
# Keep the reference clones the omasync skill compares against in step with
# the family's manifests.
#
# references.txt at each family repository root lists the clones that
# repository needs under QUARRY (default ~/Projects/quarry), one per line as
# "<directory> <git URL>"; blank lines and # comments are ignored. This
# repository's file is read first, then every sibling's ../*/references.txt,
# and the union of those files defines the quarry:
#   - a clone this repository lists and the quarry lacks is cloned
#   - a clone only a sibling lists and the quarry lacks is noted, not cloned
#   - every clone the union lists is updated: its origin is resolved through
#     the GitHub API, which follows transfers and renames, and repointed when
#     it moved; the upstream default branch is checked out and fast-forwarded
#     after a fetch that refreshes/prunes only origin's tracking branches and
#     imports new tags without pruning or replacing existing local tags;
#     a moved upstream tag refuses the fetch and requires separate review
#   - a clone no family repository lists is reported and kept, regardless of
#     its branches, tags, stash, ignored files, or apparent cleanliness
# Manifests that disagree on a URL or a malformed line stop the run before
# anything changes. A manifest URL that no longer names the resolved location,
# an origin that resolves elsewhere than its manifest, a clone with local
# changes to tracked files, or a checkout that cannot reach exact fetched
# upstream parity by fast-forwarding fails the run, so the skill never compares
# against a quarry this run did not settle. Incompatible fetch refspecs/tag
# options refuse before updating that clone. Checkout and merge refuse ignored
# file collisions rather than overwriting local bytes. Configured branch mappings must
# keep the same branch name under refs/remotes/origin, never local branches or tags.
# Non-GitHub remotes skip the transfer lookup and are fetched as they are.
# Usage: update-references.sh [--dry-run]
set -uo pipefail

repo=$(realpath -e -- "$(dirname -- "${BASH_SOURCE[0]}")/..") || { printf 'FAIL: cannot resolve the repository root\n' >&2; exit 1; }
repo_label=${repo##*/}
quarry=${QUARRY:-$HOME/Projects/quarry}
manifest=references.txt
dry_run=0
case ${1:-} in
  '') ;;
  --dry-run) dry_run=1 ;;
  *) printf 'usage: update-references.sh [--dry-run]\n' >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { printf 'usage: update-references.sh [--dry-run]\n' >&2; exit 2; }
[[ -f $repo/$manifest ]] || { printf 'FAIL: manifest is missing: %s/%s\n' "$repo" "$manifest" >&2; exit 1; }
command -v git >/dev/null || { printf 'FAIL: required tool is missing: git\n' >&2; exit 1; }

fail=0
problem() {
  printf 'FAIL: %s\n' "$1" >&2
  fail=1
}

# Manifests: this repository's, then its siblings'. The union defines the
# quarry; a name two manifests describe with different URLs is a conflict.
declare -A want=() family=() listed_by=()
read_manifest() { # file label
  local file=$1 label=$2 line name url extra
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    [[ -z ${line//[[:space:]]/} ]] && continue
    read -r name url extra <<<"$line"
    if [[ -z $name || -z $url || -n ${extra:-} || $name == */* || $name == .* ]]; then
      problem "$label/$manifest: malformed line: $line"
      continue
    fi
    if [[ -n ${family[$name]:-} && ${family[$name]} != "$url" ]]; then
      problem "$label/$manifest lists $name as $url but ${listed_by[$name]}/$manifest lists ${family[$name]}"
      continue
    fi
    family[$name]=$url
    listed_by[$name]=${listed_by[$name]:-$label}
    [[ $label == "$repo_label" ]] && want[$name]=$url
  done <"$file"
}
read_manifest "$repo/$manifest" "$repo_label"
for sibling in "${repo%/*}"/*/"$manifest"; do
  [[ -f $sibling && ! $sibling -ef $repo/$manifest ]] || continue
  sibling_dir=${sibling%/*}
  read_manifest "$sibling" "${sibling_dir##*/}"
done
((fail)) && exit 1

github_slug() { # git url -> owner/repo, or nothing for a non-GitHub remote
  local url=$1 slug
  case $url in
    https://github.com/* | http://github.com/* | ssh://git@github.com/*) slug=${url#*github.com/} ;;
    git@github.com:*) slug=${url#git@github.com:} ;;
    *) return 1 ;;
  esac
  slug=${slug%/}
  slug=${slug%.git}
  [[ $slug == */* ]] && printf '%s\n' "$slug"
}

resolve_slug() { # owner/repo -> current owner/repo through the API
  command -v gh >/dev/null || return 1
  gh api "repos/$1" --jq .full_name 2>/dev/null
}

update_clone() { # dir name manifest-url
  local clone=$1 name=$2 wanted=$3 url slug current wanted_slug wanted_current new_url default branch before after upstream
  local refspecs refspec source tagopt status
  refspecs=$(git -C "$clone" config --get-all remote.origin.fetch); status=$?
  if ((status > 1)); then problem "$name: cannot read origin fetch configuration; left alone"; return; fi
  while IFS= read -r refspec; do
    [[ -n $refspec ]] || continue
    refspec=${refspec#+}
    source=${refspec%%:*}
    if [[ $source != refs/heads/* || ${refspec#*:} != "refs/remotes/origin/${source#refs/heads/}" ]]; then
      problem "$name: incompatible origin fetch refspec; only same-name branches under refs/remotes/origin are supported; left alone"
      return
    fi
  done <<<"$refspecs"
  tagopt=$(git -C "$clone" config --get remote.origin.tagOpt); status=$?
  if ((status > 1)); then problem "$name: cannot read origin tag configuration; left alone"; return; fi
  case $tagopt in
    ''|--tags|--no-tags) ;;
    *) problem "$name: incompatible origin tagOpt; left alone"; return ;;
  esac
  url=$(git -C "$clone" remote get-url origin 2>/dev/null) || { problem "$name: no origin remote"; return; }

  if slug=$(github_slug "$url"); then
    current=$(resolve_slug "$slug")
    [[ -n $current ]] || { problem "$name: cannot resolve $slug on GitHub (gh missing, offline, or repository gone)"; return; }
    if wanted_slug=$(github_slug "$wanted"); then
      if [[ $wanted_slug != "$current" ]]; then
        wanted_current=$(resolve_slug "$wanted_slug")
        if [[ $wanted_current == "$current" ]]; then
          problem "$name: ${listed_by[$name]}/$manifest names $wanted_slug, which now lives at $current; update the manifest"
        else
          problem "$name: origin resolves to $current but ${listed_by[$name]}/$manifest names $wanted_slug; fix by hand"
          return
        fi
      fi
    else
      problem "$name: origin $url is a GitHub remote but ${listed_by[$name]}/$manifest names $wanted; fix by hand"
      return
    fi
    if [[ $current != "$slug" ]]; then
      if [[ $url == git@github.com:* ]]; then new_url="git@github.com:$current.git"; else new_url="https://github.com/$current.git"; fi
      if ((dry_run)); then
        printf 'plan: %s: repoint origin %s -> %s\n' "$name" "$slug" "$current"
      else
        git -C "$clone" remote set-url origin "$new_url" || { problem "$name: cannot repoint origin"; return; }
        printf 'ok:   %s: repointed origin %s -> %s\n' "$name" "$slug" "$current"
      fi
    fi
  elif [[ $url != "$wanted" ]]; then
    problem "$name: origin $url differs from ${listed_by[$name]}/$manifest ($wanted); fix by hand"
    return
  fi

  if [[ -n $(git -C "$clone" status --porcelain --untracked-files=no) ]]; then
    problem "$name: local changes to tracked files; left alone"
    return
  fi

  if ((dry_run)); then
    printf 'plan: %s: fetch preserving local tags, set-head, and fast-forward to the upstream default branch (now on %s)\n' \
      "$name" "$(git -C "$clone" branch --show-current)"
    return
  fi

  # Empty refmap ignores inherited forced mappings; the explicit branch map
  # bounds pruning to origin. --tags adds tags without making them pruneable.
  # Atomic ref updates refuse moved tags, including annotation-only changes.
  git -C "$clone" -c fetch.pruneTags=false -c remote.origin.pruneTags=false \
    fetch --atomic --prune --no-prune-tags --no-force --tags --refmap= \
    origin 'refs/heads/*:refs/remotes/origin/*' || {
      problem "$name: fetch refused or failed; existing local tags kept, tag conflicts require separate review"
      return
    }
  git -C "$clone" remote set-head origin -a >/dev/null 2>&1 || { problem "$name: cannot resolve the upstream default branch"; return; }
  default=$(git -C "$clone" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || { problem "$name: origin/HEAD is unset"; return; }
  default=${default#origin/}
  upstream=$(git -C "$clone" rev-parse --verify "refs/remotes/origin/$default^{commit}") || { problem "$name: fetched default branch is missing"; return; }

  # --ff-only also succeeds when the local branch is ahead. Refuse that case
  # before switching branches; success means equality with this fetched OID.
  if git -C "$clone" show-ref --verify -q "refs/heads/$default" &&
    ! git -C "$clone" merge-base --is-ancestor "refs/heads/$default" "$upstream"; then
    problem "$name: $default is ahead of or diverged from origin/$default; local branch and checkout left alone"
    return
  fi

  branch=$(git -C "$clone" branch --show-current)
  if [[ $branch != "$default" ]]; then
    if git -C "$clone" show-ref --verify -q "refs/heads/$default"; then
      git -C "$clone" checkout -q --no-overwrite-ignore "$default" || { problem "$name: cannot check out $default"; return; }
    else
      git -C "$clone" checkout -q --no-overwrite-ignore -b "$default" --track "origin/$default" || { problem "$name: cannot create $default"; return; }
    fi
    printf 'ok:   %s: switched %s -> %s\n' "$name" "${branch:-detached}" "$default"
  fi

  before=$(git -C "$clone" rev-parse --short HEAD)
  if git -C "$clone" merge -q --ff-only --no-overwrite-ignore "$upstream" &&
    [[ $(git -C "$clone" rev-parse HEAD) == "$upstream" ]]; then
    after=$(git -C "$clone" rev-parse --short HEAD)
    if [[ $before == "$after" ]]; then
      printf 'ok:   %s: %s up to date at %s\n' "$name" "$default" "$after"
    else
      printf 'ok:   %s: %s fast-forwarded %s -> %s\n' "$name" "$default" "$before" "$after"
    fi
  else
    problem "$name: cannot fast-forward $default to fetched upstream (divergence or local file conflict); inspect before retrying"
  fi
}

report_stale() { # name
  printf 'note: %s: stale reference, no family repository lists it; kept (review all refs, stashes, and ignored/untracked files before any manual removal)\n' "$1"
}

if [[ ! -d $quarry ]]; then
  if ((dry_run)); then
    printf 'plan: create %s\n' "$quarry"
  else
    mkdir -p -- "$quarry" || { printf 'FAIL: cannot create %s\n' "$quarry" >&2; exit 1; }
  fi
fi

# Clone what this repository lists and the quarry lacks.
for name in $(printf '%s\n' "${!family[@]}" | sort); do
  [[ -e $quarry/$name ]] && continue
  if [[ -z ${want[$name]:-} ]]; then
    printf 'note: %s: listed by %s only, not present here\n' "$name" "${listed_by[$name]}"
  elif ((dry_run)); then
    printf 'plan: %s: clone %s\n' "$name" "${want[$name]}"
  elif git clone -q -- "${want[$name]}" "$quarry/$name" 2>/dev/null; then
    printf 'ok:   %s: cloned %s\n' "$name" "${want[$name]}"
  else
    problem "$name: cannot clone ${want[$name]}"
  fi
done

# Update every listed clone; report and keep all unlisted ones.
for clone in "$quarry"/*/; do
  clone=${clone%/}
  [[ -d $clone ]] || continue
  name=${clone##*/}
  if [[ ! -d $clone/.git ]]; then
    printf 'note: %s: not a Git clone, left alone\n' "$name"
    continue
  fi
  if [[ -n ${family[$name]:-} ]]; then
    update_clone "$clone" "$name" "${family[$name]}"
  else
    report_stale "$name"
  fi
done

exit "$fail"
