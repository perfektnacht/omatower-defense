#!/usr/bin/env bash
# Push local edits into the running omarchy-shell, then prove they landed.
#
# You never need to reinstall: a symlink install points
# ~/.config/omarchy/plugins/ at this checkout, so the files are already live.
# All that is needed is for the shell to re-read them. The catch is that the
# shell's auto-reload watcher does not follow the symlink out to this
# directory, so it has to be told — that is what this does.
#
#   tools/reload.sh          hot reload, verified; falls back to a restart
#   tools/reload.sh --soft   hot reload only, never restart
#   tools/reload.sh --hard   go straight to a shell restart
set -euo pipefail

cd "$(dirname "$0")/.."
id="perfektnacht.omatower-defense"

# Stamp the sources so the running instance can be asked what it has.
stamp=$(cat game/*.qml ./*.qml manifest.json 2>/dev/null | sha1sum | cut -c1-7)
printf '%s' "$stamp" > game/BUILD

version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' manifest.json | head -1)
expected="$version+$stamp"

soft_reload() {
  omarchy-shell shell hide "$id" >/dev/null 2>&1 || true
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || {
    echo "omarchy-shell is not responding. Is the shell running?" >&2
    exit 1
  }
  sleep 1
}

hard_reload() {
  omarchy-restart-shell
  sleep 3
}

loaded_build() {
  omarchy-shell shell call "$id" buildInfo "" 2>/dev/null | tr -d '\r\n' || true
}

mode="${1:-}"

if [[ $mode == --hard ]]; then
  echo "Restarting omarchy-shell..."
  hard_reload
else
  soft_reload
fi

loaded=$(loaded_build)

# A long-running shell can get its reload state wedged, after which every
# rescan is a silent no-op and you debug code the shell is not running. If the
# hot path did not take, escalate rather than reporting success.
if [[ $loaded != "$expected" && $mode != --hard && $mode != --soft ]]; then
  echo "Hot reload did not take (shell has '${loaded:-nothing}'). Restarting the shell..."
  hard_reload
  loaded=$(loaded_build)
fi

if [[ $loaded == "$expected" ]]; then
  echo "Reloaded. Shell is running $loaded"
elif [[ -z $loaded || $loaded == unknown ]]; then
  echo "Plugin did not answer. Is it enabled?" >&2
  echo "  expected: $expected" >&2
  echo "  check:    omarchy plugin list | grep omatower" >&2
  exit 1
else
  echo "STALE: shell is running $loaded, expected $expected" >&2
  exit 1
fi
