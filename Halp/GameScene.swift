import SpriteKit
import UIKit

// MARK: - Zombie

final class Zombie: SKSpriteNode {
    enum Kind: CaseIterable {
        case walker    // the regular shambler
        case runner    // speed zombie: fast, fragile
        case crawler   // small, quick, spawns in packs of 3
        case tank      // armored, very slow, soaks damage
        case bloater   // bursts on death, hurting nearby zombies; hits the barricade hard
        case boss      // every 5th wave

        var baseHP: CGFloat {
            switch self {
            case .walker: return 3
            case .runner: return 1.6
            case .crawler: return 1.2
            case .tank: return 14
            case .bloater: return 6
            case .boss: return 60
            }
        }

        var walkSpeed: CGFloat {   // points per second
            switch self {
            case .walker: return 30
            case .runner: return 64
            case .crawler: return 46
            case .tank: return 17
            case .bloater: return 22
            case .boss: return 13
            }
        }

        var pixel: CGFloat {
            switch self {
            case .walker, .runner, .crawler, .bloater: return 3
            case .tank: return 4
            case .boss: return 6
            }
        }

        var reward: Int {
            switch self {
            case .walker, .runner, .crawler: return 1
            case .bloater: return 2
            case .tank: return 4
            case .boss: return 15
            }
        }

        var baseDamage: Int {
            switch self {
            case .walker, .runner, .crawler: return 1
            case .tank: return 4
            case .bloater: return 5
            case .boss: return 10
            }
        }

        var gridA: [String] {
            switch self {
            case .walker, .runner, .boss: return Sprites.zombieFrameA
            case .crawler: return Sprites.crawlerFrameA
            case .tank: return Sprites.tankFrameA
            case .bloater: return Sprites.bloaterFrameA
            }
        }

        var gridB: [String] {
            switch self {
            case .walker, .runner, .boss: return Sprites.zombieFrameB
            case .crawler: return Sprites.crawlerFrameB
            case .tank: return Sprites.tankFrameB
            case .bloater: return Sprites.bloaterFrameB
            }
        }

        var colors: (skin: UIColor, shirt: UIColor) {
            switch self {
            case .walker:
                return (UIColor(red: 0.47, green: 0.68, blue: 0.36, alpha: 1),
                        UIColor(red: 0.45, green: 0.33, blue: 0.24, alpha: 1))
            case .runner:
                return (UIColor(red: 0.62, green: 0.72, blue: 0.40, alpha: 1),
                        UIColor(red: 0.75, green: 0.18, blue: 0.18, alpha: 1))
            case .crawler:
                return (UIColor(red: 0.55, green: 0.60, blue: 0.45, alpha: 1),
                        UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1))
            case .tank:
                return (UIColor(red: 0.38, green: 0.52, blue: 0.40, alpha: 1),
                        UIColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1))
            case .bloater:
                return (UIColor(red: 0.60, green: 0.70, blue: 0.35, alpha: 1),
                        UIColor(red: 0.72, green: 0.75, blue: 0.35, alpha: 1))
            case .boss:
                return (UIColor(red: 0.55, green: 0.40, blue: 0.62, alpha: 1),
                        UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1))
            }
        }

        /// Walk-cycle textures, built once per kind.
        var frames: [SKTexture] {
            if let cached = Kind.textureCache[self] { return cached }
            let palette = Sprites.zombiePalette(skin: colors.skin, shirt: colors.shirt)
            let made = [PixelArt.texture(gridA, palette: palette), PixelArt.texture(gridB, palette: palette)]
            Kind.textureCache[self] = made
            return made
        }

        private static var textureCache: [Kind: [SKTexture]] = [:]
    }

    let kind: Kind
    let maxHP: CGFloat
    let walkSpeed: CGFloat
    private(set) var hp: CGFloat
    private let hpBar: SKSpriteNode
    private let hpBack: SKSpriteNode

    init(kind: Kind, hpScale: CGFloat, speedScale: CGFloat) {
        self.kind = kind
        maxHP = kind.baseHP * hpScale
        hp = maxHP
        walkSpeed = kind.walkSpeed * speedScale

        let size = PixelArt.size(kind.gridA, pixel: kind.pixel)
        let barWidth = max(24, size.width * 0.9)
        let back = SKSpriteNode(color: UIColor(white: 0, alpha: 0.6), size: CGSize(width: barWidth, height: 4))
        let bar = SKSpriteNode(color: .red, size: CGSize(width: barWidth, height: 4))
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpBack = back
        hpBar = bar

        super.init(texture: kind.frames[0], color: .red, size: size)
        colorBlendFactor = 0

        hpBack.position = CGPoint(x: 0, y: size.height / 2 + 6)
        hpBar.position = CGPoint(x: -barWidth / 2, y: 0)
        hpBack.isHidden = true
        hpBack.addChild(hpBar)
        addChild(hpBack)

        let frameTime: TimeInterval = (kind == .runner || kind == .crawler) ? 0.14 : 0.3
        run(.repeatForever(.animate(with: kind.frames, timePerFrame: frameTime)), withKey: "walk")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Returns true if this hit killed the zombie.
    func takeHit(_ damage: CGFloat) -> Bool {
        hp -= damage
        hpBack.isHidden = false
        hpBar.xScale = max(0, hp / maxHP)
        colorBlendFactor = 0.75
        run(.colorize(withColorBlendFactor: 0, duration: 0.12), withKey: "flash")
        return hp <= 0
    }
}

