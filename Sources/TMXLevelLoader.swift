import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

enum TMXLevelLoaderError: Error, Equatable, CustomStringConvertible {
    case missingResource(String)
    case malformedXML(String)
    case unsupportedOrientation(String)
    case infiniteMap
    case missingRequiredProperty(String)
    case unknownRoomID(String)
    case missingPlayerSpawn
    case duplicatePlayerSpawn
    case unknownLayer(String)
    case unknownObjectType(layer: String, type: String)
    case invalidProperty(name: String, value: String, expected: String)
    case unknownEnemyArchetype(String)
    case invalidExit(String)
    case unsupportedRotation(objectID: Int, degrees: Double)
    case invalidObjectGeometry(objectID: Int, reason: String)
    case unexpectedRoomID(expected: RoomID, actual: RoomID)

    var description: String {
        switch self {
        case .missingResource(let value):
            return "Missing TMX resource: \(value)"
        case .malformedXML(let value):
            return "Malformed TMX XML: \(value)"
        case .unsupportedOrientation(let value):
            return "Unsupported TMX orientation: \(value)"
        case .infiniteMap:
            return "Infinite TMX maps are not supported"
        case .missingRequiredProperty(let value):
            return "Missing required TMX property: \(value)"
        case .unknownRoomID(let value):
            return "Unknown RoomID: \(value)"
        case .missingPlayerSpawn:
            return "TMX room is missing player_spawn"
        case .duplicatePlayerSpawn:
            return "TMX room contains multiple player_spawn objects"
        case .unknownLayer(let value):
            return "Unknown TMX object layer: \(value)"
        case .unknownObjectType(let layer, let type):
            return "Unknown TMX object type \(type) in layer \(layer)"
        case .invalidProperty(let name, let value, let expected):
            return "Invalid TMX property \(name)=\(value); expected \(expected)"
        case .unknownEnemyArchetype(let value):
            return "Unknown enemy archetype: \(value)"
        case .invalidExit(let value):
            return "Invalid room_exit: \(value)"
        case .unsupportedRotation(let objectID, let degrees):
            return "TMX object \(objectID) uses unsupported rotation \(degrees)"
        case .invalidObjectGeometry(let objectID, let reason):
            return "Invalid TMX object \(objectID) geometry: \(reason)"
        case .unexpectedRoomID(let expected, let actual):
            return "Expected TMX room \(expected.rawValue), got \(actual.rawValue)"
        }
    }
}

struct TMXLevelLoader {
    static func loadRoom(
        data: Data,
        sourceName: String = "<memory>"
    ) throws -> RoomDefinition {
        let delegate = TMXParserDelegate(sourceName: sourceName)
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        let parsed = parser.parse()

        // Domain validation discovered while reading XML has priority over the
        // generic XMLParser failure so callers get the precise TMX error.
        if let domainFailure = delegate.domainFailure {
            throw domainFailure
        }

        // XMLParser can report a parser error even when parse() returns true on
        // some FoundationXML implementations. Always inspect both channels.
        if !parsed || delegate.parserFailure != nil || parser.parserError != nil {
            let message = delegate.parserFailure
                ?? parser.parserError?.localizedDescription
                ?? "unknown parser failure"
            throw TMXLevelLoaderError.malformedXML("\(sourceName): \(message)")
        }

        return try buildRoom(from: delegate.document)
    }

    static func loadRoom(at url: URL) throws -> RoomDefinition {
        guard let data = try? Data(contentsOf: url) else {
            throw TMXLevelLoaderError.missingResource(url.path)
        }
        return try loadRoom(data: data, sourceName: url.lastPathComponent)
    }

