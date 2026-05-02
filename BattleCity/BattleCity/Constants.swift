import CoreGraphics
import UIKit

enum PhysicsCategory: UInt32 {
    case none       = 0
    case playerTank = 1
    case enemyTank  = 2
    case playerBullet = 4
    case enemyBullet  = 8
    case brick      = 16
    case steel      = 32
    case base       = 64
    case powerUp    = 128
    case water      = 256
    case border     = 512
}

enum TileType: Int {
    case empty  = 0
    case brick  = 1
    case steel  = 2
    case water  = 3
    case forest = 4
    case base   = 5
    case playerSpawn = 6
    case enemySpawn  = 7
}

struct GameConfig {
    static let tileSize: CGFloat = 32
    static let mapCols = 13
    static let mapRows = 13
    static let playerBulletSpeed: CGFloat = 350
    static let enemyBulletSpeed: CGFloat = 250
    static let playerTankSpeed: CGFloat = 120
    static let enemyTankSpeed: CGFloat = 80
    static let playerBulletCooldown: TimeInterval = 0.4
    static let enemyBulletCooldown: TimeInterval = 1.5
    static let enemyRespawnDelay: TimeInterval = 3.0
    static let maxEnemiesOnScreen = 4
    static let totalEnemiesPerLevel = 20
}

enum Direction {
    case up, down, left, right

    var dx: CGFloat {
        switch self {
        case .left:  return -1
        case .right: return  1
        default:     return  0
        }
    }
    var dy: CGFloat {
        switch self {
        case .up:    return  1
        case .down:  return -1
        default:     return  0
        }
    }
    var angle: CGFloat {
        switch self {
        case .up:    return 0
        case .down:  return .pi
        case .left:  return .pi / 2
        case .right: return -.pi / 2
        }
    }
}
