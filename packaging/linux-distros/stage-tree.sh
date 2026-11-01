#!/usr/bin/env bash
# Lays out the installed file tree of the Linux packages from the release
# bundle (what CreatorToolkit-<version>-linux-<arch>.tar.gz holds). The repo
# has no .deb to unpack, so this is the tree pack.sh and the Flatpak work
# from:
#
#   /usr/lib/creator-toolkit/          the Flutter bundle (binary, lib/, data/)
#   /usr/bin/creator-toolkit           -> ../lib/creator-toolkit/creator_toolkit
#   /usr/share/applications/com.dhivalabs.creator_toolkit.desktop
#                                      (named after the GTK application id)
#   /usr/share/icons/hicolor/<size>/apps/creator-toolkit.png
#
# usage: stage-tree.sh <bundle-dir> <root>
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
[ $# -eq 2 ] || { echo "usage: $0 <bundle-dir> <root>" >&2; exit 2; }
bundle="$1"
root="$2"
[ -x "$bundle/creator_toolkit" ] || { echo "$bundle/creator_toolkit is missing" >&2; exit 1; }

install -d "$root/usr/lib/creator-toolkit" "$root/usr/bin"
cp -a "$bundle/." "$root/usr/lib/creator-toolkit/"
ln -s ../lib/creator-toolkit/creator_toolkit "$root/usr/bin/creator-toolkit"
install -Dm644 "$repo/linux/packaging/com.dhivalabs.creator_toolkit.desktop" \
  "$root/usr/share/applications/com.dhivalabs.creator_toolkit.desktop"
for png in "$repo"/linux/packaging/icons/creator-toolkit-*.png; do
  size="${png##*-}"
  size="${size%.png}"
  install -Dm644 "$png" "$root/usr/share/icons/hicolor/${size}x${size}/apps/creator-toolkit.png"
done
find "$root" -type d -exec chmod 0755 {} +
