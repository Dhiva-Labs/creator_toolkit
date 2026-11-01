#!/usr/bin/env bash
# Installs the Flatpak bundle the way a user does and runs Creator Toolkit and
# its bundled FFmpeg in the sandbox. CI runs this on a plain Ubuntu runner
# (the flatpak-run job).
#
# usage: smoke.sh <bundle.flatpak>
#
#   1. `flatpak install --user` the bundle;
#   2. ldd every ELF file under /app inside the sandbox (the app, ffmpeg,
#      ffprobe, libx264): no "not found";
#   3. inside the sandbox, the bundled ffmpeg runs every encoder argument
#      set the app uses (lib/services/{video,audio,image}_service.dart) on a
#      generated H.264 clip, writing to ~/CreatorToolkit, the app's output
#      folder (--filesystem=~/CreatorToolkit:create); ffprobe reads the
#      duration back, as the app does for progress. Each output must then
#      exist on the host side, non-empty;
#   4. under Xvfb, the app must draw its window: counted in Xvfb's
#      framebuffer, where an empty screen has one colour (read directly,
#      without xdotool).
set -euo pipefail
APP_ID=com.dhivalabs.creator_toolkit
[ $# -eq 1 ] || { echo "usage: $0 <bundle.flatpak>" >&2; exit 2; }
bundle="$(readlink -f "$1")"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
mkdir -p -m 0700 "$XDG_RUNTIME_DIR"

echo "::group::flatpak install --user $(basename "$bundle")"
# Flathub first: the bundle's runtime, and the GL extension (Mesa) that
# Flutter draws with, install from there, as on a user's machine.
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y --noninteractive "$bundle"
flatpak info --user "$APP_ID"
flatpak info --user --show-permissions "$APP_ID"
echo "::endgroup::"

echo "::group::ldd inside the sandbox"
flatpak run --command=bash "$APP_ID" -c '
  set -euo pipefail
  mapfile -d "" elfs < <(find /app -type f -print0)
  libdirs="$(find /app -name "*.so*" -type f -printf "%h\n" | sort -u | paste -sd:)"
  n=0; bad=0
  for f in "${elfs[@]}"; do
    [ "$(head -c 4 "$f" | od -An -tx1 | tr -d " \n")" = 7f454c46 ] || continue
    n=$((n + 1))
    if LD_LIBRARY_PATH="$libdirs" ldd "$f" 2>&1 | grep "not found" > /dev/null; then
      echo "missing libraries for $f:"
      LD_LIBRARY_PATH="$libdirs" ldd "$f" | grep "not found"
      bad=1
    fi
  done
  echo "$n ELF files checked with ldd in the sandbox"
  [ "$n" -gt 0 ] && [ "$bad" = 0 ]'
echo "::endgroup::"

echo "::group::the app's FFmpeg jobs inside the sandbox"
out="$HOME/CreatorToolkit"
rm -rf "$out"
# The same argument lists as the app's services, with -hide_banner -y as
# FfmpegService.run adds them.
flatpak run --command=bash "$APP_ID" -c '
  set -euo pipefail
  command -v ffmpeg ffprobe
  out="$HOME/CreatorToolkit"
  mkdir -p "$out"
  ff() { ffmpeg -hide_banner -y -loglevel error "$@"; }
  even="scale=trunc(iw/2)*2:trunc(ih/2)*2"
  # Input: a 3 s H.264 + AAC clip, like a phone video. Made with source
  # filters in -filter_complex: the bundle is built without libavdevice, so
  # it has no lavfi input device.
  ff -filter_complex "testsrc2=size=640x360:rate=30:duration=3[v];sine=frequency=440:duration=3[a]" \
     -map "[v]" -map "[a]" -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$out/input.mp4"
  in="$out/input.mp4"
  # VideoService.compress, convert (mp4/mov/mkv, webm, gif), trim
  ff -i "$in" -vf "scale=-2:min(720\,trunc(ih/2)*2)" -c:v libx264 -crf 26 -preset veryfast \
     -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart "$out/compressed.mp4"
  ff -i "$in" -vf "$even" -c:v libx264 -crf 23 -preset veryfast -pix_fmt yuv420p \
     -c:a aac -b:a 160k "$out/converted.mkv"
  ff -i "$in" -vf "$even" -c:v libvpx-vp9 -crf 33 -b:v 0 -row-mt 1 -cpu-used 4 \
     -c:a libopus -b:a 128k "$out/converted.webm"
  ff -i "$in" -vf fps=12,scale=480:-2 -loop 0 -an "$out/converted.gif"
  ff -i "$in" -ss 00:00:00.500 -to 00:00:02.000 -c copy -avoid_negative_ts make_zero "$out/trimmed.mp4"
  # AudioService.convert
  ff -i "$in" -vn -c:a libmp3lame -b:a 192k "$out/audio.mp3"
  ff -i "$in" -vn -c:a aac -b:a 192k "$out/audio.m4a"
  ff -i "$in" -vn -c:a libvorbis -b:a 192k "$out/audio.ogg"
  ff -i "$in" -vn -c:a pcm_s16le "$out/audio.wav"
  ff -i "$in" -vn -c:a flac "$out/audio.flac"
  # ImageService: WEBP through ffmpeg on desktop
  ff -i "$in" -frames:v 1 "$out/frame.png"
  ff -i "$out/frame.png" -c:v libwebp -quality 80 "$out/image.webp"
  # FfmpegService.probeDuration
  d="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$out/compressed.mp4")"
  echo "ffprobe duration of compressed.mp4: $d"
  awk -v d="$d" "BEGIN { exit !(d > 2.5 && d < 3.5) }"'
for f in input.mp4 compressed.mp4 converted.mkv converted.webm converted.gif trimmed.mp4 \
    audio.mp3 audio.m4a audio.ogg audio.wav audio.flac frame.png image.webp; do
  [ -s "$out/$f" ] || { echo "$out/$f is missing or empty on the host"; ls -la "$out"; exit 1; }
done
ls -la "$out"
echo "all of the app's FFmpeg jobs ran in the sandbox and wrote to $out"
echo "::endgroup::"

fb="$(mktemp -d)"
cat > "$fb/run.sh" <<'EOS'
set -euo pipefail
app_id="$1"; fb="$2"; here="$3"
log="$fb/app.log"
flatpak run "$app_id" > "$log" 2>&1 &
pid=$!
ok=0
for i in $(seq 1 120); do
  kill -0 "$pid" 2> /dev/null || { echo "the app exited early"; break; }
  colours="$(python3 "$here/xwd-colours.py" "$fb/Xvfb_screen0")"
  if [ "$colours" -ge 16 ]; then
    echo "after ${i}s: the screen shows $colours colours"
    ok=1
    break
  fi
  sleep 1
done
if [ "$ok" = 1 ]; then
  sleep 5
  kill -0 "$pid" 2> /dev/null || { echo "the app died after it came up"; ok=0; }
else
  echo "not up after 120s: screen colours ${colours:-?}"
fi
kill "$pid" 2> /dev/null || :
cat "$log"
if grep -E 'error while loading shared libraries|cannot open shared object|undefined symbol' "$log"; then ok=0; fi
[ "$ok" = 1 ]
EOS
echo "::group::run under Xvfb"
xvfb-run -a -s "-screen 0 1280x800x24 -br -fbdir $fb" \
  dbus-run-session -- bash "$fb/run.sh" "$APP_ID" "$fb" "$here"
echo "::endgroup::"
rm -rf "$fb"
echo "Flatpak bundle $(basename "$bundle"): OK"
