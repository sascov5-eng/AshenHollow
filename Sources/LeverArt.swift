import Foundation
import SpriteKit
import UIKit

enum LeverArt {
    private static func makeTexture(_ b64: String) -> SKTexture {
        let data = Data(base64Encoded: b64, options: [.ignoreUnknownCharacters])!
        let image = UIImage(data: data)!
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static let baseTexture = makeTexture("""
iVBORw0KGgoAAAANSUhEUgAAAGAAAACACAYAAAD03Gy6AAAEA0lEQVR4nO3bv2tTURQH8FORDvIoRUoIRUIoHUoJHURKKRI6FHESB4dO4uRUHIs4dRJxlP4B4iAODuIk0qEEKSWIQymhg5QQSgklSIeHQ5c6hBtv3o++H7nvnnPb7wcKJn157/b8uPe+JBIBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACXMe4B5HGnXLqI+91x99Spv8mpwV4W+CBXEuHEIInCwd9anw8ds77VGnrsQhLED5BoOPhRgQ/SEyE9CTe4B5BED37z41qq1+hJyjJtcRBdHVGVv7i8QM3dffrUOA0dv1YvDT12oRNEDkpRCQhOO1HBV+KSIDUBYqeguKlDD/7Or+7gJ+r3ac7HTWwCFL36g8HXxSUhzaLNSXwCogSDn/S8ZE4m4CpBApg5mYCVu+VMz0smPgH6Xl7fYgaDrT/Wjwu+PSHNTe4BxDnuno5FbR3X6qXBLieq4oP3Afr5DA/RCPEdQBSu4rggX3YnLJXIqtBlfSNOceFtCCIHOkAPXtqKdiX4RA50ABHR3Gz1wvf/Dj2X5vMAz7tFh7/bov9G0YNT5marF0vzU7Td7KR+zepihfZaPSQgq42Xm6Gdz9fP72lpfooW5zwiInr9IX4qevW03xnNQ5/2Wj169ORZ6Ji3bzbF/N1it6FRmoc+EfWrO+kYV4hahPXqL5dLg59RRJ0nqsu4iEqAMmrQbZ93FGKmoKSq3Gv1jF9PwlogJgFKVJU+X98wev5uN/4jTdtETUG2pghJU5GIBHAtihIWYxEJILJflVK6gH0RklCFnIuxmA64rtg7gIjowcPHgy6oVquFX6/dbg/+/f3bF9YYiOoAG8G3eZ00RCXgOmJPgJp+VFV2Jrv00y/+o0R1PX364yDuTrhyVqaK597XS/Ji74AiNBo7oedsdVZWrAkITj9FqpyV6Z43/DGmhGnoSnaAS9gTUET11+srkdOQretnwZaA5furudo+bWCzyjueUbHtgjyv/wG7fleaVtrXZDm3Go9tLB2Qt9o6nTZVKlXDo/mPowvYOsD3+99emJ6ezvS6iYmJVMfVagt0cLBPtdpC4rEnJyeZxmAS6yKcJfhxwfRnzulofLT/mpS1CEyyngDTbe4djdPMubk7Z9vTEFsHcFZdFK7xWE1A3upKO5cHqXUgK5tdwNIB0qpf4RgX+51wkrzVr4zyWhusJUC1dbDKTOxiTFLjszUNsXdA0i7GdAVLS7jVBGSZY4sKVJptq821wEoC8rSz6f19HjamIWsdIHXnE8fWeAv/TgzX27wm7f7YLixO7IvwdSfim3HK7cmpF7au9ees987WtS4jKgFRTCRFSrBBoH9AVETdA7k5DgAAAABJRU5ErkJggg==
""")
    private static let handleTexture = makeTexture("""
iVBORw0KGgoAAAANSUhEUgAAACAAAABQCAYAAAB4WHc1AAABYElEQVR4nO2YsUoDQRCGJ+FKCwlXLMeVFmIRlpSp7kEsLH0C8RHE2gcIxAdJmXJREAtLkRRBLCwPL9WGJe65M5uVJeT/q+Vmd+bb2b1ZGKJj1yB2Ya3Kbvfb+2ot9ide4Au8D4gIwA3e6OqXfWE+xBDDVMF3v3MyRcTMQF/wm8vz7fj+8XU7lmRCBGCDzx+u6Xm58M61IBYiBBA8Al8q+4Jz14sArOzu3bT7ZO199yQa4L90eADubY+x7w2QWsHf8K8C1FcHiPi1IKoOcJSsDvicpprHBnB3EXIufZDYGeBAxLyGoudYlaOuKMLMbftDq/Vn2ufYqq4UNdOJ19ZMJ1RXSuSvkAK4wfT4grTWZIwh8/QS5Sd7IQIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAkB2A3apV5ag7PeH3Nb++W1a7Vtwpvbs6C865nb2x/WU/AgAAIDtA9joAQRCUXRsliYFsiJ8wVgAAAABJRU5ErkJggg==
""")

    static func node() -> SKNode {
        let root = SKNode()

        let base = SKSpriteNode(texture: baseTexture)
        base.size = CGSize(width: 96, height: 128)
        base.position = .zero
        base.zPosition = 1
        base.name = "leverBase"
        root.addChild(base)

        let glow = SKShapeNode(circleOfRadius: 18)
        glow.name = "leverGlow"
        glow.fillColor = UIColor(red: 0.28, green: 0.92, blue: 0.86, alpha: 0)
        glow.strokeColor = .clear
        glow.glowWidth = 10
        glow.position = CGPoint(x: 0, y: 14)
        glow.zPosition = 2
        root.addChild(glow)

        let handle = SKSpriteNode(texture: handleTexture)
        handle.name = "leverHandle"
        handle.size = CGSize(width: 32, height: 80)
        handle.anchorPoint = CGPoint(x: 0.5, y: 0.125)
        handle.position = CGPoint(x: 0, y: 14)
        handle.zRotation = -0.55
        handle.zPosition = 4
        root.addChild(handle)
        return root
    }
}