// MARK: - Bullet

private final class Bullet: SKSpriteNode {
    var velocity = CGVector.zero
    var damage: CGFloat = 1
}

// MARK: - Scene

final class GameScene: SKScene {
    weak var model: GameModel?

    // MARK: Tuning
    private let bulletSpeed: CGFloat = 900
    private let groundHeight: CGFloat = 112   // area below the barricade where defenders stand
    private var barricadeY: CGFloat { groundHeight + 4 }
    /// Night zombies are tougher and a little faster.
    private let nightHPMultiplier: CGFloat = 1.6
    private let nightSpeedMultiplier: CGFloat = 1.1
    /// Turret spots (fraction of width, height above bottom), filled in this order:
    /// upper-left, upper-right, lower-left, lower-right.
    private let turretSlots: [(x: CGFloat, y: CGFloat)] = [(0.20, 62), (0.80, 62), (0.33, 8), (0.80, 8)]

    // MARK: Nodes
    private let sky = SKSpriteNode(color: .white, size: .zero)
    private let stars = SKNode()
    private let background = SKNode()
    private let survivor = SKSpriteNode(texture: Sprites.survivor,
                                        size: PixelArt.size(Sprites.survivorRows, pixel: 4))
    private var pads: [SKSpriteNode] = []
    private var turrets: [SKSpriteNode] = []
    private var turretCooldowns: [TimeInterval] = []
    private var zombies: [Zombie] = []
    private var bullets: [Bullet] = []

    // MARK: State
    private var isRunning = false
    private var hasSetUp = false
    private var lastUpdate: TimeInterval = 0
    private var wave = 0
    private var waveActive = false
    private var isNight = false
    private var toSpawn = 0
    private var totalThisWave = 0
    private var spawnTimer: TimeInterval = 0
    private var spawnInterval: TimeInterval = 1
    private var playerCooldown: TimeInterval = 0

    private static let daySky = UIColor(red: 0.42, green: 0.55, blue: 0.62, alpha: 1)
    private static let nightSky = UIColor(red: 0.06, green: 0.07, blue: 0.13, alpha: 1)

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = Palette.sky
        guard !hasSetUp else { return }
        hasSetUp = true

        sky.anchorPoint = .zero
        sky.zPosition = -20
        sky.colorBlendFactor = 1
        sky.color = Self.daySky
        addChild(sky)
        stars.zPosition = -19
        stars.alpha = 0
        addChild(stars)
        addChild(background)

