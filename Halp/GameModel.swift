import SwiftUI
import SpriteKit

// MARK: - Guns (weapon classes; each hero carries a set of three)

enum Gun: Int, CaseIterable, Identifiable {
    case pistol, smg, shotgun, rifle, marksman, lmg, revolver, crossbow, flamethrower

    var id: Self { self }

    var name: String {
        switch self {
        case .pistol: return "Pistol"
        case .smg: return "SMG"
        case .shotgun: return "Shotgun"
        case .rifle: return "Assault Rifle"
        case .marksman: return "Marksman"
        case .lmg: return "LMG"
        case .revolver: return "Revolver"
        case .crossbow: return "Crossbow"
        case .flamethrower: return "Flamethrower"
        }
    }

    var shortName: String {
        switch self {
        case .rifle: return "Rifle"
        case .flamethrower: return "Flamer"
        default: return name
        }
    }

    /// One line describing how it plays.
    var blurb: String {
        switch self {
        case .pistol: return "Reliable sidearm."
        case .smg: return "Sprays fast, weak hits."
        case .shotgun: return "5-pellet blast, short range."
        case .rifle: return "Fast and hard-hitting."
        case .marksman: return "Slow, huge damage, pierces 4."
        case .lmg: return "Huge mag, long reload."
        case .revolver: return "Six heavy rounds."
        case .crossbow: return "Bolts skewer up to 5."
        case .flamethrower: return "Short-range stream that burns."
        }
    }

    /// Kills to buy it (a hero's first gun is always free).
    var price: Int {
        switch self {
        case .pistol: return 0
        case .smg: return 60
        case .shotgun: return 120
        case .rifle: return 250
        case .marksman: return 400
        case .lmg: return 800
        case .revolver: return 120
        case .crossbow: return 150
        case .flamethrower: return 300
        }
    }

    var baseDamage: CGFloat {
        switch self {
        case .pistol: return 1.0
        case .smg: return 0.55
        case .shotgun: return 0.9      // per pellet
        case .rifle: return 1.1
        case .marksman: return 5.0
        case .lmg: return 1.2
        case .revolver: return 2.4
        case .crossbow: return 3.0
        case .flamethrower: return 0.3
        }
    }

    /// Seconds between shots.
    var baseInterval: TimeInterval {
        switch self {
        case .pistol: return 0.45
        case .smg: return 0.11
        case .shotgun: return 0.8
        case .rifle: return 0.16
        case .marksman: return 1.0
        case .lmg: return 0.09
        case .revolver: return 0.5
        case .crossbow: return 0.85
        case .flamethrower: return 0.06
        }
    }

    var baseMagazine: Int {
        switch self {
        case .pistol: return 8
        case .smg: return 30
        case .shotgun: return 6
        case .rifle: return 30
        case .marksman: return 5
        case .lmg: return 100
        case .revolver: return 6
        case .crossbow: return 8
        case .flamethrower: return 60
        }
    }

    var baseReload: TimeInterval {
        switch self {
        case .pistol: return 1.2
        case .smg: return 1.6
        case .shotgun: return 2.2
        case .rifle: return 1.8
        case .marksman: return 2.4
        case .lmg: return 4.0
        case .revolver: return 1.6
        case .crossbow: return 1.8
        case .flamethrower: return 2.5
        }
    }

    /// Bullets per shot.
    var pellets: Int { self == .shotgun ? 5 : 1 }

    /// Random aim wobble / pellet fan, in radians.
    var spread: CGFloat {
        switch self {
        case .pistol: return 0.03
        case .smg: return 0.09
        case .shotgun: return 0.34
        case .rifle: return 0.04
        case .marksman: return 0
        case .lmg: return 0.07
        case .revolver: return 0.02
        case .crossbow: return 0
        case .flamethrower: return 0.28
        }
    }

    /// How many zombies one bullet can pass through.
    var pierce: Int {
        switch self {
        case .marksman: return 4
        case .crossbow: return 5
        default: return 1
        }
    }

    /// How far bullets fly before fading (nil = across the whole screen).
    var range: CGFloat? {
        switch self {
        case .shotgun: return 300
        case .flamethrower: return 200
        default: return nil
        }
    }

    /// Sets zombies on fire (damage over time).
    var burns: Bool { self == .flamethrower }

    var bulletSize: CGSize {
        switch self {
        case .flamethrower: return CGSize(width: 7, height: 7)
        case .crossbow: return CGSize(width: 2, height: 14)
        case .marksman, .revolver: return CGSize(width: 3, height: 12)
        default: return CGSize(width: 3, height: 9)
        }
    }

    var bulletColor: UIColor {
        switch self {
        case .flamethrower: return UIColor(red: 1.0, green: 0.45, blue: 0.10, alpha: 0.9)
        case .crossbow: return UIColor(red: 0.75, green: 0.65, blue: 0.50, alpha: 1)
        default: return Palette.bullet
        }
    }

