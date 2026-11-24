import SwiftUI
import SpriteKit

// MARK: - Upgrades (bottom panel)

enum Upgrade: CaseIterable, Identifiable {
    case damage, fireRate, multiShot, turretPower, catapultPower, repair

    var id: Self { self }

    var title: String {
        switch self {
        case .damage: return "Damage"
        case .fireRate: return "Fire Rate"
        case .multiShot: return "Multi-Shot"
        case .turretPower: return "Turret Pwr"
        case .catapultPower: return "Catapult Pwr"
        case .repair: return "Repair"
        }
    }

    var icon: String {
        switch self {
        case .damage: return "flame.fill"
        case .fireRate: return "bolt.fill"
        case .multiShot: return "arrow.triangle.branch"
        case .turretPower: return "wrench.and.screwdriver.fill"
        case .catapultPower: return "circle.hexagongrid.fill"
        case .repair: return "heart.fill"
        }
    }

    /// nil means it can be bought forever.
    var maxLevel: Int? {
        switch self {
        case .fireRate: return 15
        case .multiShot: return 2
        case .damage, .turretPower, .catapultPower, .repair: return nil
        }
    }
}

// MARK: - Defense slots

enum SlotState: Equatable {
    case locked
    case empty
    case turret
    case catapult
}

enum Defense {
    case turret, catapult
}

// MARK: - Perks (random drops after wave 5)

enum Perk: CaseIterable, Hashable {
    case doubleMoney   // 2x kills earned
    case instaKill     // normal zombies die in one hit; bosses take +30% damage instead
    case poison        // every bullet also poisons (damage over time)

    var duration: TimeInterval {
        switch self {
        case .doubleMoney: return 20
        case .instaKill: return 8
        case .poison: return 15
        }
    }

    var title: String {
        switch self {
        case .doubleMoney: return "DOUBLE MONEY"
        case .instaKill: return "INSTA-KILL"
        case .poison: return "POISON BULLETS"
        }
    }

    var emoji: String {
        switch self {
        case .doubleMoney: return "💰"
        case .instaKill: return "💀"
        case .poison: return "🧪"
        }
    }

    var color: UIColor {
        switch self {
        case .doubleMoney: return UIColor(red: 1.0, green: 0.80, blue: 0.20, alpha: 1)
        case .instaKill: return UIColor(red: 0.95, green: 0.25, blue: 0.25, alpha: 1)
        case .poison: return UIColor(red: 0.45, green: 0.90, blue: 0.30, alpha: 1)
        }
    }
}

// MARK: - Model

/// Shared state between the SwiftUI interface (top bar, upgrades, menus) and the SpriteKit scene.
/// Kills are the currency: every zombie killed adds to `kills`, which upgrades and slots spend.
final class GameModel: ObservableObject {
    enum Phase { case menu, playing, gameOver }

    let maxBaseHP = 20

    // Slots
    static let slotCount = 8
    static let freeSlots = 2
    /// A locked slot unlocks for free every this many waves (in order).
    static let freeUnlockEvery = 4
    /// Price to unlock slots 3...8 early.
    private static let unlockCosts = [40, 80, 140, 220, 320, 450]

    // Perks
    /// Perks only start dropping after this wave.
    static let perksAfterWave = 5
    static let perkDropChance: CGFloat = 0.04

    @Published private(set) var phase: Phase = .menu
    @Published private(set) var wave = 0
    @Published private(set) var kills = 0          // spendable
    @Published private(set) var totalKills = 0
    @Published private(set) var baseHP = 20
    @Published private(set) var levels: [Upgrade: Int] = [:]
    @Published private(set) var slots: [SlotState] = GameModel.freshSlots()
    @Published private(set) var activePerks: [Perk: Int] = [:]  // seconds left, for the HUD
    /// Best wave reached; nights count as half-waves (e.g. 3.5).
    @Published private(set) var bestWave: Double
    /// True while (or after) playing a night half-wave.
    @Published private(set) var isNightWave = false
    @Published private(set) var isNewBest = false
    @Published private(set) var waveInProgress = false
    @Published var selectedSlot: Int?
    @Published var isPaused = false
    @Published var isFastForward = false {
        didSet { scene.speed = isFastForward ? 2 : 1 }
    }

