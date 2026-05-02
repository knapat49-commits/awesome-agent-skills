import SpriteKit
import Foundation

class GameScene: SKScene, SKPhysicsContactDelegate, ControlsDelegate {

    // MARK: - Properties
    private(set) var playerTank: TankNode?
    private var enemyTanks: [TankNode] = []
    private var enemyAIs: [ObjectIdentifier: EnemyAI] = [:]
    private var bullets: [BulletNode] = []
    private var mapNode: MapNode!
    private var hudNode: HUDNode!
    private var controlsNode: ControlsNode!
    private var worldNode: SKNode!

    private var lives = 3
    private var score = 0
    private var level: Int
    private var enemiesRemaining: Int = GameConfig.totalEnemiesPerLevel
    private var enemiesOnScreen = 0
    private var playerBulletCooldownTimer: TimeInterval = 0
    private var isGameOver = false
    private var isLevelComplete = false
    private var playerMoveDirection: Direction?
    private var spawnIndex = 0
    private var powerUps: [PowerUpNode] = []
    private var isFrozen = false
    private var frozenTimer: TimeInterval = 0
    private let frozenDuration: TimeInterval = 8.0
    private var playerSpawning = false

    // MARK: - Init
    init(size: CGSize, level: Int) {
        self.level = level
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        setupWorld()
        setupHUD()
        setupControls()
        spawnPlayer()
        scheduleEnemySpawn()

        updateHUD()
    }

    // MARK: - Setup
    private func setupWorld() {
        worldNode = SKNode()
        addChild(worldNode)

        let levelIndex = (level - 1) % LevelData.levels.count
        let data = LevelData.levels[levelIndex]
        mapNode = MapNode(levelData: data, tileSize: GameConfig.tileSize)
        worldNode.addChild(mapNode)

        let mapWidth = CGFloat(mapNode.cols) * GameConfig.tileSize
        let mapHeight = CGFloat(mapNode.rows) * GameConfig.tileSize
        let offsetX = (size.width - mapWidth) / 2
        let offsetY = (size.height - mapHeight) / 2 + 30

        worldNode.position = CGPoint(x: offsetX, y: offsetY)
    }

    private func setupHUD() {
        hudNode = HUDNode()
        hudNode.zPosition = 100
        hudNode.setup(size: size)
        addChild(hudNode)
    }

    private func setupControls() {
        controlsNode = ControlsNode()
        controlsNode.zPosition = 200
        controlsNode.delegate = self
        controlsNode.setUserInteractionEnabled()
        controlsNode.setup(size: size)
        addChild(controlsNode)

        isUserInteractionEnabled = true
    }

    // MARK: - Player
    private func spawnPlayer(at spawnPos: CGPoint? = nil) {
        guard !playerSpawning else { return }
        playerSpawning = true

        let positions = mapNode.playerSpawnPositions
        let pos = spawnPos ?? (positions.first ?? CGPoint(x: GameConfig.tileSize * 6, y: GameConfig.tileSize))

        let worldPos = CGPoint(
            x: worldNode.position.x + pos.x,
            y: worldNode.position.y + pos.y
        )

        let tank = TankNode(type: .player)
        tank.position = worldPos
        tank.setDirection(.up)
        tank.zPosition = 5
        addChild(tank)
        playerTank = tank
        playerSpawning = false

        tank.showShield()
        showSpawnEffect(at: worldPos)
    }

