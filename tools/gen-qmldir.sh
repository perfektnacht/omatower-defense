#!/usr/bin/env bash
# Regenerates game/qmldir from the .qml files present, marking pragma Singletons.
set -euo pipefail
cd "$(dirname "$0")/.."
out=game/qmldir
{
  for f in game/*.qml; do
    n=$(basename "$f" .qml)
    if head -3 "$f" | grep -q "^pragma Singleton"; then
      echo "singleton $n 1.0 $n.qml"
    fi
  done
  echo
  for f in game/*.qml; do
    n=$(basename "$f" .qml)
    head -3 "$f" | grep -q "^pragma Singleton" || echo "$n 1.0 $n.qml"
  done
} > "$out"
