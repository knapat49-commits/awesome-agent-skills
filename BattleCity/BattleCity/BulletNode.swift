import SpriteKit

class BulletNode: SKSpriteNode {

    enum BulletOwner {
        case player, enemy
    }

    let owner: BulletOwner
    let direction: Direction

    init(owner: BulletOwner, direction: Direction) {
        self.owner = owner
        self.direction = direction

        let color: SKColor = owner == .player ? .white : .orange
        super.init(texture: nil, color: color, size: CGSize(width: 6, height: 10))

        zRotation = direction.angle

        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = true
        body.allowsRotation = false
        body.linearDamping = 0
        body.angularDamping = 0
        body.restitution = 0
        body.usesPreciseCollisionDetection = true

        if owner == .player {
            body.categoryBitMask    = PhysicsCategory.playerBullet.rawValue
            body.contactTestBitMask = PhysicsCategory.enemyTank.rawValue |
                                      PhysicsCategory.brick.rawValue |
                                      PhysicsCategory.steel.rawValue |
                                      PhysicsCategory.base.rawValue
            body.collisionBitMask   = 0
        } else {
            body.categoryBitMask    = PhysicsCategory.enemyBullet.rawValue
            body.contactTestBitMask = PhysicsCategory.playerTank.rawValue |
                                      PhysicsCategory.brick.rawValue |
                                      PhysicsCategory.steel.rawValue |
                                      PhysicsCategory.base.rawValue
            body.collisionBitMask   = 0
        }

        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func launch(speed: CGFloat) {
        let velocity = CGVector(dx: direction.dx * speed, dy: direction.dy * speed)
        physicsBody?.velocity = velocity
    }
}
