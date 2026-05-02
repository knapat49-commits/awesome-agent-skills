import SpriteKit
import Foundation

class EnemyAI {
    private weak var tank: TankNode?
    private weak var gameScene: SKScene?
    private var directionChangeTimer: TimeInterval = 0
    private var directionChangeInterval: TimeInterval
    private var shootTimer: TimeInterval = 0
    private var shootInterval: TimeInterval
    private var currentSpeed: CGFloat
    private var isBlocked = false
    private var blockedTimer: TimeInterval = 0
    private let maxBlockedTime: TimeInterval = 0.5

    init(tank: TankNode, scene: SKScene) {
        self.tank = tank
        self.gameScene = scene

        switch tank.tankType {
        case .fastEnemy:
            currentSpeed = GameConfig.enemyTankSpeed * 1.8
            directionChangeInterval = 1.5
            shootInterval = GameConfig.enemyBulletCooldown * 0.8
        case .armoredEnemy:
            currentSpeed = GameConfig.enemyTankSpeed * 0.7
            directionChangeInterval = 3.0
            shootInterval = GameConfig.enemyBulletCooldown * 1.2
        default:
            currentSpeed = GameConfig.enemyTankSpeed
            directionChangeInterval = Double.random(in: 1.5...3.0)
            shootInterval = GameConfig.enemyBulletCooldown
        }
    }

    func update(delta: TimeInterval) -> (shouldShoot: Bool, newBulletDirection: Direction?) {
        guard let tank = tank else { return (false, nil) }

        directionChangeTimer += delta
        shootTimer += delta
        tank.animateTracks(delta: delta)

        // Check if blocked
        let speed = tank.physicsBody?.velocity ?? .zero
        if abs(speed.dx) < 5 && abs(speed.dy) < 5 {
            blockedTimer += delta
            if blockedTimer >= maxBlockedTime {
                isBlocked = true
                blockedTimer = 0
            }
        } else {
            blockedTimer = 0
            isBlocked = false
        }

        if directionChangeTimer >= directionChangeInterval || isBlocked {
            directionChangeTimer = 0
            isBlocked = false
            directionChangeInterval = Double.random(in: 1.5...4.0)
            chooseNewDirection()
        }

        tank.move(speed: currentSpeed)

        var shouldShoot = false
        if shootTimer >= shootInterval && tank.canShoot {
            shootTimer = 0
            shouldShoot = true
        }

        return (shouldShoot, shouldShoot ? tank.direction : nil)
    }

    private func chooseNewDirection() {
        guard let tank = tank, let scene = gameScene as? GameScene else { return }

        // 40% chance: aim toward base or player
        if Float.random(in: 0...1) < 0.4 {
            if let player = scene.playerTank {
                let dx = player.position.x - tank.position.x
                let dy = player.position.y - tank.position.y
                if abs(dx) > abs(dy) {
                    tank.setDirection(dx > 0 ? .right : .left)
                } else {
                    tank.setDirection(dy > 0 ? .up : .down)
                }
                return
            }
        }

        let directions: [Direction] = [.up, .down, .left, .right]
        tank.setDirection(directions.randomElement()!)
    }
}