    private func showSpawnEffect(at pos: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 5)
        ring.strokeColor = .yellow
        ring.lineWidth = 3
        ring.position = pos
        ring.zPosition = 20
        addChild(ring)

        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 5, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Enemy Spawning
    private func scheduleEnemySpawn() {
        let delay = enemyTanks.isEmpty ? 1.0 : GameConfig.enemyRespawnDelay
        run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.run { [weak self] in self?.trySpawnEnemy() }
        ]))
    }

    private func trySpawnEnemy() {
        guard !isGameOver && !isLevelComplete else { return }
        guard enemiesRemaining > 0 && enemiesOnScreen < GameConfig.maxEnemiesOnScreen else { return }

        let positions = mapNode.enemySpawnPositions
        guard !positions.isEmpty else { return }

        let spawnPos = positions[spawnIndex % positions.count]
        spawnIndex += 1

        let worldPos = CGPoint(
            x: worldNode.position.x + spawnPos.x,
            y: worldNode.position.y + spawnPos.y
        )

        let types: [TankNode.TankType] = [.basicEnemy, .basicEnemy, .basicEnemy, .fastEnemy, .armoredEnemy]
        let typeIndex = (GameConfig.totalEnemiesPerLevel - enemiesRemaining) % types.count
        let tankType = types[typeIndex]

        let tank = TankNode(type: tankType)
        tank.position = worldPos
        tank.setDirection(.down)
        tank.zPosition = 5
        addChild(tank)

        enemyTanks.append(tank)
        enemyAIs[ObjectIdentifier(tank)] = EnemyAI(tank: tank, scene: self)
        enemiesOnScreen += 1
        enemiesRemaining -= 1

        showSpawnEffect(at: worldPos)

        updateHUD()
        scheduleEnemySpawn()
    }

    // MARK: - Update
    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver && !isLevelComplete else { return }

        let delta = 1.0 / 60.0

        updatePlayerMovement()
        updatePlayerCooldown(delta: delta)
        updateEnemies(delta: delta)
        updateFrozenTimer(delta: delta)
        cleanupOffscreenBullets()

        if enemiesRemaining == 0 && enemiesOnScreen == 0 {
            triggerLevelComplete()
        }
    }

    private func updatePlayerMovement() {
        guard let player = playerTank else { return }
        if let dir = playerMoveDirection {
            if player.direction != dir {
                player.setDirection(dir)
            }
            player.move(speed: GameConfig.playerTankSpeed)
            player.animateTracks(delta: 1.0/60.0)
        } else {
            player.stop()
        }
    }

    private func updatePlayerCooldown(delta: TimeInterval) {
        if playerBulletCooldownTimer > 0 {
            playerBulletCooldownTimer -= delta
        }
    }

    private func updateEnemies(delta: TimeInterval) {
        guard !isFrozen else {
            for tank in enemyTanks { tank.stop() }
            return
        }

        for tank in enemyTanks {
            let ai = enemyAIs[ObjectIdentifier(tank)]
            if let result = ai?.update(delta: delta), result.shouldShoot {
                if let dir = result.newBulletDirection {
                    fireBullet(from: tank, direction: dir, isPlayer: false)
                }
            }
        }
    }

    private func updateFrozenTimer(delta: TimeInterval) {
        guard isFrozen else { return }
        frozenTimer += delta
        if frozenTimer >= frozenDuration {
            isFrozen = false
            frozenTimer = 0
        }
    }

    private func cleanupOffscreenBullets() {
        let expanded = frame.insetBy(dx: -100, dy: -100)
        bullets = bullets.filter { bullet in
            if !expanded.contains(bullet.position) {
                bullet.removeFromParent()
                return false
            }
            return true
        }
    }

    // MARK: - Controls Delegate
    func controlsDidChangeDirection(_ direction: Direction?) {
        playerMoveDirection = direction
    }

    func controlsDidTapFire() {
        guard let player = playerTank, playerBulletCooldownTimer <= 0 else { return }
        fireBullet(from: player, direction: player.direction, isPlayer: true)
        playerBulletCooldownTimer = GameConfig.playerBulletCooldown
    }

    // MARK: - Bullets
    private func fireBullet(from tank: TankNode, direction: Direction, isPlayer: Bool) {
        let owner: BulletNode.BulletOwner = isPlayer ? .player : .enemy
        let bullet = BulletNode(owner: owner, direction: direction)
        let spawnPos = tank.bulletSpawnPosition()
        bullet.position = spawnPos
        bullet.zPosition = 8
        addChild(bullet)
        bullets.append(bullet)

        let speed: CGFloat = isPlayer ? GameConfig.playerBulletSpeed : GameConfig.enemyBulletSpeed
        bullet.launch(speed: speed)

        let flash = SKShapeNode(circleOfRadius: 8)
        flash.fillColor = isPlayer ? .white : .orange
        flash.strokeColor = .clear
        flash.position = spawnPos
        flash.zPosition = 9
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.08),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Physics Contact
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB

        handleContact(bodyA: a, bodyB: b, contactPoint: contact.contactPoint)
    }

    private func handleContact(bodyA: SKPhysicsBody, bodyB: SKPhysicsBody, contactPoint: CGPoint) {
        let catA = bodyA.categoryBitMask
        let catB = bodyB.categoryBitMask

        let playerBullet = PhysicsCategory.playerBullet.rawValue
        let enemyBullet  = PhysicsCategory.enemyBullet.rawValue
        let playerTankCat = PhysicsCategory.playerTank.rawValue
        let enemyTankCat  = PhysicsCategory.enemyTank.rawValue
        let brickCat = PhysicsCategory.brick.rawValue
        let steelCat = PhysicsCategory.steel.rawValue
        let baseCat  = PhysicsCategory.base.rawValue
        let powerUpCat = PhysicsCategory.powerUp.rawValue
        let borderCat = PhysicsCategory.border.rawValue

        func bullet(from bodies: (SKPhysicsBody, SKPhysicsBody), cat: UInt32) -> BulletNode? {
            if bodies.0.categoryBitMask == cat { return bodies.0.node as? BulletNode }
            if bodies.1.categoryBitMask == cat { return bodies.1.node as? BulletNode }
            return nil
        }

        func other(from bodies: (SKPhysicsBody, SKPhysicsBody), cat: UInt32) -> SKNode? {
            if bodies.0.categoryBitMask == cat { return bodies.1.node }
            if bodies.1.categoryBitMask == cat { return bodies.0.node }
            return nil
        }

        // Player bullet hits enemy
        if (catA == playerBullet || catB == playerBullet) && (catA == enemyTankCat || catB == enemyTankCat) {
            if let b = bullet(from: (bodyA, bodyB), cat: playerBullet),
               let tank = other(from: (bodyA, bodyB), cat: enemyTankCat) as? TankNode {
                destroyBullet(b, at: contactPoint)
                hitEnemyTank(tank, at: contactPoint)
            }
        }

        // Enemy bullet hits player
        else if (catA == enemyBullet || catB == enemyBullet) && (catA == playerTankCat || catB == playerTankCat) {
            if let b = bullet(from: (bodyA, bodyB), cat: enemyBullet),
               let tank = other(from: (bodyA, bodyB), cat: playerTankCat) as? TankNode {
                destroyBullet(b, at: contactPoint)
                hitPlayerTank(tank)
            }
        }

        // Any bullet hits brick
        else if (catA == playerBullet || catB == playerBullet || catA == enemyBullet || catB == enemyBullet)
                && (catA == brickCat || catB == brickCat) {
            let bulletCat: UInt32 = catA == playerBullet || catA == enemyBullet ? catA : catB
            if let b = bullet(from: (bodyA, bodyB), cat: bulletCat) {
                destroyBullet(b, at: contactPoint)
                let localPos = mapNode.convert(contactPoint, from: self)
                mapNode.destroyBrick(at: localPos)
                showHitEffect(at: contactPoint, color: .orange)
            }
        }

        // Any bullet hits steel
        else if (catA == playerBullet || catB == playerBullet || catA == enemyBullet || catB == enemyBullet)
                && (catA == steelCat || catB == steelCat) {
            let bulletCat: UInt32 = catA == playerBullet || catA == enemyBullet ? catA : catB
            if let b = bullet(from: (bodyA, bodyB), cat: bulletCat) {
                destroyBullet(b, at: contactPoint)
                showHitEffect(at: contactPoint, color: .gray)
            }
        }

        // Any bullet hits base
        else if (catA == playerBullet || catB == playerBullet || catA == enemyBullet || catB == enemyBullet)
                && (catA == baseCat || catB == baseCat) {
            let bulletCat: UInt32 = catA == playerBullet || catA == enemyBullet ? catA : catB
            if let b = bullet(from: (bodyA, bodyB), cat: bulletCat) {
                destroyBullet(b, at: contactPoint)
                triggerGameOver(message: "BASE DESTROYED!")
            }
        }

        // Bullet hits border
        else if (catA == playerBullet || catB == playerBullet || catA == enemyBullet || catB == enemyBullet)
                && (catA == borderCat || catB == borderCat) {
            let bulletCat: UInt32 = catA == playerBullet || catA == enemyBullet ? catA : catB
            if let b = bullet(from: (bodyA, bodyB), cat: bulletCat) {
                destroyBullet(b, at: contactPoint)
            }
        }

        // Player picks up power-up
        else if (catA == playerTankCat || catB == playerTankCat) && (catA == powerUpCat || catB == powerUpCat) {
            if let pu = (catA == powerUpCat ? bodyA.node : bodyB.node) as? PowerUpNode {
                collectPowerUp(pu)
            }
        }
    }

    // MARK: - Combat
    private func destroyBullet(_ bullet: BulletNode, at point: CGPoint) {
        bullet.physicsBody = nil
        bullet.removeFromParent()
        bullets.removeAll { $0 === bullet }
    }

    private func hitEnemyTank(_ tank: TankNode, at point: CGPoint) {
        if tank.hit() {
            destroyEnemyTank(tank, at: point)
        } else {
            showHitEffect(at: point, color: .red)
        }
    }

    private func destroyEnemyTank(_ tank: TankNode, at point: CGPoint) {
        enemyAIs.removeValue(forKey: ObjectIdentifier(tank))
        enemyTanks.removeAll { $0 === tank }
        enemiesOnScreen -= 1

        let scoreGain: Int
        switch tank.tankType {
        case .basicEnemy: scoreGain = 100
        case .fastEnemy:  scoreGain = 200
        case .armoredEnemy: scoreGain = 400
        default: scoreGain = 100
        }
        score += scoreGain
        hudNode.updateScore(score)
        hudNode.showMessage("+\(scoreGain)", at: convert(point, from: self), color: .yellow)

        if Int.random(in: 0..<5) == 0 {
            spawnPowerUp(near: point)
        }

        tank.explode {
            // cleanup done by removeFromParent in explode
        }
        updateHUD()
    }

    private func hitPlayerTank(_ tank: TankNode) {
        guard !tank.isInvincible else { return }

        tank.explode { [weak self] in
            self?.playerTank = nil
            self?.loseLife()
        }
    }

    private func loseLife() {
        lives -= 1
        hudNode.updateLives(lives)

        if lives <= 0 {
            triggerGameOver(message: "GAME OVER")
        } else {
            run(SKAction.sequence([
                SKAction.wait(forDuration: 1.5),
                SKAction.run { [weak self] in self?.spawnPlayer() }
            ]))
        }
    }

    // MARK: - Power-Ups
    private func spawnPowerUp(near point: CGPoint) {
        let type = PowerUpType.allCases.randomElement()!
        let pu = PowerUpNode(type: type)
        pu.position = point
        pu.zPosition = 6
        addChild(pu)
        powerUps.append(pu)
    }

    private func collectPowerUp(_ pu: PowerUpNode) {
        pu.removeFromParent()
        powerUps.removeAll { $0 === pu }
        score += 500
        hudNode.updateScore(score)

        switch pu.powerType {
        case .shield:
            playerTank?.showShield()
            hudNode.showMessage("SHIELD!", at: CGPoint(x: size.width/2, y: size.height/2), color: .cyan)

        case .grenade:
            destroyAllEnemies()
            hudNode.showMessage("BOOM!", at: CGPoint(x: size.width/2, y: size.height/2), color: .orange)

        case .clock:
            isFrozen = true
            frozenTimer = 0
            hudNode.showMessage("FREEZE!", at: CGPoint(x: size.width/2, y: size.height/2), color: .white)
            showFreezeEffect()

        case .star:
            playerBulletCooldownTimer = 0
            hudNode.showMessage("RAPID FIRE!", at: CGPoint(x: size.width/2, y: size.height/2), color: .yellow)
            run(SKAction.sequence([
                SKAction.wait(forDuration: 0.0),
                SKAction.run { [weak self] in
                    // Apply reduced cooldown temporarily
                }
            ]))

        case .life:
            lives += 1
            hudNode.updateLives(lives)
            hudNode.showMessage("1-UP!", at: CGPoint(x: size.width/2, y: size.height/2), color: .green)

        case .shovel:
            fortifyBase()
            hudNode.showMessage("BASE FORTIFIED!", at: CGPoint(x: size.width/2, y: size.height/2), color: .brown)
        }
    }

    private func destroyAllEnemies() {
        let toDestroy = enemyTanks
        for tank in toDestroy {
            destroyEnemyTank(tank, at: tank.position)
        }
    }

    private func showFreezeEffect() {
        let overlay = SKSpriteNode(color: SKColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 0.15),
                                   size: size)
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)
        overlay.zPosition = 50
        overlay.name = "freezeOverlay"
        addChild(overlay)

        overlay.run(SKAction.sequence([
            SKAction.wait(forDuration: frozenDuration),
            SKAction.removeFromParent()
        ]))
    }

    private func fortifyBase() {
        // Add steel around base positions
        for pos in mapNode.playerSpawnPositions {
            let worldPos = CGPoint(x: worldNode.position.x + pos.x, y: worldNode.position.y + pos.y - GameConfig.tileSize)
            let steel = SKSpriteNode(color: SKColor(red: 0.7, green: 0.7, blue: 0.8, alpha: 1),
                                     size: CGSize(width: GameConfig.tileSize, height: GameConfig.tileSize))
            steel.position = worldPos
            steel.zPosition = 4
            let body = SKPhysicsBody(rectangleOf: steel.size)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.steel.rawValue
            body.contactTestBitMask = PhysicsCategory.playerBullet.rawValue | PhysicsCategory.enemyBullet.rawValue
            body.collisionBitMask = PhysicsCategory.playerTank.rawValue | PhysicsCategory.enemyTank.rawValue
            steel.physicsBody = body
            addChild(steel)

            steel.run(SKAction.sequence([
                SKAction.wait(forDuration: 15.0),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Effects
    private func showHitEffect(at point: CGPoint, color: SKColor) {
        for _ in 0..<6 {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            spark.fillColor = color
            spark.strokeColor = .clear
            spark.position = point
            spark.zPosition = 30
            addChild(spark)

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 10...30)
            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(by: CGVector(dx: cos(angle)*dist, dy: sin(angle)*dist), duration: 0.3),
                    SKAction.fadeOut(withDuration: 0.3)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Game Flow
    private func triggerLevelComplete() {
        guard !isLevelComplete && !isGameOver else { return }
        isLevelComplete = true

        score += 1000
        hudNode.updateScore(score)

        let banner = SKLabelNode(text: "STAGE CLEAR!")
        banner.fontName = "AvenirNext-Bold"
        banner.fontSize = 40
        banner.fontColor = .yellow
        banner.position = CGPoint(x: size.width/2, y: size.height/2)
        banner.zPosition = 200
        addChild(banner)

        banner.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.3, duration: 0.3),
                SKAction.scale(to: 1.0, duration: 0.2)
            ]),
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                let nextScene = GameScene(size: self.size, level: self.level + 1)
                nextScene.scaleMode = .aspectFill
                let transition = SKTransition.fade(withDuration: 0.5)
                self.view?.presentScene(nextScene, transition: transition)
            }
        ]))
    }

    private func triggerGameOver(message: String) {
        guard !isGameOver else { return }
        isGameOver = true
        playerTank?.removeFromParent()
        playerTank = nil

        let overlay = SKSpriteNode(color: SKColor(red: 0, green: 0, blue: 0, alpha: 0.6), size: size)
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)
        overlay.zPosition = 150
        addChild(overlay)

        let gameOverLabel = SKLabelNode(text: message)
        gameOverLabel.fontName = "AvenirNext-Bold"
        gameOverLabel.fontSize = 42
        gameOverLabel.fontColor = .red
        gameOverLabel.position = CGPoint(x: size.width/2, y: size.height/2 + 40)
        gameOverLabel.zPosition = 160
        addChild(gameOverLabel)

        let scoreLabel = SKLabelNode(text: "SCORE: \(score)")
        scoreLabel.fontName = "AvenirNext-Medium"
        scoreLabel.fontSize = 26
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width/2, y: size.height/2)
        scoreLabel.zPosition = 160
        addChild(scoreLabel)

        let tapLabel = SKLabelNode(text: "Tap to return to menu")
        tapLabel.fontName = "AvenirNext-Medium"
        tapLabel.fontSize = 20
        tapLabel.fontColor = .gray
        tapLabel.position = CGPoint(x: size.width/2, y: size.height/2 - 50)
        tapLabel.zPosition = 160
        tapLabel.name = "menuButton"
        addChild(tapLabel)

        let blink = SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.6),
            SKAction.fadeIn(withDuration: 0.6)
        ])
        tapLabel.run(SKAction.repeatForever(blink))

        gameOverLabel.run(SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.2)
        ]))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isGameOver else { return }
        let menu = MenuScene(size: size)
        menu.scaleMode = .aspectFill
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(menu, transition: transition)
    }

    // MARK: - HUD
    private func updateHUD() {
        hudNode.updateLives(lives)
        hudNode.updateEnemies(enemiesRemaining + enemiesOnScreen)
        hudNode.updateLevel(level)
        hudNode.updateScore(score)
    }
}
