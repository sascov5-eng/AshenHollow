#!/bin/bash
set -euo pipefail

ROOT="Resources/PlayerAnimations"
required=(
  "Idle.png:1008:144"
  "Run.png:1152:144"
  "Jump.png:576:144"
  "Fall.png:576:144"
  "Dash.png:1728:144"
  "Attack1.png:1440:144"
  "Attack2.png:2160:144"
  "Hurt.png:432:144"
  "Death.png:2592:144"
)

for entry in "${required[@]}"; do
  IFS=: read -r name width height <<< "$entry"
  file="$ROOT/$name"
  test -f "$file" || { echo "missing animation asset: $file"; exit 1; }
  actual_width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')"
  actual_height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')"
  test "$actual_width" = "$width" || { echo "$name width $actual_width != $width"; exit 1; }
  test "$actual_height" = "$height" || { echo "$name height $actual_height != $height"; exit 1; }
done

echo "player animation asset contract OK"
