#!/usr/bin/env bash
# Installs Omatower Defense into omarchy-shell as a third-party plugin.
#
# This symlinks the checkout into ~/.config/omarchy/plugins/, which is the
# development-friendly install: edit a file here and the shell hot-reloads it.
# For a normal install, prefer:
#
#   omarchy plugin add https://github.com/perfektnacht/omatower-defense --enable
set -euo pipefail

id="perfektnacht.omatower-defense"
src="$(cd "$(dirname "$0")" && pwd)"
dest="$HOME/.config/omarchy/plugins/$id"

if ! command -v omarchy-shell >/dev/null 2>&1; then
  echo "omarchy-shell not found. This plugin needs Omarchy 4 or newer." >&2
  exit 1
fi

if [[ -e $dest || -L $dest ]]; then
  echo "Already installed at $dest"
else
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "Linked $dest -> $src"
fi

omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy plugin enable "$id" || {
  echo "Could not enable automatically. Run: omarchy plugin enable $id" >&2
  exit 1
}

cat <<MSG

Installed. Open it with the car icon in the bar, or bind a key to:

  omarchy-shell shell toggle $id

Note: this is a symlink install, and the shell's hot-reload watcher does not
follow symlinks out to $src. After editing files here, run:

  tools/reload.sh

MSG
