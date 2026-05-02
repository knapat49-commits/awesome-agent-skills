import SpriteKit

protocol ControlsDelegate: AnyObject {
    func controlsDidChangeDirection(_ direction: Direction?)
    func controlsDidTapFire()
}

class ControlsNode: SKNode {

    weak var delegate: ControlsDelegate?

    private var dpadCenter: CGPoint = .zero
    private let dpadRadius: CGFloat = 60
    private let dpadInnerRadius: CGFloat = 22
    private var activeDpadTouch: UITouch?
    private var activeFireTouch: UITouch?
    private var fireButton: SKShapeNode!
    private var currentDirection: Direction?

    func setup(size: CGSize) {
        let margin: CGFloat = 30
        let bottomY = size.height * 0.14

        dpadCenter = CGPoint(x: margin + dpadRadius + 20, y: bottomY + 70)
        drawDpad()

        let firePos = CGPoint(x: size.width - margin - 50, y: bottomY + 70)
        drawFireButton(at: firePos)
    }

    private func drawDpad() {
        let bg = SKShapeNode(circleOfRadius: dpadRadius)
        bg.fillColor = SKColor(white: 1.0, alpha: 0.12)
        bg.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        bg.lineWidth = 2
        bg.position = dpadCenter
        bg.name = "dpadBg"
        addChild(bg)

        let arrowData: [(String, CGPoint)] = [
            ("▲", CGPoint(x: dpadCenter.x, y: dpadCenter.y + dpadRadius * 0.6)),
            ("▼", CGPoint(x: dpadCenter.x, y: dpadCenter.y - dpadRadius * 0.6)),
            ("◀", CGPoint(x: dpadCenter.x - dpadRadius * 0.6, y: dpadCenter.y)),
            ("▶", CGPoint(x: dpadCenter.x + dpadRadius * 0.6, y: dpadCenter.y)),
        ]
        for (sym, pos) in arrowData {
            let arrow = SKLabelNode(text: sym)
            arrow.fontSize = 22
            arrow.fontColor = SKColor(white: 1, alpha: 0.5)
            arrow.verticalAlignmentMode = .center
            arrow.horizontalAlignmentMode = .center
            arrow.position = pos
            addChild(arrow)
        }

        let center = SKShapeNode(circleOfRadius: dpadInnerRadius)
        center.fillColor = SKColor(white: 1.0, alpha: 0.15)
        center.strokeColor = .clear
        center.position = dpadCenter
        addChild(center)
    }

    private func drawFireButton(at pos: CGPoint) {
        let btn = SKShapeNode(circleOfRadius: 44)
        btn.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 0.75)
        btn.strokeColor = SKColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 0.9)
        btn.lineWidth = 3
        btn.position = pos
        btn.name = "fireButton"
        addChild(btn)
        fireButton = btn

        let fireLabel = SKLabelNode(text: "FIRE")
        fireLabel.fontName = "AvenirNext-Bold"
        fireLabel.fontSize = 18
        fireLabel.fontColor = .white
        fireLabel.verticalAlignmentMode = .center
        fireLabel.horizontalAlignmentMode = .center
        btn.addChild(fireLabel)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: self)
            if activeDpadTouch == nil && isDpadArea(loc) {
                activeDpadTouch = touch
                updateDpad(location: loc)
            } else if activeFireTouch == nil && isFireArea(loc) {
                activeFireTouch = touch
                delegate?.controlsDidTapFire()
                pulseFireButton()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == activeDpadTouch {
                updateDpad(location: touch.location(in: self))
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == activeDpadTouch {
                activeDpadTouch = nil
                currentDirection = nil
                delegate?.controlsDidChangeDirection(nil)
            }
            if touch == activeFireTouch {
                activeFireTouch = nil
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func isDpadArea(_ point: CGPoint) -> Bool {
        let dx = point.x - dpadCenter.x
        let dy = point.y - dpadCenter.y
        return sqrt(dx*dx + dy*dy) <= dpadRadius + 20
    }

    private func isFireArea(_ point: CGPoint) -> Bool {
        guard let btn = fireButton else { return false }
        let dx = point.x - btn.position.x
        let dy = point.y - btn.position.y
        return sqrt(dx*dx + dy*dy) <= 60
    }

    private func updateDpad(location: CGPoint) {
        let dx = location.x - dpadCenter.x
        let dy = location.y - dpadCenter.y
        let dist = sqrt(dx*dx + dy*dy)

        if dist < dpadInnerRadius {
            if currentDirection != nil {
                currentDirection = nil
                delegate?.controlsDidChangeDirection(nil)
            }
            return
        }

        let newDir: Direction
        if abs(dx) > abs(dy) {
            newDir = dx > 0 ? .right : .left
        } else {
            newDir = dy > 0 ? .up : .down
        }

        if newDir != currentDirection {
            currentDirection = newDir
            delegate?.controlsDidChangeDirection(newDir)
        }
    }

    private func pulseFireButton() {
        let pulse = SKAction.sequence([
            SKAction.scale(to: 0.9, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.08)
        ])
        fireButton.run(pulse)
    }

    func setUserInteractionEnabled() {
        isUserInteractionEnabled = true
    }
}
