#!/usr/bin/env bash
# Renders the AUR PKGBUILD for one release and proves it builds.
#
# usage: aur.sh <linux-x64.tar.gz> <linux-arm64.tar.gz> <outdir>
#
# Fills PKGBUILD.in with the version, the release download URL and the
# sha256 of both release tarballs and of the desktop entry and icons that
# ship next to it, then, in an archlinux:latest container, generates
# .SRCINFO and runs makepkg on the x86_64 source (the tarball is placed
# next to the PKGBUILD, so makepkg verifies the checksum without
# downloading), and installs the result. Writes
# <name>-bin-<version>-aur.tar.gz holding PKGBUILD, .SRCINFO, the desktop
# entry and the icons, ready to push to the AUR.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
[ $# -eq 3 ] || { echo "usage: $0 <linux-x64.tar.gz> <linux-arm64.tar.gz> <outdir>" >&2; exit 2; }
tar_x64="$(readlink -f "$1")"; tar_arm64="$(readlink -f "$2")"
mkdir -p "$3"; out="$(cd "$3" && pwd)"
# shellcheck source=/dev/null
. "$here/../linux-distros/distro.conf"
: "${VERSION:?set VERSION}"
: "${GITHUB_REPO:?distro.conf must set GITHUB_REPO}"
tag="${TAG_PREFIX-v}$VERSION"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
cp "$repo/linux/packaging/com.dhivalabs.creator_toolkit.desktop" "$work/"
icons=()
for png in "$repo"/linux/packaging/icons/"$NAME"-*.png; do
  cp "$png" "$work/"
  icons+=("$(basename "$png")")
done
sha() { sha256sum "$1" | cut -d' ' -f1; }
icon_files=""; sha_common="'$(sha "$work/com.dhivalabs.creator_toolkit.desktop")'"
for i in "${icons[@]}"; do
  icon_files+="'$i' "
  sha_common+=" '$(sha "$work/$i")'"
done
deps=""; for d in "${ARCH_DEPENDS[@]}"; do deps+="'$d' "; done
optdeps=""; for d in "${ARCH_OPTDEPENDS[@]}"; do optdeps+="'$d' "; done
sed -e "s|@NAME@|$NAME|g" -e "s|@VERSION@|$VERSION|g" \
    -e "s|@SUMMARY@|${SUMMARY//\'/}|g" -e "s|@HOMEPAGE@|$HOMEPAGE|g" \
    -e "s|@LICENSE@|$LICENSE|g" -e "s|@ARCH_DEPENDS@|${deps% }|g" -e "s|@ARCH_OPTDEPENDS@|${optdeps% }|g" \
    -e "s|@ICON_FILES@|${icon_files% }|g" -e "s|@SHA_COMMON@|$sha_common|g" \
    -e "s|@RELEASE_URL@|https://github.com/$GITHUB_REPO/releases/download/$tag|g" \
    -e "s|@TARBALL_X64@|$(basename "$tar_x64")|g" -e "s|@TARBALL_ARM64@|$(basename "$tar_arm64")|g" \
    -e "s|@SHA_X64@|$(sha "$tar_x64")|g" -e "s|@SHA_ARM64@|$(sha "$tar_arm64")|g" \
    "$here/PKGBUILD.in" > "$work/PKGBUILD"
cp "$tar_x64" "$work/"
if grep -n '@[A-Z0-9_]*@' "$work/PKGBUILD"; then echo "unfilled placeholder" >&2; exit 1; fi

# The container hands /build to its builder user; the trap gives it back to
# the runner's user, which must still read it (tar) and delete it (trap).
docker run --rm -v "$work:/build" -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    archlinux:latest bash -euo pipefail -c '
  trap "chown -R $HOST_UID:$HOST_GID /build" EXIT
  pacman -Syu --noconfirm --needed -q base-devel namcap
  useradd -m builder
  chown -R builder /build
  cd /build
  su builder -c "makepkg --printsrcinfo > .SRCINFO"
  su builder -c "makepkg --noconfirm --nodeps -f"
  namcap PKGBUILD
  pacman -U --noconfirm ./*-x86_64.pkg.tar.zst
  pacman -Qlq '"$NAME"'-bin | grep -x /usr/bin/'"$NAME"'
  cat .SRCINFO
'
tar -C "$work" -czf "$out/$NAME-bin-$VERSION-aur.tar.gz" PKGBUILD .SRCINFO \
  com.dhivalabs.creator_toolkit.desktop "${icons[@]}"
ls -l "$out/$NAME-bin-$VERSION-aur.tar.gz"
