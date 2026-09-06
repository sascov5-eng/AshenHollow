#!/bin/bash
set -euo pipefail

ROOT="Resources/PlayerAnimations"
required=(
  "Idle.png:768:192"
  "Run.png:768:192"
  "Jump.png:768:192"
  "Fall.png:768:192"
  "Dash.png:768:192"
  "Attack1.png:768:192"
  "Attack2.png:768:192"
  "AttackUp.png:768:192"
  "AttackDown.png:768:192"
  "Hurt.png:768:192"
  "Death.png:768:192"
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
