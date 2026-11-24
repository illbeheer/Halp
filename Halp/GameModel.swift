import SwiftUI
import SpriteKit

enum Upgrade: CaseIterable, Identifiable {
    case damage, fireRate, multiShot, turret, turretPower, repair

    var id: Self { self }

    var title: String {
        switch self {
        case .damage: return "Damage"
        case .fireRate: return "Fire Rate"
        case .multiShot: return "Multi-Shot"
        case .turret: return "Turret"
        case .turretPower: return "Turret Pwr"
        case .repair: return "Repair"
        }
    }

    var icon: String {
        switch self {
        case .damage: return "flame.fill"
        case .fireRate: return "bolt.fill"
        case .multiShot: return "arrow.triangle.branch"
        case .turret: return "plus.square.on.square"
        case .turretPower: return "wrench.and.screwdriver.fill"
        case .repair: return "heart.fill"
        }
    }

    /// nil means it can be bought forever.
    var maxLevel: Int? {
        switch self {
        case .fireRate: return 15
        case .multiShot: return 2
        case .turret: return GameModel.turretSlots
        case .damage, .turretPower, .repair: return nil
        }
    }
}

/// Shared state between the SwiftUI interface (top bar, upgrades, menus) and the SpriteKit scene.
/// Kills are the currency: every zombie killed adds to `kills`, which upgrades spend.
final class GameModel: ObservableObject {
    enum Phase { case menu, playing, gameOver }

    static let turretSlots = 4
    let maxBaseHP = 20

    @Published private(set) var phase: Phase = .menu
    @Published private(set) var wave = 0
    @Published private(set) var kills = 0          // spendable
    @Published private(set) var totalKills = 0
    @Published private(set) var baseHP = 20
    @Published private(set) var levels: [Upgrade: Int] = [:]
    @Published private(set) var bestWave: Int
    @Published private(set) var isNewBest = false
    @Published private(set) var waveInProgress = false
    @Published var isPaused = false
    @Published var isFastForward = false {
        didSet { scene.speed = isFastForward ? 2 : 1 }
    }

    /// Day and night alternate: odd waves are day, even waves are night.
    /// Night zombies get extra health (see GameScene.nightHPMultiplier).
    static func isNight(wave: Int) -> Bool { wave % 2 == 0 }

    /// The phase shown at the top: the current wave while it's running, otherwise the next one.
    var isNight: Bool { Self.isNight(wave: waveInProgress ? wave : wave + 1) }

    let scene: GameScene
    private static let bestWaveKey = "halp.bestWave"

    init() {
        bestWave = UserDefaults.standard.integer(forKey: Self.bestWaveKey)
        scene = GameScene(size: CGSize(width: 390, height: 600))
        scene.scaleMode = .resizeFill
        scene.model = self
    }

    // MARK: Flow

    func start() {
        wave = 0
        kills = 0
        totalKills = 0
        baseHP = maxBaseHP
        levels = [:]
        isNewBest = false
        isFastForward = false
        isPaused = false
        waveInProgress = false
        phase = .playing
        scene.startGame()
    }

    /// The Play button: starts the next wave, or pauses/resumes the current one.
    func playPressed() {
        guard phase == .playing else { return }
        if waveInProgress {
            isPaused.toggle()
        } else {
            isPaused = false
            scene.startNextWave()
        }
    }

    // MARK: Upgrades

    func level(_ upgrade: Upgrade) -> Int { levels[upgrade, default: 0] }

    func cost(_ upgrade: Upgrade) -> Int {
        let lvl = Double(level(upgrade))
        switch upgrade {
        case .damage: return Int(10 * pow(1.45, lvl))
        case .fireRate: return Int(12 * pow(1.5, lvl))
        case .multiShot: return [60, 220][min(level(upgrade), 1)]
        case .turret: return [20, 50, 110, 220][min(level(upgrade), 3)]
        case .turretPower: return Int(25 * pow(1.55, lvl))
        case .repair: return 10 + wave * 2
        }
    }

    func isMaxed(_ upgrade: Upgrade) -> Bool {
        if let max = upgrade.maxLevel { return level(upgrade) >= max }
        return false
    }

    /// Whether the upgrade makes sense right now, ignoring cost.
    func isAvailable(_ upgrade: Upgrade) -> Bool {
        if isMaxed(upgrade) { return false }
        switch upgrade {
        case .turretPower: return turretCount > 0
        case .repair: return baseHP < maxBaseHP
        default: return true
        }
    }

    func canBuy(_ upgrade: Upgrade) -> Bool {
        phase == .playing && isAvailable(upgrade) && kills >= cost(upgrade)
    }

    func buy(_ upgrade: Upgrade) {
        guard canBuy(upgrade) else { return }
        kills -= cost(upgrade)
        if upgrade == .repair {
            baseHP = min(maxBaseHP, baseHP + 5)
        } else {
            levels[upgrade, default: 0] += 1
        }
        if upgrade == .turret {
            scene.syncTurrets()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Short stat line shown on each upgrade card.
    func detail(_ upgrade: Upgrade) -> String {
        switch upgrade {
        case .damage: return String(format: "%.1f dmg", Double(playerDamage))
        case .fireRate: return String(format: "%.1f/s", 1 / fireInterval)
        case .multiShot: return "\(shotsPerVolley) target\(shotsPerVolley == 1 ? "" : "s")"
        case .turret: return "\(turretCount)/\(Self.turretSlots)"
        case .turretPower: return "Lv \(level(.turretPower))"
        case .repair: return "+5 HP"
        }
    }

    // MARK: Stats read by the scene

    var playerDamage: CGFloat { pow(1.3, CGFloat(level(.damage))) }
    var fireInterval: TimeInterval { 0.55 * pow(0.88, Double(level(.fireRate))) }
    var shotsPerVolley: Int { 1 + level(.multiShot) }
    var turretCount: Int { level(.turret) }
    var turretDamage: CGFloat { 0.7 * pow(1.3, CGFloat(level(.turretPower))) }
    var turretInterval: TimeInterval { 0.9 * pow(0.9, Double(level(.turretPower))) }

    // MARK: Events from the scene

    func waveStarted(_ number: Int) {
        wave = number
        waveInProgress = true
    }

    func waveCleared() {
        waveInProgress = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func zombieKilled(reward: Int) {
        kills += reward
        totalKills += 1
    }

    func baseHit(damage: Int) {
        guard phase == .playing else { return }
        baseHP = max(0, baseHP - damage)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        if baseHP == 0 {
            if wave > bestWave {
                bestWave = wave
                isNewBest = true
                UserDefaults.standard.set(wave, forKey: Self.bestWaveKey)
            }
            scene.endGame()
            waveInProgress = false
            isPaused = false
            phase = .gameOver
        }
    }
}
