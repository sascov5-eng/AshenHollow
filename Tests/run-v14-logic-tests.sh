#!/usr/bin/env bash
set -euo pipefail

xcrun swiftc \
  Sources/PlayerMovementTuning.swift \
  Sources/TestLocationModel.swift \
  Sources/KingdomMap.swift \
  Sources/TestLocationLayout.swift \
  Sources/TraversalReachabilityValidator.swift \
  Sources/TestSessionState.swift \
  Sources/CheckpointController.swift \
  Sources/SafePositionTracker.swift \
  Sources/HazardController.swift \
  Sources/RespawnController.swift \
  Sources/DeveloperTutorialController.swift \
  Sources/MovingPlatformController.swift \
  Sources/TestEnemyController.swift \
  Sources/PlayerDamageController.swift \
  Sources/PlayerLifeStateController.swift \
  Sources/TestInteractionController.swift \
  Tests/V14LogicTests.swift \
  -o /tmp/ashen-v14-tests

/tmp/ashen-v14-tests