    static func productionURL(
        named name: String,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> URL? {
        let fileName = name.hasSuffix(".tmx") ? name : "\(name).tmx"
        var candidates: [URL] = [
            bundle.bundleURL
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("Maps", isDirectory: true)
                .appendingPathComponent(fileName)
        ]

        if let resourceURL = bundle.resourceURL {
            let candidate = resourceURL
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("Maps", isDirectory: true)
                .appendingPathComponent(fileName)
            if !candidates.contains(where: { $0.standardizedFileURL == candidate.standardizedFileURL }) {
                candidates.append(candidate)
            }
        }

        candidates.append(
            URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("Maps", isDirectory: true)
                .appendingPathComponent(fileName)
        )

        return candidates.first(where: { fileManager.fileExists(atPath: $0.path) })
    }

    static func loadProductionRoom(
        named name: String,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) throws -> RoomDefinition {
        guard let url = productionURL(named: name, bundle: bundle, fileManager: fileManager) else {
            throw TMXLevelLoaderError.missingResource(name)
        }
        return try loadRoom(at: url)
    }

    private static func buildRoom(from document: TMXParsedDocument) throws -> RoomDefinition {
        guard document.orientation == "orthogonal" else {
            throw TMXLevelLoaderError.unsupportedOrientation(document.orientation)
        }
        if document.infinite {
            throw TMXLevelLoaderError.infiniteMap
        }

        let mapWidth = try positiveDouble(document.width, name: "map.width")
        let mapHeight = try positiveDouble(document.height, name: "map.height")
        let tileWidth = try positiveDouble(document.tileWidth, name: "map.tilewidth")
        let tileHeight = try positiveDouble(document.tileHeight, name: "map.tileheight")
        let pixelWidth = mapWidth * tileWidth
        let pixelHeight = mapHeight * tileHeight

        let roomIDRaw = try requiredProperty(TMXRoomSchema.Property.roomID, in: document.properties)
        guard let roomID = RoomID(rawValue: roomIDRaw) else {
            throw TMXLevelLoaderError.unknownRoomID(roomIDRaw)
        }

        let worldOriginX = try requiredDouble(TMXRoomSchema.Property.worldOriginX, in: document.properties)
        let worldOriginY = try requiredDouble(TMXRoomSchema.Property.worldOriginY, in: document.properties)
        let requiresCombatClear = try requiredBool(TMXRoomSchema.Property.requiresCombatClear, in: document.properties)

        let boundKeys = [
            TMXRoomSchema.Property.boundsX,
            TMXRoomSchema.Property.boundsY,
            TMXRoomSchema.Property.boundsWidth,
            TMXRoomSchema.Property.boundsHeight
        ]
        let explicitBoundCount = boundKeys.filter { document.properties[$0] != nil }.count
        let bounds: RoomRect
        if explicitBoundCount == 0 {
            bounds = RoomRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        } else if explicitBoundCount == boundKeys.count {
            bounds = RoomRect(
                x: try requiredDouble(TMXRoomSchema.Property.boundsX, in: document.properties),
                y: try requiredDouble(TMXRoomSchema.Property.boundsY, in: document.properties),
                width: try requiredDouble(TMXRoomSchema.Property.boundsWidth, in: document.properties),
                height: try requiredDouble(TMXRoomSchema.Property.boundsHeight, in: document.properties)
            )
        } else {
            let missing = boundKeys.first(where: { document.properties[$0] == nil }) ?? "bounds"
            throw TMXLevelLoaderError.missingRequiredProperty(missing)
        }

        var platforms: [RoomPlatform] = []
        var playerSpawn: RoomPoint?
        var enemySpawns: [EnemySpawn] = []
        var checkpointTriggers: [CheckpointTrigger] = []
        var shrine: AbilityShrinePlacement?
        var exits: [RoomExit] = []

        for object in document.objects {
            guard TMXRoomSchema.Layer.allowed.contains(object.layer) else {
                throw TMXLevelLoaderError.unknownLayer(object.layer)
            }

            if abs(object.rotation) > 0.000_001 {
                throw TMXLevelLoaderError.unsupportedRotation(
                    objectID: object.id,
                    degrees: object.rotation
                )
            }

            guard let objectType = object.objectType else {
                throw TMXLevelLoaderError.unknownObjectType(layer: object.layer, type: "<missing>")
            }

            switch object.layer {
            case TMXRoomSchema.Layer.collision:
                guard objectType == TMXRoomSchema.ObjectClass.platform else {
                    throw TMXLevelLoaderError.unknownObjectType(layer: object.layer, type: objectType)
                }
                try requireRectangle(object)
                platforms.append(
                    RoomPlatform(
                        center: rectangleCenter(object, mapPixelHeight: pixelHeight),
                        size: RoomSize(width: object.width, height: object.height)
                    )
                )

            case TMXRoomSchema.Layer.entities:
                switch objectType {
                case TMXRoomSchema.ObjectClass.playerSpawn:
                    let position = try placementPoint(object, mapPixelHeight: pixelHeight)
                    if playerSpawn != nil {
                        throw TMXLevelLoaderError.duplicatePlayerSpawn
                    }
                    playerSpawn = position

                case TMXRoomSchema.ObjectClass.enemy:
                    let position = try placementPoint(object, mapPixelHeight: pixelHeight)
                    let id = try requiredInt(TMXRoomSchema.Property.id, in: object.properties)
                    let archetypeRaw = try requiredProperty(TMXRoomSchema.Property.archetype, in: object.properties)
                    guard let archetype = EnemyArchetype(rawValue: archetypeRaw) else {
                        throw TMXLevelLoaderError.unknownEnemyArchetype(archetypeRaw)
                    }
                    enemySpawns.append(EnemySpawn(id: id, archetype: archetype, position: position))

                case TMXRoomSchema.ObjectClass.checkpoint:
                    try requireRectangle(object)
                    let checkpoint = try checkpointSnapshot(from: object.properties)
                    checkpointTriggers.append(
                        CheckpointTrigger(
                            checkpoint: checkpoint,
                            trigger: rectangle(object, mapPixelHeight: pixelHeight)
                        )
                    )

                case TMXRoomSchema.ObjectClass.shrine:
                    if shrine != nil {
                        throw TMXLevelLoaderError.invalidObjectGeometry(
                            objectID: object.id,
                            reason: "only one shrine is supported per room"
                        )
                    }
                    let position = try placementPoint(object, mapPixelHeight: pixelHeight)
                    let shrineRaw = try requiredProperty(TMXRoomSchema.Property.id, in: object.properties)
                    guard let shrineID = ShrineID(rawValue: shrineRaw) else {
                        throw TMXLevelLoaderError.invalidProperty(
                            name: TMXRoomSchema.Property.id,
                            value: shrineRaw,
                            expected: "ShrineID raw value"
                        )
                    }
                    let abilityRaw = try requiredProperty(TMXRoomSchema.Property.ability, in: object.properties)
                    guard let ability = PlayerAbility(rawValue: abilityRaw) else {
                        throw TMXLevelLoaderError.invalidProperty(
                            name: TMXRoomSchema.Property.ability,
                            value: abilityRaw,
                            expected: "PlayerAbility raw value"
                        )
                    }
                    shrine = AbilityShrinePlacement(
                        id: shrineID,
                        ability: ability,
                        position: position,
                        checkpoint: try checkpointSnapshot(from: object.properties)
                    )

                default:
                    throw TMXLevelLoaderError.unknownObjectType(layer: object.layer, type: objectType)
                }

            case TMXRoomSchema.Layer.triggers:
                guard objectType == TMXRoomSchema.ObjectClass.roomExit else {
                    throw TMXLevelLoaderError.unknownObjectType(layer: object.layer, type: objectType)
                }
                try requireRectangle(object)
                exits.append(try roomExit(from: object, mapPixelHeight: pixelHeight))

            default:
                throw TMXLevelLoaderError.unknownLayer(object.layer)
            }
        }

        guard let playerSpawn else {
            throw TMXLevelLoaderError.missingPlayerSpawn
        }

        return RoomDefinition(
            id: roomID,
            worldOrigin: RoomPoint(x: worldOriginX, y: worldOriginY),
            bounds: bounds,
            playerSpawn: playerSpawn,
            platforms: platforms,
            enemySpawns: enemySpawns,
            requiresCombatClear: requiresCombatClear,
            exits: exits,
            shrine: shrine,
            checkpointTriggers: checkpointTriggers
        )
    }

    private static func roomExit(
        from object: TMXParsedObject,
        mapPixelHeight: Double
    ) throws -> RoomExit {
        let completesLevel: Bool
        if let raw = object.properties[TMXRoomSchema.Property.completesLevel] {
            completesLevel = try parseBool(raw, name: TMXRoomSchema.Property.completesLevel)
        } else {
            completesLevel = false
        }

        let requiredAbility: PlayerAbility?
        if let raw = object.properties[TMXRoomSchema.Property.requiredAbility], !raw.isEmpty {
            guard let ability = PlayerAbility(rawValue: raw) else {
                throw TMXLevelLoaderError.invalidProperty(
                    name: TMXRoomSchema.Property.requiredAbility,
                    value: raw,
                    expected: "PlayerAbility raw value"
                )
            }
            requiredAbility = ability
        } else {
            requiredAbility = nil
        }

        let destinationRaw = object.properties[TMXRoomSchema.Property.destinationRoom]
        let destinationRoomID: RoomID?
        let destinationSpawn: RoomPoint?

        if let destinationRaw, !destinationRaw.isEmpty {
            guard let destination = RoomID(rawValue: destinationRaw) else {
                throw TMXLevelLoaderError.unknownRoomID(destinationRaw)
            }
            destinationRoomID = destination

            guard let xRaw = object.properties[TMXRoomSchema.Property.destinationSpawnX],
                  let yRaw = object.properties[TMXRoomSchema.Property.destinationSpawnY] else {
                throw TMXLevelLoaderError.invalidExit("destinationRoom requires destinationSpawnX and destinationSpawnY")
            }
            destinationSpawn = RoomPoint(
                x: try parseDouble(xRaw, name: TMXRoomSchema.Property.destinationSpawnX),
                y: try parseDouble(yRaw, name: TMXRoomSchema.Property.destinationSpawnY)
            )
        } else {
            destinationRoomID = nil
            destinationSpawn = nil
            if !completesLevel {
                throw TMXLevelLoaderError.invalidExit("exit must have destinationRoom or completesLevel=true")
            }
        }

        return RoomExit(
            trigger: rectangle(object, mapPixelHeight: mapPixelHeight),
            destinationRoomID: destinationRoomID,
            destinationSpawn: destinationSpawn,
            completesLevel: completesLevel,
            requiredAbility: requiredAbility
        )
    }

    private static func checkpointSnapshot(
        from properties: [String: String]
    ) throws -> CheckpointSnapshot {
        let checkpointRaw = try requiredProperty(TMXRoomSchema.Property.checkpointID, in: properties)
        guard let checkpointID = CheckpointID(rawValue: checkpointRaw) else {
            throw TMXLevelLoaderError.invalidProperty(
                name: TMXRoomSchema.Property.checkpointID,
                value: checkpointRaw,
                expected: "CheckpointID raw value"
            )
        }

        let roomRaw = try requiredProperty(TMXRoomSchema.Property.checkpointRoom, in: properties)
        guard let roomID = RoomID(rawValue: roomRaw) else {
            throw TMXLevelLoaderError.unknownRoomID(roomRaw)
        }

        return CheckpointSnapshot(
            id: checkpointID,
            roomID: roomID,
            spawn: RoomPoint(
                x: try requiredDouble(TMXRoomSchema.Property.checkpointSpawnX, in: properties),
                y: try requiredDouble(TMXRoomSchema.Property.checkpointSpawnY, in: properties)
            )
        )
    }

    private static func placementPoint(
        _ object: TMXParsedObject,
        mapPixelHeight: Double
    ) throws -> RoomPoint {
        if object.isPoint {
            return RoomPoint(x: object.x, y: mapPixelHeight - object.y)
        }
        try requireRectangle(object)
        return rectangleCenter(object, mapPixelHeight: mapPixelHeight)
    }

    private static func rectangleCenter(
        _ object: TMXParsedObject,
        mapPixelHeight: Double
    ) -> RoomPoint {
        RoomPoint(
            x: object.x + object.width * 0.5,
            y: mapPixelHeight - object.y - object.height * 0.5
        )
    }

    private static func rectangle(
        _ object: TMXParsedObject,
        mapPixelHeight: Double
    ) -> RoomRect {
        RoomRect(
            x: object.x,
            y: mapPixelHeight - object.y - object.height,
            width: object.width,
            height: object.height
        )
    }

    private static func requireRectangle(_ object: TMXParsedObject) throws {
        guard !object.isPoint, object.width > 0, object.height > 0 else {
            throw TMXLevelLoaderError.invalidObjectGeometry(
                objectID: object.id,
                reason: "expected non-empty rectangle"
            )
        }
    }

    private static func positiveDouble(_ raw: String?, name: String) throws -> Double {
        guard let raw else {
            throw TMXLevelLoaderError.missingRequiredProperty(name)
        }
        let value = try parseDouble(raw, name: name)
        guard value > 0 else {
            throw TMXLevelLoaderError.invalidProperty(name: name, value: raw, expected: "positive number")
        }
        return value
    }

    private static func requiredProperty(
        _ name: String,
        in properties: [String: String]
    ) throws -> String {
        guard let value = properties[name], !value.isEmpty else {
            throw TMXLevelLoaderError.missingRequiredProperty(name)
        }
        return value
    }

    private static func requiredDouble(
        _ name: String,
        in properties: [String: String]
    ) throws -> Double {
        try parseDouble(try requiredProperty(name, in: properties), name: name)
    }

    private static func requiredInt(
        _ name: String,
        in properties: [String: String]
    ) throws -> Int {
        let raw = try requiredProperty(name, in: properties)
        guard let value = Int(raw) else {
            throw TMXLevelLoaderError.invalidProperty(name: name, value: raw, expected: "integer")
        }
        return value
    }

    private static func requiredBool(
        _ name: String,
        in properties: [String: String]
    ) throws -> Bool {
        try parseBool(try requiredProperty(name, in: properties), name: name)
    }

    private static func parseDouble(_ raw: String, name: String) throws -> Double {
        guard let value = Double(raw), value.isFinite else {
            throw TMXLevelLoaderError.invalidProperty(name: name, value: raw, expected: "finite number")
        }
        return value
    }

    private static func parseBool(_ raw: String, name: String) throws -> Bool {
        switch raw.lowercased() {
        case "true", "1":
            return true
        case "false", "0":
            return false
        default:
            throw TMXLevelLoaderError.invalidProperty(name: name, value: raw, expected: "boolean")
        }
    }
}

private struct TMXParsedDocument {
    var orientation: String = ""
    var infinite = false
    var width: String?
    var height: String?
    var tileWidth: String?
    var tileHeight: String?
    var properties: [String: String] = [:]
    var objects: [TMXParsedObject] = []
}

private struct TMXParsedObject {
    let id: Int
    let layer: String
    let objectType: String?
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let rotation: Double
    var isPoint: Bool
    var properties: [String: String]
}

private final class TMXParserDelegate: NSObject, XMLParserDelegate {
    private enum PropertyTarget {
        case map
        case object
    }

