import SpriteKit
import UIKit

final class GameScene: SKScene {
    private let tuning = PlayerMovementTuning.current

    private let player = SKShapeNode(rectOf: CGSize(width: 42, height: 64), cornerRadius: 10)
    private let playerVisual = SKNode()
    private var playerSprite: SKSpriteNode?
    private var animationLibrary = PlayerAnimationLibrary()
    private var currentAnimation: PlayerAnimationKey?
    private var activeAttackAnimation: PlayerAnimationKey = .attack1
    private var useSecondAttack = false

    private let gameCamera = SKCameraNode()
    private let hud = SKNode()
    private var platformRects: [CGRect] = []
    private var worldWidth: CGFloat = 2200

    private var velocity = CGVector.zero
    private var moveInput: CGFloat = 0
    private var targetMoveInput: CGFloat = 0
    private var facing: CGFloat = 1
    private var isGrounded = false
    private var jumpHeld = false
    private var coyoteTimer: TimeInterval = 0
    private var jumpBufferTimer: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0

    private let audio = GameAudio()
    private var dashController = DashController()
    private var wallController = WallTraversalController()
    private var attackController = AttackController()
    private var essenceController = EssenceFocusController()
    private var currentHP = 5
    private let maxHP = 5
    private var currentWallCling: WallSide?

    private let cameraZoom: CGFloat = 1.55
    private let cameraFollowSpeed: CGFloat = 4.2
    private let cameraLookAhead: CGFloat = 120
    private let cameraVerticalOffset: CGFloat = 22

    private let leftButton = SKShapeNode(circleOfRadius: 43)
    private let rightButton = SKShapeNode(circleOfRadius: 43)
    private let jumpButton = SKShapeNode(circleOfRadius: 51)
    private let attackButton = SKShapeNode(circleOfRadius: 44)
    private let dashButton = SKShapeNode(circleOfRadius: 44)
    private let healButton = SKShapeNode(circleOfRadius: 40)

    private let leftArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let rightArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let jumpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let attackLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let dashLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let healLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var leftTouches = Set<ObjectIdentifier>()
    private var rightTouches = Set<ObjectIdentifier>()
    private var jumpTouches = Set<ObjectIdentifier>()

    private var colliderSize: CGSize {
        CGSize(width: CGFloat(tuning.colliderWidth), height: CGFloat(tuning.colliderHeight))
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.025, green: 0.03, blue: 0.045, alpha: 1)
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = false
        view.isMultipleTouchEnabled = true

        buildWorld()
        buildPlayer()
        buildCamera()
        buildHUD()
        layoutHUD()
        audio.prepare()

        isGrounded = isStandingOnSurface()
        coyoteTimer = isGrounded ? tuning.coyoteDuration : 0
    }
