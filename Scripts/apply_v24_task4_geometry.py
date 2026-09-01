from pathlib import Path

path = Path("Sources/GameScene.swift")
text = path.read_text()

if "func replaceRoomGeometry(" in text:
    print("V24 room geometry integration already present")
    raise SystemExit(0)

old = '''    private func addPlatform(center: CGPoint, size: CGSize) {
        platformRects.append(
            CGRect(
                x: center.x - size.width * 0.5,
                y: center.y - size.height * 0.5,
                width: size.width,
                height: size.height
            )
        )

        let visual = SKShapeNode(rectOf: size, cornerRadius: 7)
        visual.fillColor = UIColor(red: 0.15, green: 0.17, blue: 0.21, alpha: 1)
        visual.strokeColor = UIColor(white: 0.42, alpha: 0.35)
        visual.lineWidth = 2
        visual.position = center
        visual.zPosition = 1
        worldRoot.addChild(visual)
    }
'''

new = '''    private func roomGeometryNode() -> SKNode {
        if let existing = worldRoot.childNode(withName: "roomGeometry") {
            return existing
        }

        let geometry = SKNode()
        geometry.name = "roomGeometry"
        worldRoot.addChild(geometry)
        return geometry
    }

    private func addPlatform(center: CGPoint, size: CGSize) {
        platformRects.append(
            CGRect(
                x: center.x - size.width * 0.5,
                y: center.y - size.height * 0.5,
                width: size.width,
                height: size.height
            )
        )

        let visual = SKShapeNode(rectOf: size, cornerRadius: 7)
        visual.fillColor = UIColor(red: 0.15, green: 0.17, blue: 0.21, alpha: 1)
        visual.strokeColor = UIColor(white: 0.42, alpha: 0.35)
        visual.lineWidth = 2
        visual.position = center
        visual.zPosition = 1
        roomGeometryNode().addChild(visual)
    }

    func replaceRoomGeometry(
        platforms: [RoomPlatform],
        roomWidth: CGFloat,
        roomHeight: CGFloat
    ) {
        platformRects.removeAll(keepingCapacity: true)

        let geometry = roomGeometryNode()
        geometry.removeAllChildren()

        for platform in platforms {
            let center = CGPoint(
                x: CGFloat(platform.center.x),
                y: CGFloat(platform.center.y)
            )
            let size = CGSize(
                width: CGFloat(platform.size.width),
                height: CGFloat(platform.size.height)
            )

            platformRects.append(
                CGRect(
                    x: center.x - size.width * 0.5,
                    y: center.y - size.height * 0.5,
                    width: size.width,
                    height: size.height
                )
            )

            let visual = SKShapeNode(rectOf: size, cornerRadius: 7)
            visual.fillColor = UIColor(red: 0.15, green: 0.17, blue: 0.21, alpha: 1)
            visual.strokeColor = UIColor(white: 0.42, alpha: 0.35)
            visual.lineWidth = 2
            visual.position = center
            visual.zPosition = 1
            geometry.addChild(visual)
        }

        worldWidth = max(roomWidth, colliderSize.width)
        _ = roomHeight
    }
'''

count = text.count(old)
if count != 1:
    raise RuntimeError(f"expected exactly one addPlatform block, found {count}")

path.write_text(text.replace(old, new, 1))
print("Applied V24 replaceable room geometry to GameScene.swift")
