import SpriteKit

class MenuScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupUI()
    }

    private func setupUI() {
        let title = SKLabelNode(text: "BATTLE CITY")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 48
        title.fontColor = .yellow
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.65)
        addChild(title)

        let subtitle = SKLabelNode(text: "TANK COMMANDER")
        subtitle.fontName = "AvenirNext-Medium"
        subtitle.fontSize = 20
        subtitle.fontColor = .white
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.57)
        addChild(subtitle)

        let tapLabel = SKLabelNode(text: "TAP TO START")
        tapLabel.fontName = "AvenirNext-Bold"
        tapLabel.fontSize = 28
        tapLabel.fontColor = .green
        tapLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.38)
        tapLabel.name = "startButton"
        addChild(tapLabel)

        let blink = SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.6),
            SKAction.fadeIn(withDuration: 0.6)
        ])
        tapLabel.run(SKAction.repeatForever(blink))

        drawTankDecoration()
    }

    private func drawTankDecoration() {
        let tank = makeTankSprite(color: .green)
        tank.position = CGPoint(x: size.width / 2, y: size.height * 0.5)
        tank.setScale(2.5)
        addChild(tank)
    }

    private func makeTankSprite(color: SKColor) -> SKNode {
        let node = SKNode()

        let body = SKSpriteNode(color: color, size: CGSize(width: 24, height: 26))
        node.addChild(body)

        let barrel = SKSpriteNode(color: color, size: CGSize(width: 6, height: 14))
        barrel.position = CGPoint(x: 0, y: 18)
        node.addChild(barrel)

        let leftTrack = SKSpriteNode(color: color.withAlphaComponent(0.7), size: CGSize(width: 6, height: 28))
        leftTrack.position = CGPoint(x: -15, y: 0)
        node.addChild(leftTrack)

        let rightTrack = SKSpriteNode(color: color.withAlphaComponent(0.7), size: CGSize(width: 6, height: 28))
        rightTrack.position = CGPoint(x: 15, y: 0)
        node.addChild(rightTrack)

        return node
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = self.nodes(at: location)

        if nodes.contains(where: { $0.name == "startButton" }) || true {
            let gameScene = GameScene(size: size, level: 1)
            gameScene.scaleMode = .aspectFill
            let transition = SKTransition.fade(withDuration: 0.5)
            view?.presentScene(gameScene, transition: transition)
        }
    }
}