    let sourceName: String
    var document = TMXParsedDocument()
    var parserFailure: String?
    var domainFailure: TMXLevelLoaderError?

    private var currentLayer: String?
    private var currentObject: TMXParsedObject?
    private var currentPropertyName: String?
    private var currentPropertyValue = ""
    private var currentPropertyTarget: PropertyTarget?
    private var propertyHasValueAttribute = false

    init(sourceName: String) {
        self.sourceName = sourceName
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "map":
            document.orientation = attributeDict["orientation"] ?? ""
            document.infinite = (attributeDict["infinite"] ?? "0") == "1"
            document.width = attributeDict["width"]
            document.height = attributeDict["height"]
            document.tileWidth = attributeDict["tilewidth"]
            document.tileHeight = attributeDict["tileheight"]

        case "objectgroup":
            currentLayer = attributeDict["name"] ?? ""

        case "object":
            let id = Int(attributeDict["id"] ?? "") ?? 0
            let className = TMXRoomSchema.objectClass(
                className: attributeDict["class"],
                legacyType: attributeDict["type"]
            )

            let x = finiteObjectAttribute("x", attributes: attributeDict, objectID: id, defaultValue: "0")
            let y = finiteObjectAttribute("y", attributes: attributeDict, objectID: id, defaultValue: "0")
            let width = finiteObjectAttribute("width", attributes: attributeDict, objectID: id, defaultValue: "0")
            let height = finiteObjectAttribute("height", attributes: attributeDict, objectID: id, defaultValue: "0")
            let rotation = finiteObjectAttribute("rotation", attributes: attributeDict, objectID: id, defaultValue: "0")

            if attributeDict["gid"] != nil {
                recordDomainFailure(
                    .invalidObjectGeometry(objectID: id, reason: "tile object geometry is unsupported")
                )
            }

            currentObject = TMXParsedObject(
                id: id,
                layer: currentLayer ?? "",
                objectType: className,
                x: x,
                y: y,
                width: width,
                height: height,
                rotation: rotation,
                isPoint: false,
                properties: [:]
            )

        case "point":
            currentObject?.isPoint = true

        case "ellipse", "polygon", "polyline":
            if let object = currentObject {
                recordDomainFailure(
                    .invalidObjectGeometry(
                        objectID: object.id,
                        reason: "\(elementName) geometry is unsupported"
                    )
                )
            }

        case "property":
            guard let name = attributeDict["name"], !name.isEmpty else { return }
            currentPropertyName = name
            currentPropertyValue = attributeDict["value"] ?? ""
            propertyHasValueAttribute = attributeDict["value"] != nil
            currentPropertyTarget = currentObject == nil ? .map : .object

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentPropertyName != nil, !propertyHasValueAttribute {
            currentPropertyValue += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "property":
            if let name = currentPropertyName, let target = currentPropertyTarget {
                let value = currentPropertyValue.trimmingCharacters(in: .whitespacesAndNewlines)
                switch target {
                case .map:
                    document.properties[name] = value
                case .object:
                    currentObject?.properties[name] = value
                }
            }
            currentPropertyName = nil
            currentPropertyValue = ""
            currentPropertyTarget = nil
            propertyHasValueAttribute = false

        case "object":
            if let object = currentObject {
                document.objects.append(object)
            }
            currentObject = nil

        case "objectgroup":
            currentLayer = nil

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parserFailure = parseError.localizedDescription
    }

    private func finiteObjectAttribute(
        _ name: String,
        attributes: [String: String],
        objectID: Int,
        defaultValue: String
    ) -> Double {
        let raw = attributes[name] ?? defaultValue
        guard let value = Double(raw), value.isFinite else {
            recordDomainFailure(
                .invalidObjectGeometry(
                    objectID: objectID,
                    reason: "\(name) must be a finite number (got \(raw))"
                )
            )
            return 0
        }
        return value
    }

    private func recordDomainFailure(_ error: TMXLevelLoaderError) {
        if domainFailure == nil {
            domainFailure = error
        }
    }
}