    /// Nights are half-waves that come after every 3rd day wave:
    /// 1, 2, 3, 3.5 (night), 4, 5, 6, 6.5 (night), 7...
    /// They're short but brutal: fewer zombies (GameScene.nightLengthMultiplier)
    /// with extra health (GameScene.nightHPMultiplier).
    static let nightEvery = 3

    /// Whether the next wave the Play button sends is a night.
    var nextIsNight: Bool { wave > 0 && !isNightWave && wave % Self.nightEvery == 0 }

    /// The phase shown at the top: the current wave while it's running, otherwise the next one.
    var isNight: Bool { waveInProgress ? isNightWave : nextIsNight }

    /// Progress as a number: 3 for day wave 3, 3.5 for the night after it.
    var progress: Double { Double(wave) + (isNightWave ? 0.5 : 0) }

    /// "3" or "3.5".
    static func waveLabel(_ progress: Double) -> String {
        progress.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(progress))" : String(format: "%.1f", progress)
    }

    /// Label for the top bar: the current (or last) wave.
    var waveLabel: String { wave == 0 ? "1" : Self.waveLabel(progress) }

    let scene: GameScene
    private static let bestWaveKey = "halp.bestWave"

    private static func freshSlots() -> [SlotState] {
        (0..<slotCount).map { $0 < freeSlots ? .empty : .locked }
    }

    init() {
        bestWave = UserDefaults.standard.double(forKey: Self.bestWaveKey)
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
        slots = Self.freshSlots()
        activePerks = [:]
        selectedSlot = nil
        isNewBest = false
        isNightWave = false
        isFastForward = false
        isPaused = false
        waveInProgress = false
        phase = .playing
        scene.startGame()
    }

    /// Play: starts the next wave, or resumes if paused.
    func playPressed() {
        guard phase == .playing else { return }
        if isPaused {
            isPaused = false
        } else if !waveInProgress {
            scene.startNextWave()
        }
    }

    /// Pause: freezes the current wave.
    func pausePressed() {
        guard phase == .playing, waveInProgress else { return }
        isPaused = true
    }

    var canPlay: Bool { phase == .playing && (isPaused || !waveInProgress) }
    var canPause: Bool { phase == .playing && waveInProgress && !isPaused }

    // MARK: Slots

    var unlockedCount: Int { slots.filter { $0 != .locked }.count }
    var turretCount: Int { slots.filter { $0 == .turret }.count }
    var catapultCount: Int { slots.filter { $0 == .catapult }.count }

    /// Slots unlock in order, so only the first locked one can be bought.
    var nextLockedSlot: Int? { slots.firstIndex(of: .locked) }

    var unlockCost: Int? {
        guard nextLockedSlot != nil else { return nil }
        return Self.unlockCosts[min(unlockedCount - Self.freeSlots, Self.unlockCosts.count - 1)]
    }

    /// The wave after which the next slot unlocks for free.
    var nextFreeUnlockWave: Int? {
        guard nextLockedSlot != nil else { return nil }
        return (wave / Self.freeUnlockEvery + 1) * Self.freeUnlockEvery
    }

    func buildCost(_ defense: Defense) -> Int {
        switch defense {
        case .turret: return Int(25 * pow(1.35, Double(turretCount)))
        case .catapult: return Int(45 * pow(1.4, Double(catapultCount)))
        }
    }

    /// Called when the player taps a slot on the battlefield.
    func slotTapped(_ index: Int) {
        guard phase == .playing, slots.indices.contains(index) else { return }
        switch slots[index] {
        case .locked, .empty: selectedSlot = index
        case .turret, .catapult: break // upgraded from the panel
        }
    }

    func unlockSlot(_ index: Int) {
        guard index == nextLockedSlot, let cost = unlockCost, kills >= cost else { return }
        kills -= cost
        slots[index] = .empty
        scene.syncSlots()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func build(_ defense: Defense, at index: Int) {
        guard slots.indices.contains(index), slots[index] == .empty else { return }
        let cost = buildCost(defense)
        guard kills >= cost else { return }
        kills -= cost
        slots[index] = defense == .turret ? .turret : .catapult
        scene.syncSlots()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func unlockNextForFree() {
        guard let index = nextLockedSlot else { return }
        slots[index] = .empty
        scene.syncSlots()
        scene.announce("SLOT UNLOCKED!")
    }

    // MARK: Upgrades

    func level(_ upgrade: Upgrade) -> Int { levels[upgrade, default: 0] }

    func cost(_ upgrade: Upgrade) -> Int {
        let lvl = Double(level(upgrade))
        switch upgrade {
        case .damage: return Int(10 * pow(1.45, lvl))
        case .fireRate: return Int(12 * pow(1.5, lvl))
        case .multiShot: return [60, 220][min(level(upgrade), 1)]
        case .turretPower: return Int(25 * pow(1.55, lvl))
        case .catapultPower: return Int(35 * pow(1.55, lvl))
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
        case .catapultPower: return catapultCount > 0
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
            refreshDanger()
        } else {
            levels[upgrade, default: 0] += 1
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Short stat line shown on each upgrade card.
    func detail(_ upgrade: Upgrade) -> String {
        switch upgrade {
        case .damage: return String(format: "%.1f dmg", Double(playerDamage))
        case .fireRate: return String(format: "%.1f/s", 1 / fireInterval)
        case .multiShot: return "\(shotsPerVolley) target\(shotsPerVolley == 1 ? "" : "s")"
        case .turretPower: return turretCount == 0 ? "no turrets" : "Lv \(level(.turretPower))"
        case .catapultPower: return catapultCount == 0 ? "no catapults" : "Lv \(level(.catapultPower))"
        case .repair: return "+5 HP"
        }
    }

    // MARK: Stats read by the scene

    var playerDamage: CGFloat { pow(1.3, CGFloat(level(.damage))) }
    var fireInterval: TimeInterval { 0.55 * pow(0.88, Double(level(.fireRate))) }
    var shotsPerVolley: Int { 1 + level(.multiShot) }

    /// Turrets: fast, single target.
    var turretDamage: CGFloat { 0.7 * pow(1.3, CGFloat(level(.turretPower))) }
    var turretInterval: TimeInterval { 0.9 * pow(0.9, Double(level(.turretPower))) }

    /// Catapults: slow, splash damage.
    var catapultDamage: CGFloat { 2.2 * pow(1.3, CGFloat(level(.catapultPower))) }
    var catapultInterval: TimeInterval { 2.6 * pow(0.92, Double(level(.catapultPower))) }
    var catapultRadius: CGFloat { 50 + CGFloat(min(level(.catapultPower), 10)) * 2 }

    // MARK: Events from the scene

    func waveStarted(_ number: Int, night: Bool) {
        wave = number
        isNightWave = night
        waveInProgress = true
    }

    func waveCleared() {
        waveInProgress = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if !isNightWave && wave % Self.freeUnlockEvery == 0 {
            unlockNextForFree()
        }
    }

    func zombieKilled(reward: Int) {
        kills += reward
        totalKills += 1
    }

    /// The scene reports perk timers (whole seconds) whenever they change.
    func perksChanged(_ perks: [Perk: Int]) {
        activePerks = perks
    }

    /// Red pulsing screen edges when the barricade is at 30% or less.
    private func refreshDanger() {
        scene.setDanger(baseHP > 0 && baseHP * 10 <= maxBaseHP * 3)
    }

    func baseHit(damage: Int) {
        guard phase == .playing else { return }
        baseHP = max(0, baseHP - damage)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        refreshDanger()
        if baseHP == 0 {
            if progress > bestWave {
                bestWave = progress
                isNewBest = true
                UserDefaults.standard.set(progress, forKey: Self.bestWaveKey)
            }
            scene.endGame()
            waveInProgress = false
            isPaused = false
            selectedSlot = nil
            phase = .gameOver
        }
    }
}
