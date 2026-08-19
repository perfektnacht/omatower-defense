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

cd "$(dirname "$0")/.."
harness="${1:-simtest}"
stage="${TMPDIR:-/tmp}/omatower-dev-$harness"

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
