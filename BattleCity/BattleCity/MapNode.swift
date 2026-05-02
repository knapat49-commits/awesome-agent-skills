import SpriteKit

class MapNode: SKNode {

    let cols: Int
    let rows: Int
    let tileSize: CGFloat
    private(set) var tiles: [[TileType]]
    private var tileNodes: [[SKNode?]]

    init(levelData: [[Int]], tileSize: CGFloat) {
        self.rows = levelData.count
        self.cols = levelData[0].count
        self.tileSize = tileSize

        tiles = levelData.map { row in row.map { TileType(rawValue: $0) ?? .empty } }
        tileNodes = Array(repeating: Array(repeating: nil, count: cols), count: rows)

        super.init()
        buildMap()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func buildMap() {
        for row in 0..<rows {
            for col in 0..<cols {
                let type = tiles[row][col]
                if type == .empty || type == .playerSpawn || type == .enemySpawn {
                    continue
                }
                let node = makeTileNode(type: type, row: row, col: col)
                if let node = node {
                    addChild(node)
                    tileNodes[row][col] = node
                }
            }
        }
        addBorders()
    }

    private func makeTileNode(type: TileType, row: Int, col: Int) -> SKNode? {
        let pos = tilePosition(col: col, row: row)

        switch type {
        case .brick:
            let node = BrickNode(tileSize: tileSize)
            node.position = pos
            return node

        case .steel:
            let node = SKSpriteNode(color: SKColor(red: 0.7, green: 0.7, blue: 0.8, alpha: 1),
                                    size: CGSize(width: tileSize, height: tileSize))
            node.position = pos
            node.name = "steel_\(row)_\(col)"
            let body = SKPhysicsBody(rectangleOf: CGSize(width: tileSize, height: tileSize))
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.steel.rawValue
            body.contactTestBitMask = PhysicsCategory.playerBullet.rawValue | PhysicsCategory.enemyBullet.rawValue
            body.collisionBitMask = PhysicsCategory.playerTank.rawValue | PhysicsCategory.enemyTank.rawValue
            node.physicsBody = body
            addSteelPattern(to: node)
            return node

        case .water:
            let node = SKSpriteNode(color: SKColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1),
                                    size: CGSize(width: tileSize, height: tileSize))
            node.position = pos
            let body = SKPhysicsBody(rectangleOf: CGSize(width: tileSize, height: tileSize))
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.water.rawValue
            body.contactTestBitMask = 0
            body.collisionBitMask = PhysicsCategory.playerTank.rawValue | PhysicsCategory.enemyTank.rawValue
            node.physicsBody = body
            animateWater(node: node)
            return node

        case .forest:
            let node = SKSpriteNode(color: SKColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 0.85),
                                    size: CGSize(width: tileSize, height: tileSize))
            node.position = pos
            node.zPosition = 10
            return node

        case .base:
            let node = BaseNode(tileSize: tileSize)
            node.position = pos
            return node

        default:
            return nil
        }
    }

    private func addSteelPattern(to node: SKSpriteNode) {
        let size = node.size
        let lines: [(CGPoint, CGPoint)] = [
            (CGPoint(x: -size.width/2, y: 0), CGPoint(x: size.width/2, y: 0)),
            (CGPoint(x: 0, y: -size.height/2), CGPoint(x: 0, y: size.height/2))
        ]
        for (start, end) in lines {
            let path = CGMutablePath()
            path.move(to: start)
            path.addLine(to: end)
            let line = SKShapeNode(path: path)
            line.strokeColor = SKColor(white: 0.5, alpha: 0.5)
            line.lineWidth = 1
            node.addChild(line)
        }
    }

    private func animateWater(node: SKSpriteNode) {
        let wave = SKAction.sequence([
            SKAction.colorize(with: SKColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1), colorBlendFactor: 0.5, duration: 0.8),
            SKAction.colorize(with: SKColor(red: 0.0, green: 0.3, blue: 0.8, alpha: 1), colorBlendFactor: 0.5, duration: 0.8)
        ])
        node.run(SKAction.repeatForever(wave))
    }

    private func addBorders() {
        let mapWidth = CGFloat(cols) * tileSize
        let mapHeight = CGFloat(rows) * tileSize
        let thickness: CGFloat = 20

        let borders: [(CGRect, String)] = [
            (CGRect(x: -thickness, y: -thickness, width: thickness, height: mapHeight + thickness * 2), "borderLeft"),
            (CGRect(x: mapWidth, y: -thickness, width: thickness, height: mapHeight + thickness * 2), "borderRight"),
            (CGRect(x: -thickness, y: mapHeight, width: mapWidth + thickness * 2, height: thickness), "borderTop"),
            (CGRect(x: -thickness, y: -thickness, width: mapWidth + thickness * 2, height: thickness), "borderBottom"),
        ]

        for (rect, name) in borders {
            let node = SKSpriteNode(color: SKColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1),
                                    size: rect.size)
            node.position = CGPoint(x: rect.midX, y: rect.midY)
            node.name = name
            let body = SKPhysicsBody(rectangleOf: rect.size)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.border.rawValue
            body.contactTestBitMask = PhysicsCategory.playerBullet.rawValue | PhysicsCategory.enemyBullet.rawValue
            body.collisionBitMask = PhysicsCategory.playerTank.rawValue | PhysicsCategory.enemyTank.rawValue
            node.physicsBody = body
            addChild(node)
        }
    }

    func tilePosition(col: Int, row: Int) -> CGPoint {
        return CGPoint(
            x: CGFloat(col) * tileSize + tileSize / 2,
            y: CGFloat(rows - 1 - row) * tileSize + tileSize / 2
        )
    }

    func tileCoordinate(for position: CGPoint) -> (col: Int, row: Int) {
        let col = Int(position.x / tileSize)
        let row = rows - 1 - Int(position.y / tileSize)
        return (col: max(0, min(cols-1, col)), row: max(0, min(rows-1, row)))
    }

    func destroyBrick(at position: CGPoint) {
        let coord = tileCoordinate(for: position)
        guard coord.row >= 0 && coord.row < rows && coord.col >= 0 && coord.col < cols else { return }
        guard tiles[coord.row][coord.col] == .brick else { return }

        tiles[coord.row][coord.col] = .empty
        let node = tileNodes[coord.row][coord.col]
        node?.removeFromParent()
        tileNodes[coord.row][coord.col] = nil
    }

    var playerSpawnPositions: [CGPoint] {
        var positions: [CGPoint] = []
        for row in 0..<rows {
            for col in 0..<cols {
                if tiles[row][col] == .playerSpawn {
                    positions.append(tilePosition(col: col, row: row))
                }
            }
        }
        return positions
    }

    var enemySpawnPositions: [CGPoint] {
        var positions: [CGPoint] = []
        for row in 0..<rows {
            for col in 0..<cols {
                if tiles[row][col] == .enemySpawn {
                    positions.append(tilePosition(col: col, row: row))
                }
            }
        }
        return positions
    }
}