        survivor.anchorPoint = CGPoint(x: 0.5, y: 0)
        survivor.zPosition = 20
        addChild(survivor)

        for _ in turretSlots {
            let pad = SKSpriteNode(texture: Sprites.pad, size: PixelArt.size(Sprites.padRows, pixel: 4))
            pad.anchorPoint = CGPoint(x: 0.5, y: 0)
            pad.zPosition = 15
            addChild(pad)
            pads.append(pad)
        }
        layout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if hasSetUp && size.width > 0 && size.height > 0 { layout() }
    }

    private func layout() {
        sky.size = size
        drawStars()
        drawBackground()
        survivor.position = CGPoint(x: size.width / 2, y: 30)
        for (index, pad) in pads.enumerated() {
            pad.position = slotPosition(index)
        }
        for (index, turret) in turrets.enumerated() {
            turret.position = slotPosition(index)
        }
    }

    private func slotPosition(_ index: Int) -> CGPoint {
        CGPoint(x: size.width * turretSlots[index].x, y: turretSlots[index].y)
    }

    /// Dirt, grass line and a wooden barricade, all built from flat blocks for a pixel look.
    private func drawBackground() {
        background.removeAllChildren()
        guard size.width > 0 else { return }

        let dirt = SKSpriteNode(color: Palette.dirt, size: CGSize(width: size.width, height: groundHeight))
        dirt.anchorPoint = .zero
        background.addChild(dirt)

        for _ in 0..<Int(size.width / 4) {
            let speck = SKSpriteNode(color: Palette.dirtSpeck, size: CGSize(width: 4, height: 4))
            speck.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                     y: CGFloat.random(in: 4...(groundHeight - 8)))
            background.addChild(speck)
        }

        let grass = SKSpriteNode(color: Palette.ground, size: CGSize(width: size.width, height: 6))
        grass.anchorPoint = .zero
        grass.position = CGPoint(x: 0, y: groundHeight - 6)
        background.addChild(grass)

        // Barricade: two rails with posts, right along the line in the sketch.
        for railY in [barricadeY, barricadeY + 10] {
            let rail = SKSpriteNode(color: Palette.plank, size: CGSize(width: size.width, height: 6))
            rail.anchorPoint = .zero
            rail.position = CGPoint(x: 0, y: railY)
            rail.zPosition = 5
            background.addChild(rail)
        }
        var x: CGFloat = 10
        while x < size.width {
            let post = SKSpriteNode(color: Palette.plankDark, size: CGSize(width: 8, height: 24))
            post.anchorPoint = CGPoint(x: 0.5, y: 0)
            post.position = CGPoint(x: x, y: barricadeY - 4)
            post.zPosition = 6
            background.addChild(post)
            x += 44
        }
    }

    private func drawStars() {
        stars.removeAllChildren()
        guard size.width > 0, size.height > groundHeight + 40 else { return }
        for _ in 0..<40 {
            let star = SKSpriteNode(color: UIColor(white: 1, alpha: CGFloat.random(in: 0.3...0.9)),
                                    size: CGSize(width: 2, height: 2))
            star.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                    y: CGFloat.random(in: (groundHeight + 40)...size.height))
            stars.addChild(star)
        }
        let moon = SKShapeNode(circleOfRadius: 18)
        moon.fillColor = UIColor(red: 0.95, green: 0.93, blue: 0.80, alpha: 1)
        moon.strokeColor = .clear
        moon.position = CGPoint(x: size.width * 0.82, y: size.height - 50)
        stars.addChild(moon)
    }

    private func setNight(_ night: Bool) {
        isNight = night
        let duration = 1.2
        sky.run(.colorize(with: night ? Self.nightSky : Self.daySky, colorBlendFactor: 1, duration: duration))
        stars.run(.fadeAlpha(to: night ? 1 : 0, duration: duration))
    }

    // MARK: Game flow

    func startGame() {
        zombies.forEach { $0.removeFromParent() }
        zombies.removeAll()
        bullets.forEach { $0.removeFromParent() }
        bullets.removeAll()
        wave = 0
        waveActive = false
        toSpawn = 0
        playerCooldown = 0
        sky.removeAllActions()
        sky.color = Self.daySky
        stars.alpha = 0
        isNight = false
        syncTurrets()
        isRunning = true
        showBanner("PRESS ▶ TO START", size: 24, hold: 2.0)
    }

    func endGame() {
        isRunning = false
        waveActive = false
        zombies.forEach { $0.removeAction(forKey: "walk") }
    }

    /// Called when the player presses Play between waves.
    func startNextWave() {
        guard isRunning, !waveActive else { return }
        wave += 1
        waveActive = true
        let night = GameModel.isNight(wave: wave)
        if night != isNight { setNight(night) }

        totalThisWave = min(60, 5 + wave * 2)
        toSpawn = totalThisWave
        spawnInterval = max(0.35, 1.1 - Double(wave) * 0.04)
        spawnTimer = 0.6
        model?.waveStarted(wave)
        showBanner(night ? "NIGHT \(wave)" : "DAY \(wave)", size: 40, hold: 1.0)
    }

    private func waveCleared() {
        waveActive = false
        model?.waveCleared()
        showBanner("WAVE \(wave) CLEARED", size: 26, hold: 1.2)
    }

    /// Show a turret on each owned slot, and an empty pad on the rest.
    func syncTurrets() {
        let count = model?.turretCount ?? 0
        while turrets.count > count {
            turrets.removeLast().removeFromParent()
            turretCooldowns.removeLast()
        }
        while turrets.count < count, turrets.count < pads.count {
            let index = turrets.count
            let turret = SKSpriteNode(texture: Sprites.turret, size: PixelArt.size(Sprites.turretRows, pixel: 4))
            turret.anchorPoint = CGPoint(x: 0.5, y: 0)
            turret.position = slotPosition(index)
            turret.zPosition = 18
            addChild(turret)
            turrets.append(turret)
            turretCooldowns.append(0)

            turret.setScale(0.2)
            turret.run(.scale(to: 1, duration: 0.2))
        }
        for (index, pad) in pads.enumerated() {
            pad.isHidden = index < turrets.count
        }
    }

    /// Which zombie types can appear, and how often, by wave.
    private func randomKind() -> Zombie.Kind {
        var pool: [(Zombie.Kind, Int)] = [(.walker, 10)]
        if wave >= 2 { pool.append((.runner, isNight ? 6 : 4)) }
        if wave >= 3 { pool.append((.crawler, 3)) }
        if wave >= 4 { pool.append((.tank, isNight ? 3 : 2)) }
        if wave >= 6 { pool.append((.bloater, 2)) }
        var roll = Int.random(in: 0..<pool.reduce(0) { $0 + $1.1 })
        for (kind, weight) in pool {
            if roll < weight { return kind }
            roll -= weight
        }
        return .walker
    }

    private func spawnNext() {
        let kind: Zombie.Kind
        if wave % 5 == 0 && toSpawn == totalThisWave {
            kind = .boss
        } else {
            kind = randomKind()
        }
        let count = kind == .crawler ? 3 : 1
        for _ in 0..<count {
            spawnZombie(kind)
        }
    }

    private func spawnZombie(_ kind: Zombie.Kind) {
        // Health climbs every wave, and night waves get an extra boost.
        var hpScale = pow(1.17, CGFloat(wave - 1))
        var speedScale = 1 + min(0.6, CGFloat(wave) * 0.02)
        if isNight {
            hpScale *= nightHPMultiplier
            speedScale *= nightSpeedMultiplier
        }
        let zombie = Zombie(kind: kind, hpScale: hpScale, speedScale: speedScale)
        let half = zombie.size.width / 2
        zombie.position = CGPoint(x: CGFloat.random(in: half...max(half, size.width - half)),
                                  y: size.height + zombie.size.height / 2 + CGFloat.random(in: 0...30))
        zombie.zPosition = 10
        addChild(zombie)
        zombies.append(zombie)
    }

    // MARK: Frame update

    override func update(_ currentTime: TimeInterval) {
        let rawDt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 20.0)
        lastUpdate = currentTime
        guard isRunning, let model = model else { return }
        let dt = rawDt * Double(speed) // the 2x button doubles game time

        // Spawning
        if waveActive {
            if toSpawn > 0 {
                spawnTimer -= dt
                if spawnTimer <= 0 {
                    spawnNext()
                    toSpawn -= 1
                    spawnTimer = spawnInterval
                }
            } else if zombies.isEmpty {
                waveCleared()
            }
        }

        // Zombies walk toward the barricade.
        for zombie in zombies {
            zombie.position.y -= zombie.walkSpeed * CGFloat(dt)
            if zombie.position.y - zombie.size.height / 2 <= barricadeY + 14 {
                remove(zombie)
                hitBarricade(at: zombie.position)
                model.baseHit(damage: zombie.kind.baseDamage)
                if !isRunning { return } // that hit ended the game
            }
        }

        // The survivor shoots at the closest zombies.
        playerCooldown -= dt
        if playerCooldown <= 0 {
            let targets = closestZombies(model.shotsPerVolley)
            if !targets.isEmpty {
                let muzzle = CGPoint(x: survivor.position.x + 14, y: survivor.position.y + survivor.size.height)
                for target in targets {
                    fire(from: muzzle, at: target, damage: model.playerDamage, color: Palette.bullet)
                }
                flash(at: muzzle)
                playerCooldown = model.fireInterval
            }
        }

        // Turrets each pick the closest zombie.
        for index in turrets.indices {
            turretCooldowns[index] -= dt
            guard turretCooldowns[index] <= 0, let target = closestZombies(1).first else { continue }
            let turret = turrets[index]
            let muzzle = CGPoint(x: turret.position.x, y: turret.position.y + turret.size.height)
            fire(from: muzzle, at: target, damage: model.turretDamage, color: Palette.turretBullet)
            flash(at: muzzle)
            turretCooldowns[index] = model.turretInterval
        }

        moveBullets(dt)
    }

    private func closestZombies(_ count: Int) -> [Zombie] {
        zombies
            .filter { $0.position.y < size.height - 4 } // only ones on screen
            .sorted { $0.position.y < $1.position.y }
            .prefix(count)
            .map { $0 }
    }

    // MARK: Shooting

    private func fire(from origin: CGPoint, at target: Zombie, damage: CGFloat, color: UIColor) {
        // Lead the target slightly so shots land on walking zombies.
        let distance = hypot(target.position.x - origin.x, target.position.y - origin.y)
        let travel = distance / bulletSpeed
        let aim = CGPoint(x: target.position.x,
                          y: target.position.y - target.walkSpeed * CGFloat(travel))
        let dx = aim.x - origin.x, dy = aim.y - origin.y
        let length = max(1, hypot(dx, dy))

        let bullet = Bullet(color: color, size: CGSize(width: 3, height: 9))
        bullet.position = origin
        bullet.zPosition = 25
        bullet.zRotation = atan2(dy, dx) - .pi / 2
        bullet.velocity = CGVector(dx: dx / length * bulletSpeed, dy: dy / length * bulletSpeed)
        bullet.damage = damage
        addChild(bullet)
        bullets.append(bullet)
    }

    private func moveBullets(_ dt: TimeInterval) {
        var spent: [Bullet] = []
        for bullet in bullets {
            bullet.position.x += bullet.velocity.dx * CGFloat(dt)
            bullet.position.y += bullet.velocity.dy * CGFloat(dt)

            if let hit = zombies.first(where: { $0.frame.contains(bullet.position) }) {
                spent.append(bullet)
                if hit.takeHit(bullet.damage) {
                    kill(hit)
                }
            } else if bullet.position.y > size.height + 20
                        || bullet.position.x < -20 || bullet.position.x > size.width + 20 {
                spent.append(bullet)
            }
        }
        if !spent.isEmpty {
            spent.forEach { $0.removeFromParent() }
            bullets.removeAll { b in spent.contains { $0 === b } }
        }
    }

    private func kill(_ zombie: Zombie) {
        guard zombie.parent != nil else { return } // already dead
        remove(zombie)
        model?.zombieKilled(reward: zombie.kind.reward)
        splat(at: zombie.position, size: zombie.size.width)
        popLabel("+\(zombie.kind.reward)", at: zombie.position)
        if zombie.kind == .bloater {
            burst(from: zombie)
        }
    }

    /// Bloaters pop when killed, damaging every zombie nearby (which can chain).
    private func burst(from bloater: Zombie) {
        let radius: CGFloat = 80
        let damage = bloater.maxHP * 0.6
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = bloater.position
        ring.strokeColor = UIColor(red: 0.75, green: 0.85, blue: 0.3, alpha: 0.9)
        ring.fillColor = UIColor(red: 0.6, green: 0.75, blue: 0.2, alpha: 0.25)
        ring.zPosition = 30
        ring.setScale(0.2)
        addChild(ring)
        ring.run(.sequence([.group([.scale(to: 1, duration: 0.2), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))

        let caught = zombies.filter {
            hypot($0.position.x - bloater.position.x, $0.position.y - bloater.position.y) < radius
        }
        for victim in caught where victim.takeHit(damage) {
            kill(victim)
        }
    }

    private func remove(_ zombie: Zombie) {
        zombie.removeFromParent()
        zombies.removeAll { $0 === zombie }
    }

    // MARK: Effects

    private func flash(at point: CGPoint) {
        let flash = SKSpriteNode(color: Palette.bullet, size: CGSize(width: 8, height: 8))
        flash.position = point
        flash.zPosition = 26
        addChild(flash)
        flash.run(.sequence([.wait(forDuration: 0.04), .removeFromParent()]))
    }

    /// Chunky pixel gibs.
    private func splat(at point: CGPoint, size: CGFloat) {
        let pieces = size > 40 ? 16 : 8
        for _ in 0..<pieces {
            let bit = SKSpriteNode(color: Palette.blood, size: CGSize(width: 4, height: 4))
            bit.position = point
            bit.zPosition = 9
            addChild(bit)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 10...max(12, size * 0.9))
            let move = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.3)
            move.timingMode = .easeOut
            bit.run(.sequence([move, .wait(forDuration: 0.4), .fadeOut(withDuration: 0.3), .removeFromParent()]))
        }
    }

    private func hitBarricade(at point: CGPoint) {
        let shake = SKAction.sequence([
            .moveBy(x: 6, y: 0, duration: 0.03), .moveBy(x: -12, y: 0, duration: 0.06),
            .moveBy(x: 6, y: 0, duration: 0.03),
        ])
        background.run(shake)
        let flash = SKSpriteNode(color: UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.5),
                                 size: CGSize(width: 50, height: 30))
        flash.position = CGPoint(x: point.x, y: barricadeY + 8)
        flash.zPosition = 30
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func popLabel(_ text: String, at point: CGPoint) {
        let label = SKLabelNode(text: text)
        label.fontName = "Menlo-Bold"
        label.fontSize = 16
        label.fontColor = Palette.bullet
        label.position = point
        label.zPosition = 40
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 36, duration: 0.6), .fadeOut(withDuration: 0.6)]),
            .removeFromParent(),
        ]))
    }

    private func showBanner(_ text: String, size fontSize: CGFloat, hold: TimeInterval) {
        let label = SKLabelNode(text: text)
        label.fontName = "Menlo-Bold"
        label.fontSize = fontSize
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        label.zPosition = 50
        label.alpha = 0
        addChild(label)
        label.run(.sequence([
            .fadeIn(withDuration: 0.2), .wait(forDuration: hold),
            .fadeOut(withDuration: 0.4), .removeFromParent(),
        ]))
    }
}
