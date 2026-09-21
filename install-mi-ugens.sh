#!/bin/sh
# Install only the two MI plugins this script needs on standard 32-bit Norns.
set -eu

case "$(uname -m)" in
  arm*|aarch64) ;;
  *) echo "This archive is for Norns ARM hardware. Install matching MI-UGens for your platform." >&2; exit 1 ;;
esac
if [ "$(getconf LONG_BIT)" != 32 ]; then
  echo "This archive needs 32-bit Norns userspace. Install matching MiRings and MiClouds builds for your image." >&2
  exit 1
fi

extensions="$HOME/.local/share/SuperCollider/Extensions"
mkdir -p "$extensions"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT HUP INT TERM

wget -T 180 -O "$staging/mi.tar" \
  https://raw.githubusercontent.com/okyeron/mi-UGens/e340375aa4bde839c73c18a94296426c76ea08b1/linux-norns-binaries/mi-UGens-linux-v.03.tar
printf '%s  %s\n' 23f71a7ad25e048dc60aaf371da44de71b0ed5f1ee4046df66ac11b2c64cc873 "$staging/mi.tar" | sha256sum -c -
tar -xf "$staging/mi.tar" -C "$staging"

for plugin in MiRings MiClouds; do
  existing_class=$(find "$extensions" -type f -name "$plugin.sc" -print -quit)
  existing_binary=$(find "$extensions" -type f -name "$plugin.so" -print -quit)
  if [ -n "$existing_class" ] && [ -n "$existing_binary" ]; then
    echo "$plugin is already installed; keeping your existing version."
  elif [ -n "$existing_class" ] || [ -n "$existing_binary" ]; then
    echo "$plugin is only partially installed. Repair the existing installation first to avoid duplicate classes." >&2
    exit 1
  else
    cp -R "$staging/mi-UGens-linux-v.03/$plugin" "$extensions/"
    echo "Installed $plugin."
  fi
done
echo "Restart Norns before opening krill-clouds."
