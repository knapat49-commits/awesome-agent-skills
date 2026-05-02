import SpriteKit

enum PowerUpType: CaseIterable {
    case shield, grenade, clock, shovel, star, life

    var symbol: String {
        switch self {
        case .shield:  return "🛡"
        case .grenade: return "💣"
        case .clock:   return "⏰"
        case .shovel:  return "⛏"
        case .star:    return "⭐"
        case .life:    return "❤️"
        }
    }

    var color: SKColor {
        switch self {
        case .shield:  return .cyan
        case .grenade: return .red
        case .clock:   return .yellow
        case .shovel:  return .brown
        case .star:    return .yellow
        case .life:    return .red
        }
    }
}

class PowerUpNode: SKNode {

    let powerType: PowerUpType

    init(type: PowerUpType) {
        self.powerType = type
        super.init()

        let bg = SKShapeNode(rectOf: CGSize(width: 28, height: 28), cornerRadius: 6)
        bg.fillColor = type.color.withAlphaComponent(0.8)
        bg.strokeColor = .white
        bg.lineWidth = 2
        addChild(bg)

        let label = SKLabelNode(text: type.symbol)
        label.fontSize = 18
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 28, height: 28))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.powerUp.rawValue
        body.contactTestBitMask = PhysicsCategory.playerTank.rawValue
        body.collisionBitMask = 0
        physicsBody = body

        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.4),
            SKAction.fadeAlpha(to: 1.0, duration: 0.4)
        ])
        run(SKAction.repeatForever(blink))

        run(SKAction.sequence([
            SKAction.wait(forDuration: 10.0),
            SKAction.removeFromParent()
        ]))
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }
}
