import SpriteKit

class HUDNode: SKNode {

    private var livesLabel: SKLabelNode!
    private var enemiesLabel: SKLabelNode!
    private var levelLabel: SKLabelNode!
    private var scoreLabel: SKLabelNode!
    private var scoreValueLabel: SKLabelNode!

    func setup(size: CGSize) {
        let bg = SKSpriteNode(color: SKColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.85),
                              size: CGSize(width: size.width, height: 52))
        bg.position = CGPoint(x: size.width / 2, y: 26)
        bg.zPosition = -1
        addChild(bg)

        let margin: CGFloat = 12
        let y: CGFloat = 26

        livesLabel = makeLabel(text: "❤️ 3", fontSize: 18)
        livesLabel.position = CGPoint(x: margin + 30, y: y)
        addChild(livesLabel)

        scoreLabel = makeLabel(text: "SCORE", fontSize: 13)
        scoreLabel.position = CGPoint(x: size.width / 2, y: y + 10)
        addChild(scoreLabel)

        scoreValueLabel = makeLabel(text: "0", fontSize: 20)
        scoreValueLabel.position = CGPoint(x: size.width / 2, y: y - 10)
        addChild(scoreValueLabel)

        enemiesLabel = makeLabel(text: "🎯 20", fontSize: 18)
        enemiesLabel.position = CGPoint(x: size.width - margin - 40, y: y)
        addChild(enemiesLabel)

        levelLabel = makeLabel(text: "LV 1", fontSize: 16)
        levelLabel.position = CGPoint(x: size.width - margin - 30, y: y - 14)
        levelLabel.alpha = 0.7
        addChild(levelLabel)
    }

    private func makeLabel(text: String, fontSize: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        return label
    }

    func updateLives(_ lives: Int) {
        livesLabel.text = "❤️ \(lives)"
    }

    func updateEnemies(_ count: Int) {
        enemiesLabel.text = "🎯 \(count)"
    }

    func updateLevel(_ level: Int) {
        levelLabel.text = "LV \(level)"
    }

    func updateScore(_ score: Int) {
        scoreValueLabel.text = "\(score)"

        let pop = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1)
        ])
        scoreValueLabel.run(pop)
    }

    func showMessage(_ text: String, at position: CGPoint, color: SKColor = .yellow) {
        let label = makeLabel(text: text, fontSize: 22)
        label.fontColor = color
        label.position = position
        label.zPosition = 50
        parent?.addChild(label)

        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 40, duration: 0.8),
                SKAction.fadeOut(withDuration: 0.8)
            ]),
            SKAction.removeFromParent()
        ]))
    }
}