    /// Better guns cost more to upgrade.
    var upgradeCostScale: Double {
        switch self {
        case .pistol: return 1
        case .smg: return 1.4
        case .shotgun, .revolver: return 1.8
        case .crossbow: return 2
        case .rifle: return 2.6
        case .flamethrower: return 2.8
        case .marksman: return 3.4
        case .lmg: return 5
        }
    }
}

// MARK: - Upgrades for the equipped gun (bottom panel)

enum Upgrade: CaseIterable, Identifiable {
    case damage, fireRate, magazine, repair

    var id: Self { self }

    var title: String {
        switch self {
        case .damage: return "Damage"
        case .fireRate: return "Fire Rate"
        case .magazine: return "Magazine"
        case .repair: return "Repair"
        }
    }

    var icon: String {
        switch self {
        case .damage: return "flame.fill"
        case .fireRate: return "bolt.fill"
        case .magazine: return "rectangle.stack.fill"
        case .repair: return "hammer.fill"
        }
    }

    /// nil means it can be bought forever.
    var maxLevel: Int? {
        switch self {
        case .fireRate: return 10
        case .magazine: return 8
        case .damage, .repair: return nil
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
    case doubleMoney   // 2x gold earned
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
/// Gold is the currency: every zombie killed pays gold, which guns, upgrades and defenses spend.
/// In Campaign your gold is saved and carries over from region to region (and run to run).
final class GameModel: ObservableObject {
    enum Phase { case menu, map, playing, regionCleared, gameOver }
    enum Mode { case endless, campaign }

    let maxBaseHP = 20

    // Slots: 2 free, the other 6 must be bought (in order). Each defense levels up on its own.
    static let slotCount = 8
    static let freeSlots = 2
    static let maxDefenseLevel = 10
    private static let unlockCosts = [40, 80, 140, 220, 320, 450]

    // Perks
    /// Perks only start dropping after this wave.
    static let perksAfterWave = 5
    static let perkDropChance: CGFloat = 0.04

    @Published private(set) var phase: Phase = .menu
    @Published private(set) var mode: Mode = .endless
    /// The campaign region being played (nil in Endless).
    @Published private(set) var region: Region?

    // Heroes and saved progress
    @Published private(set) var hero: Hero
    @Published private(set) var rescuedHeroes: Set<Hero>
    @Published private(set) var regionsCleared: Int
    /// Set when a region is cleared, for the "rescued" screen.
    @Published private(set) var lastRescue: Hero?
    @Published var showRoster = false
    /// Seconds until the hero's ability is ready again (0 = ready).
    @Published private(set) var abilityCooldown = 0
    @Published private(set) var wave = 0
    /// Spendable gold. In Campaign every change is saved, so it carries over between regions.
    @Published private(set) var gold = 0 {
        didSet { if mode == .campaign { SavedProgress.campaignGold = gold } }
    }
    @Published private(set) var totalKills = 0
    @Published private(set) var baseHP = 20
    @Published private(set) var ownedGuns: Set<Gun> = [.pistol]
    @Published private(set) var equippedGun: Gun = .pistol
    @Published private(set) var gunLevels: [Gun: [Upgrade: Int]] = [:]
    @Published private(set) var slots: [SlotState] = GameModel.freshSlots()
    @Published private(set) var slotLevels: [Int] = Array(repeating: 0, count: GameModel.slotCount)
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

    /// Endless: 2 free slots, buy the rest. Campaign: every slot is open (you pay for the defenses).
    private static func freshSlots(allOpen: Bool = false) -> [SlotState] {
        (0..<slotCount).map { allOpen || $0 < freeSlots ? .empty : .locked }
    }

    init() {
        bestWave = UserDefaults.standard.double(forKey: Self.bestWaveKey)
        let rescued = SavedProgress.rescued
        rescuedHeroes = rescued
        regionsCleared = SavedProgress.regionsCleared
        let saved = SavedProgress.selectedHero
        hero = rescued.contains(saved) ? saved : .rook
        scene = GameScene(size: CGSize(width: 390, height: 600))
        scene.scaleMode = .resizeFill
        scene.model = self
    }

    // MARK: Flow

    // MARK: Menus and modes

    func startEndless() {
        mode = .endless
        region = nil
        beginRun()
    }

    func openMap() {
        selectedSlot = nil
        isPaused = false
        phase = .map
    }

    func backToMenu() {
        selectedSlot = nil
        isPaused = false
        phase = .menu
    }

    func isUnlocked(_ region: Region) -> Bool { region.rawValue <= regionsCleared }
    func isCleared(_ region: Region) -> Bool { region.rawValue < regionsCleared }

    func startRegion(_ region: Region) {
        guard isUnlocked(region) else { return }
        mode = .campaign
        self.region = region
        beginRun()
    }

    /// Play the same mode/region again after losing.
    func retry() {
        beginRun()
    }

    /// Gold banked for Campaign (shown on the menu and route).
    var campaignGold: Int { mode == .campaign && phase == .playing ? gold : SavedProgress.campaignGold }

    /// Kept for older call sites: restart the current mode.
    func start() {
        beginRun()
    }

    private func beginRun() {
        wave = 0
        gold = mode == .campaign ? SavedProgress.campaignGold : 0
        totalKills = 0
        baseHP = maxBaseHP
        ownedGuns = [hero.startingGun]
        equippedGun = hero.startingGun
        gunLevels = [:]
        abilityCooldown = 0
        lastRescue = nil
        showRoster = false
        slots = Self.freshSlots(allOpen: mode == .campaign)
        slotLevels = Array(repeating: 0, count: Self.slotCount)
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

    // MARK: Guns

    func owns(_ gun: Gun) -> Bool { ownedGuns.contains(gun) }

    /// A hero's first gun is free; the others cost gold.
    func price(_ gun: Gun) -> Int { gun == hero.startingGun ? 0 : gun.price }

    func canBuyGun(_ gun: Gun) -> Bool {
        phase == .playing && !owns(gun) && gold >= price(gun)
    }

    /// Tapping a gun: buy it if you can, or switch to it if you own it.
    func gunTapped(_ gun: Gun) {
        guard phase == .playing else { return }
        if owns(gun) {
            guard gun != equippedGun else { return }
            equippedGun = gun
            scene.weaponChanged()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else if canBuyGun(gun) {
            gold -= price(gun)
            ownedGuns.insert(gun)
            equippedGun = gun
            scene.weaponChanged()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: Gun upgrades (always for the equipped gun, except Repair)

    func level(_ upgrade: Upgrade, for gun: Gun? = nil) -> Int {
        gunLevels[gun ?? equippedGun]?[upgrade] ?? 0
    }

    func cost(_ upgrade: Upgrade) -> Int {
        let lvl = Double(level(upgrade))
        let scale = equippedGun.upgradeCostScale
        switch upgrade {
        case .damage: return Int(10 * pow(1.45, lvl) * scale)
        case .fireRate: return Int(12 * pow(1.5, lvl) * scale)
        case .magazine: return Int(10 * pow(1.5, lvl) * scale)
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
        if upgrade == .repair { return baseHP < maxBaseHP }
        return true
    }

    func canBuy(_ upgrade: Upgrade) -> Bool {
        phase == .playing && isAvailable(upgrade) && gold >= cost(upgrade)
    }

    func buy(_ upgrade: Upgrade) {
        guard canBuy(upgrade) else { return }
        gold -= cost(upgrade)
        if upgrade == .repair {
            baseHP = min(maxBaseHP, baseHP + 5)
            refreshDanger()
        } else {
            gunLevels[equippedGun, default: [:]][upgrade, default: 0] += 1
            if upgrade == .magazine { scene.weaponChanged(refill: true) }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Short stat line shown on each upgrade card.
    func detail(_ upgrade: Upgrade) -> String {
        switch upgrade {
        case .damage:
            let perShot = gunDamage * CGFloat(equippedGun.pellets)
            return String(format: "%.1f / shot", Double(perShot))
        case .fireRate: return String(format: "%.1f / s", 1 / gunInterval)
        case .magazine: return String(format: "%d rds · %.1fs", magazineSize, reloadTime)
        case .repair: return "+5 HP"
        }
    }

    // MARK: Gun stats read by the scene (equipped gun)

    var gunDamage: CGFloat { equippedGun.baseDamage * pow(1.3, CGFloat(level(.damage))) }
    var gunInterval: TimeInterval {
        equippedGun.baseInterval * pow(0.9, Double(level(.fireRate))) * hero.fireIntervalMultiplier
    }
    var magazineSize: Int {
        Int((Double(equippedGun.baseMagazine) * (1 + 0.25 * Double(level(.magazine)))
             * hero.magazineMultiplier).rounded())
    }
    var reloadTime: TimeInterval {
        equippedGun.baseReload * pow(0.88, Double(level(.magazine))) * hero.reloadMultiplier
    }

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

    func buildCost(_ defense: Defense) -> Int {
        switch defense {
        case .turret: return Int(25 * pow(1.35, Double(turretCount)))
        case .catapult: return Int(45 * pow(1.4, Double(catapultCount)))
        }
    }

    /// Price to take the defense in this slot to its next level, or nil if maxed/empty.
    func upgradeCost(slot index: Int) -> Int? {
        let lvl = slotLevels[index]
        guard lvl >= 1, lvl < Self.maxDefenseLevel else { return nil }
        switch slots[index] {
        case .turret: return Int(30 * pow(1.6, Double(lvl - 1)))
        case .catapult: return Int(45 * pow(1.6, Double(lvl - 1)))
        case .locked, .empty: return nil
        }
    }

    /// Called when the player taps a slot on the battlefield.
    func slotTapped(_ index: Int) {
        guard phase == .playing, slots.indices.contains(index) else { return }
        selectedSlot = index
    }

    func unlockSlot(_ index: Int) {
        guard index == nextLockedSlot, let cost = unlockCost, gold >= cost else { return }
        gold -= cost
        slots[index] = .empty
        scene.syncSlots()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func build(_ defense: Defense, at index: Int) {
        guard slots.indices.contains(index), slots[index] == .empty else { return }
        let cost = buildCost(defense)
        guard gold >= cost else { return }
        gold -= cost
        slots[index] = defense == .turret ? .turret : .catapult
        slotLevels[index] = 1
        scene.syncSlots()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func upgradeDefense(at index: Int) {
        guard let cost = upgradeCost(slot: index), gold >= cost else { return }
        gold -= cost
        slotLevels[index] += 1
        scene.syncSlots()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: Defense stats read by the scene (per slot, by level)

    /// Turrets: fast, single target.
    func turretDamage(slot index: Int) -> CGFloat {
        0.7 * pow(1.35, CGFloat(slotLevels[index] - 1)) * hero.defenseDamageMultiplier
    }
    func turretInterval(slot index: Int) -> TimeInterval { 0.9 * pow(0.9, Double(slotLevels[index] - 1)) }

    /// Catapults: slow, splash damage.
    func catapultDamage(slot index: Int) -> CGFloat {
        2.2 * pow(1.35, CGFloat(slotLevels[index] - 1)) * hero.defenseDamageMultiplier
    }
    func catapultInterval(slot index: Int) -> TimeInterval { 2.6 * pow(0.92, Double(slotLevels[index] - 1)) }
    func catapultRadius(slot index: Int) -> CGFloat { 50 + CGFloat(slotLevels[index] - 1) * 3 }

    // MARK: Heroes

    func isRescued(_ hero: Hero) -> Bool { rescuedHeroes.contains(hero) }

    /// Heroes can be swapped outside a run, or between waves.
    var canSwapHero: Bool { phase != .playing || !waveInProgress }

    /// Tapping the survivor on the battlefield opens the roster between waves.
    func heroTapped() {
        guard phase == .playing, canSwapHero else { return }
        showRoster = true
    }

    func selectHero(_ newHero: Hero) {
        guard isRescued(newHero), canSwapHero, newHero != hero else { return }
        hero = newHero
        SavedProgress.selectedHero = newHero
        if phase == .playing {
            // Their own weapon set: the first gun is free; anything already bought stays bought.
            ownedGuns.insert(newHero.startingGun)
            equippedGun = newHero.startingGun
            abilityCooldown = 0
            scene.heroChanged()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    var abilityReady: Bool { abilityCooldown == 0 }
    var canUseAbility: Bool { phase == .playing && waveInProgress && !isPaused && abilityReady }

    func useAbility() {
        guard canUseAbility else { return }
        scene.useAbility()
    }

    /// The scene reports the cooldown in whole seconds.
    func abilityCooldownChanged(_ seconds: Int) {
        abilityCooldown = seconds
    }

    func repairBarricade(_ amount: Int) {
        guard phase == .playing else { return }
        baseHP = min(maxBaseHP, baseHP + amount)
        refreshDanger()
    }

    // MARK: Events from the scene

    func waveStarted(_ number: Int, night: Bool) {
        wave = number
        isNightWave = night
        waveInProgress = true
    }

    func waveCleared() {
        waveInProgress = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// In Campaign: how many day waves this region has.
    var regionWaves: Int? { mode == .campaign ? region?.waves : nil }

    /// The scene calls this when the region's last wave is cleared.
    func regionCompleted() {
        guard mode == .campaign, let region = region else { return }
        waveInProgress = false
        isPaused = false
        selectedSlot = nil
        if region.rawValue + 1 > regionsCleared {
            regionsCleared = region.rawValue + 1
            SavedProgress.regionsCleared = regionsCleared
        }
        if let rescued = region.rescue, !rescuedHeroes.contains(rescued) {
            rescuedHeroes.insert(rescued)
            SavedProgress.rescued = rescuedHeroes
            lastRescue = rescued
        } else {
            lastRescue = nil
        }
        scene.endGame()
        phase = .regionCleared
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func zombieKilled(reward: Int) {
        gold += reward
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
            if mode == .endless && progress > bestWave {
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
