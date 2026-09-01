import Foundation

enum TMXRoomSchema {
    enum Layer {
        static let collision = "Collision"
        static let entities = "Entities"
        static let triggers = "Triggers"
        static let allowed: Set<String> = [collision, entities, triggers]
    }

    enum ObjectClass {
        static let platform = "platform"
        static let playerSpawn = "player_spawn"
        static let enemy = "enemy"
        static let checkpoint = "checkpoint"
        static let shrine = "shrine"
        static let roomExit = "room_exit"
    }

    enum Property {
        static let roomID = "roomID"
        static let worldOriginX = "worldOriginX"
        static let worldOriginY = "worldOriginY"
        static let requiresCombatClear = "requiresCombatClear"

        static let boundsX = "boundsX"
        static let boundsY = "boundsY"
        static let boundsWidth = "boundsWidth"
        static let boundsHeight = "boundsHeight"

        static let id = "id"
        static let archetype = "archetype"
        static let ability = "ability"

        static let checkpointID = "checkpointID"
        static let checkpointRoom = "checkpointRoom"
        static let checkpointSpawnX = "checkpointSpawnX"
        static let checkpointSpawnY = "checkpointSpawnY"

        static let destinationRoom = "destinationRoom"
        static let destinationSpawnX = "destinationSpawnX"
        static let destinationSpawnY = "destinationSpawnY"
        static let completesLevel = "completesLevel"
        static let requiredAbility = "requiredAbility"
    }

    static func objectClass(className: String?, legacyType: String?) -> String? {
        let preferred = className?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let preferred, !preferred.isEmpty {
            return preferred
        }

        let legacy = legacyType?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let legacy, !legacy.isEmpty {
            return legacy
        }

        return nil
    }
}
