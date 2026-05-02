import SpriteKit

class TankNode: SKNode {

    enum TankType {
        case player, basicEnemy, fastEnemy, armoredEnemy
    }

    let tankType: TankType
    var direction: Direction = .up
    var health: Int
    var canShoot = true
    var isInvincible = false

    private let bodyNode: SKSpriteNode
    private let barrelNode: SKSpriteNode
    private let leftTrack: SKSpriteNode
    private let rightTrack: SKSpriteNode
    private var shieldNode: SKShapeNode?
    private var animTimer: TimeInterval = 0

    var physicsSize: CGSize {
        return CGSize(width: GameConfig.tileSize - 4, height: GameConfig.tileSize - 4)
    }

    init(type: TankType) {
        self.tankType = type

        let bodyColor: SKColor
        let trackColor: SKColor
        switch type {
        case .player:
            bodyColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)
            trackColor = SKColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1)
            health = 1
        case .basicEnemy:
            bodyColor = SKColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 1)
            trackColor = SKColor(red: 0.5, green: 0.35, blue: 0.0, alpha: 1)
            health = 1
        case .fastEnemy:
            bodyColor = SKColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
            trackColor = SKColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
            health = 1
        case .armoredEnemy:
            bodyColor = SKColor(red: 0.7, green: 0.3, blue: 0.3, alpha: 1)
            trackColor = SKColor(red: 0.4, green: 0.1, blue: 0.1, alpha: 1)
            health = 3
        }

        bodyNode = SKSpriteNode(color: bodyColor, size: CGSize(width: 20, height: 22))
        barrelNode = SKSpriteNode(color: bodyColor, size: CGSize(width: 5, height: 12))
        leftTrack = SKSpriteNode(color: trackColor, size: CGSize(width: 5, height: 24))
        rightTrack = SKSpriteNode(color: trackColor, size: CGSize(width: 5, height: 24))

        super.init()

        leftTrack.position = CGPoint(x: -13, y: 0)
        rightTrack.position = CGPoint(x: 13, y: 0)
        barrelNode.position = CGPoint(x: 0, y: 15)

        addChild(leftTrack)
        addChild(rightTrack)
        addChild(bodyNode)
        addChild(barrelNode)

        setupPhysics()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func setupPhysics() {
        let body = SKPhysicsBody(rectangleOf: physicsSize)
        body.isDynamic = true
        body.allowsRotation = false
        body.linearDamping = 10
        body.angularDamping = 10
        body.restitution = 0

        switch tankType {
        case .player:
            body.categoryBitMask    = PhysicsCategory.playerTank.rawValue
            body.contactTestBitMask = PhysicsCategory.enemyBullet.rawValue |
                                      PhysicsCategory.powerUp.rawValue
            body.collisionBitMask   = PhysicsCategory.brick.rawValue |
                                      PhysicsCategory.steel.rawValue |
                                      PhysicsCategory.water.rawValue |
                                      PhysicsCategory.enemyTank.rawValue |
                                      PhysicsCategory.border.rawValue
        default:
            body.categoryBitMask    = PhysicsCategory.enemyTank.rawValue
            body.contactTestBitMask = PhysicsCategory.playerBullet.rawValue
            body.collisionBitMask   = PhysicsCategory.brick.rawValue |
                                      PhysicsCategory.steel.rawValue |
                                      PhysicsCategory.water.rawValue |
                                      PhysicsCategory.playerTank.rawValue |
                                      PhysicsCategory.enemyTank.rawValue |
                                      PhysicsCategory.border.rawValue
        }

        physicsBody = body
    }

    func setDirection(_ dir: Direction) {
        direction = dir
        zRotation = dir.angle
    }

    func move(speed: CGFloat) {
        let velocity = CGVector(dx: direction.dx * speed, dy: direction.dy * speed)
        physicsBody?.velocity = velocity
    }

    func stop() {
        physicsBody?.velocity = .zero
    }

    func animateTracks(delta: TimeInterval) {
        animTimer += delta
        if animTimer > 0.1 {
            animTimer = 0
            let offset: CGFloat = leftTrack.position.y == 0 ? 2 : 0
            leftTrack.position.y = offset
            rightTrack.position.y = -offset
        }
    }

    func bulletSpawnPosition() -> CGPoint {
        let offset: CGFloat = 18
        return CGPoint(
            x: position.x + direction.dx * offset,
            y: position.y + direction.dy * offset
        )
    }

    func hit() -> Bool {
        health -= 1
        if health <= 0 {
            return true
        }
        // Flash red for armored tanks
        let flash = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 1, duration: 0.1),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
        ])
        bodyNode.run(flash)
        return false
    }

    func showShield() {
        isInvincible = true
        let shield = SKShapeNode(circleOfRadius: 20)
        shield.strokeColor = .cyan
        shield.lineWidth = 2
        shield.alpha = 0.8
        shield.name = "shield"
        addChild(shield)
        shieldNode = shield

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        shield.run(SKAction.repeatForever(pulse))

        run(SKAction.sequence([
            SKAction.wait(forDuration: 5.0),
            SKAction.run { [weak self] in
                self?.removeShield()
            }
        ]))
    }

    func removeShield() {
        isInvincible = false
        shieldNode?.removeFromParent()
        shieldNode = nil
    }

    func explode(completion: @escaping () -> Void) {
        physicsBody = nil
        isUserInteractionEnabled = false

        let explosion = SKEmitterNode()
        let particleCount = 20
        var particles: [SKShapeNode] = []
        for _ in 0..<particleCount {
            let p = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...6))
            p.fillColor = [SKColor.orange, SKColor.red, SKColor.yellow].randomElement()!
            p.strokeColor = .clear
            addChild(p)
            particles.append(p)
        }

        _ = explosion

        for p in particles {
            let dx = CGFloat.random(in: -60...60)
            let dy = CGFloat.random(in: -60...60)
            let move = SKAction.move(by: CGVector(dx: dx, dy: dy), duration: 0.5)
            let fade = SKAction.fadeOut(withDuration: 0.5)
            p.run(SKAction.group([move, fade]))
        }

        let bigFlash = SKShapeNode(circleOfRadius: 30)
        bigFlash.fillColor = .yellow
        bigFlash.strokeColor = .orange
        bigFlash.alpha = 0.9
        addChild(bigFlash)

        bigFlash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.2),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ]))

        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.6),
            SKAction.run(completion),
            SKAction.removeFromParent()
        ]))
    }
}