class BrickNode: SKNode {
    init(tileSize: CGFloat) {
        super.init()
        let half = tileSize / 2
        let quarterH = tileSize / 4

        let colors: [SKColor] = [
            SKColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1),
            SKColor(red: 0.7, green: 0.25, blue: 0.08, alpha: 1)
        ]

        let rects: [CGRect] = [
            CGRect(x: -half, y: 0, width: half, height: quarterH),
            CGRect(x: 0, y: 0, width: half, height: quarterH),
            CGRect(x: -half + quarterH/2, y: -quarterH, width: half, height: quarterH),
            CGRect(x: quarterH/2, y: -quarterH, width: half, height: quarterH),
            CGRect(x: -half, y: -2*quarterH, width: half, height: quarterH),
            CGRect(x: 0, y: -2*quarterH, width: half, height: quarterH),
            CGRect(x: -half + quarterH/2, y: -3*quarterH, width: half, height: quarterH),
            CGRect(x: quarterH/2, y: -3*quarterH, width: half, height: quarterH),
        ]

        for (i, rect) in rects.enumerated() {
            let brick = SKSpriteNode(color: colors[i % 2], size: rect.size)
            brick.position = CGPoint(x: rect.midX, y: rect.midY)
            addChild(brick)
        }

        let body = SKPhysicsBody(rectangleOf: CGSize(width: tileSize, height: tileSize))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.brick.rawValue
        body.contactTestBitMask = PhysicsCategory.playerBullet.rawValue | PhysicsCategory.enemyBullet.rawValue
        body.collisionBitMask = PhysicsCategory.playerTank.rawValue | PhysicsCategory.enemyTank.rawValue
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }
}

class BaseNode: SKNode {
    init(tileSize: CGFloat) {
        super.init()

        let base = SKShapeNode(rectOf: CGSize(width: tileSize * 0.9, height: tileSize * 0.9), cornerRadius: 4)
        base.fillColor = SKColor(red: 0.9, green: 0.7, blue: 0.0, alpha: 1)
        base.strokeColor = SKColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1)
        base.lineWidth = 2
        addChild(base)

        let star = SKLabelNode(text: "★")
        star.fontSize = tileSize * 0.6
        star.fontColor = .red
        star.verticalAlignmentMode = .center
        star.horizontalAlignmentMode = .center
        addChild(star)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: tileSize, height: tileSize))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.base.rawValue
        body.contactTestBitMask = PhysicsCategory.playerBullet.rawValue | PhysicsCategory.enemyBullet.rawValue
        body.collisionBitMask = 0
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }
}
