#!/usr/bin/env bash
# Runs a dev harness from tools/ against the current game/ sources.
#
# `qs -p <file>` treats that file's directory as the config root and refuses to
# import above it, so a harness in tools/ cannot reach ../game. This stages both
# into a scratch directory and runs there.
#
#   tools/dev.sh preview [circuit 0-4]   a live game, screenshot to $SHOT
#   tools/dev.sh artcheck                every car and creature, side by side
#   tools/dev.sh simtest                 headless mechanics + balance checks
set -euo pipefail
umask 077

cd "$(dirname "$0")/.."

# The name picks a file to copy and a directory to delete, so it has to be a
# plain harness name -- not a path that can climb out of tools/.
harness="${1:-simtest}"
if [[ ! $harness =~ ^[a-z][a-z0-9]*$ ]]; then
  echo "harness must be a plain name like 'simtest', got: $harness" >&2
  exit 1
fi
if [[ ! -f tools/$harness.qml ]]; then
  echo "no such harness: tools/$harness.qml" >&2
  echo "available: $(cd tools && ls -1 ./*.qml | sed 's|^\./||;s|\.qml$||' | tr '\n' ' ')" >&2
  exit 1
fi

# The stage is wiped and repopulated on every run, and then executed. A fixed
# name in shared /tmp is the wrong place for that: on a multi-user machine
# anyone can park a directory or a symlink there first. $XDG_RUNTIME_DIR is
# per-user and 0700, so a stable, predictable path inside it is safe -- and a
# stable path is worth keeping, because it makes the staged sources easy to
# inspect between runs. Without one, fall back to a name nobody can guess.
if [[ -n ${XDG_RUNTIME_DIR:-} && -d ${XDG_RUNTIME_DIR:-} ]]; then
  stage="$XDG_RUNTIME_DIR/omatower-dev/$harness"
  mkdir -p "$XDG_RUNTIME_DIR/omatower-dev"
else
  stage="$(mktemp -d "${TMPDIR:-/tmp}/omatower-dev-XXXXXXXXXX")/$harness"
fi

# Refuse to follow a symlink out of the staging area, however it got there.
if [[ -L $stage ]]; then
  echo "staging path is a symlink, refusing to use it: $stage" >&2
  exit 1
fi

rm -rf "$stage"
mkdir -p "$stage"
cp -r game "$stage/game"
cp "tools/$harness.qml" "$stage/$harness.qml"
[ -d tools/themes ] && cp -r tools/themes "$stage/themes"

export SHOT="${SHOT:-$stage/$harness.png}"
export CIRCUIT="${2:-0}"
export DELAY="${DELAY:-6000}"
# themecheck grades the shipped fixtures by default; point EXTRA elsewhere to
# grade a different set.
export EXTRA="${EXTRA:-$stage/themes}"

cd "$stage"
timeout "${RUNFOR:-30}" qs -p "./$harness.qml" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -v "qt.qpa.services" || true
echo "harness: $stage"
[ -f "$SHOT" ] && echo "shot:    $SHOT"
