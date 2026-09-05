#!/usr/bin/env bash
set -euo pipefail

for file in Sources/LargeWorldLayout.swift Sources/CinematicCameraController.swift; do
  if [ ! -f "$file" ]; then
    echo "FAIL: missing production file $file"
    exit 1
  fi
done

xcrun swiftc \
  Sources/LargeWorldLayout.swift \
  Sources/CinematicCameraController.swift \
  Tests/BlockoutLogicTests.swift \
  -o /tmp/ashen-blockout-tests

/tmp/ashen-blockout-tests
