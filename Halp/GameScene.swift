import SpriteKit
import UIKit

// MARK: - Zombie

final class Zombie: SKSpriteNode {
    enum Kind {
        case walker, runner, brute, boss

        var baseHP: CGFloat {
            switch self {
            case .walker: return 3
            case .runner: return 1.6
            case .brute: return 10
            case .boss: return 60
            }
        }

        var walkSpeed: CGFloat {   // points per second
            switch self {
            case .walker: return 32
            case .runner: return 62
            case .brute: return 20
            case .boss: return 14
            }
        }

        var pixel: CGFloat {
            switch self {
            case .walker, .runner: return 3
            case .brute: return 4
            case .boss: return 6
            }
        }

        var reward: Int {
            switch self {
            case .walker, .runner: return 1
            case .brute: return 3
            case .boss: return 15
            }
        }

        var baseDamage: Int {
            switch self {
            case .walker, .runner: return 1
            case .brute: return 3
            case .boss: return 10
            }
        }

        var frames: [SKTexture] {
            switch self {
            case .walker: return Zombie.walkerFrames
            case .runner: return Zombie.runnerFrames
            case .brute: return Zombie.bruteFrames
            case .boss: return Zombie.bossFrames
            }
        }
    }

    private static func makeFrames(skin: UIColor, shirt: UIColor) -> [SKTexture] {
        let palette = Sprites.zombiePalette(skin: skin, shirt: shirt)
        return [PixelArt.texture(Sprites.zombieFrameA, palette: palette),
                PixelArt.texture(Sprites.zombieFrameB, palette: palette)]
    }

    static let walkerFrames = makeFrames(skin: UIColor(red: 0.47, green: 0.68, blue: 0.36, alpha: 1),
                                         shirt: UIColor(red: 0.45, green: 0.33, blue: 0.24, alpha: 1))
    static let runnerFrames = makeFrames(skin: UIColor(red: 0.62, green: 0.72, blue: 0.40, alpha: 1),
                                         shirt: UIColor(red: 0.70, green: 0.20, blue: 0.20, alpha: 1))
    static let bruteFrames = makeFrames(skin: UIColor(red: 0.38, green: 0.52, blue: 0.40, alpha: 1),
                                        shirt: UIColor(red: 0.35, green: 0.30, blue: 0.50, alpha: 1))
    static let bossFrames = makeFrames(skin: UIColor(red: 0.55, green: 0.40, blue: 0.62, alpha: 1),
                                       shirt: UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1))

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

        let size = PixelArt.size(Sprites.zombieFrameA, pixel: kind.pixel)
        let barWidth = size.width * 0.9
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

        let walk = SKAction.animate(with: kind.frames, timePerFrame: kind == .runner ? 0.15 : 0.3)
        run(.repeatForever(walk), withKey: "walk")
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
    private let groundHeight: CGFloat = 70     // dirt strip the defenders stand on
    private let defenderY: CGFloat = 14        // feet of the survivor and turrets
    private var barricadeY: CGFloat { groundHeight + 20 }
    /// Order turret spots are filled: inner pair first, then the outer pair.
    private let turretSlotX: [CGFloat] = [0.32, 0.68, 0.13, 0.87]

    // MARK: Nodes
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
    private var toSpawn = 0
    private var spawnTimer: TimeInterval = 0
    private var spawnInterval: TimeInterval = 1
    private var intermission: TimeInterval = 0
    private var playerCooldown: TimeInterval = 0

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = Palette.sky
        guard !hasSetUp else { return }
        hasSetUp = true

        addChild(background)
        survivor.anchorPoint = CGPoint(x: 0.5, y: 0)
        survivor.zPosition = 20
        addChild(survivor)

        for _ in turretSlotX {
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
        drawBackground()
        survivor.position = CGPoint(x: size.width / 2, y: defenderY)
        for (index, pad) in pads.enumerated() {
            pad.position = CGPoint(x: size.width * turretSlotX[index], y: defenderY)
        }
        for (index, turret) in turrets.enumerated() {
            turret.position = pads[index].position
        }
    }

    /// Dirt, grass line and a wooden barricade, all built from flat blocks for a pixel look.
    private func drawBackground() {
        background.removeAllChildren()
        guard size.width > 0 else { return }

        let dirt = SKSpriteNode(color: Palette.dirt, size: CGSize(width: size.width, height: groundHeight))
        dirt.anchorPoint = .zero
        background.addChild(dirt)

        var rng = SystemRandomNumberGenerator()
        for _ in 0..<Int(size.width / 6) {
            let speck = SKSpriteNode(color: Palette.dirtSpeck, size: CGSize(width: 4, height: 4))
            speck.position = CGPoint(x: CGFloat.random(in: 0...size.width, using: &rng),
                                     y: CGFloat.random(in: 4...(groundHeight - 8), using: &rng))
            background.addChild(speck)
        }

        let grass = SKSpriteNode(color: Palette.ground, size: CGSize(width: size.width, height: 6))
        grass.anchorPoint = .zero
        grass.position = CGPoint(x: 0, y: groundHeight - 6)
        background.addChild(grass)

        // Barricade: two rails with posts.
        for railY in [barricadeY - 2, barricadeY + 8] {
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
            post.position = CGPoint(x: x, y: barricadeY - 6)
            post.zPosition = 6
            background.addChild(post)
            x += 44
        }
    }

    // MARK: Game flow

    func startGame() {
        zombies.forEach { $0.removeFromParent() }
        zombies.removeAll()
        bullets.forEach { $0.removeFromParent() }
        bullets.removeAll()
        wave = 0
        toSpawn = 0
        playerCooldown = 0
        intermission = 1.0
        syncTurrets()
        isRunning = true
    }

    func endGame() {
        isRunning = false
        zombies.forEach { $0.removeAction(forKey: "walk") }
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
            turret.position = pads[index].position
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

    private func startNextWave() {
        wave += 1
        model?.waveStarted(wave)
        toSpawn = min(60, 5 + wave * 2)
        spawnInterval = max(0.35, 1.1 - Double(wave) * 0.04)
        spawnTimer = 0
        showBanner("WAVE \(wave)")
    }

    private func spawnZombie() {
        let kind: Zombie.Kind
        let isFirstOfWave = toSpawn == min(60, 5 + wave * 2)
        if wave % 5 == 0 && isFirstOfWave {
            kind = .boss
        } else {
            let roll = CGFloat.random(in: 0...1)
            if wave >= 5 && roll < 0.15 {
                kind = .brute
            } else if wave >= 3 && roll < 0.40 {
                kind = .runner
            } else {
                kind = .walker
            }
        }

        let hpScale = pow(1.17, CGFloat(wave - 1))
        let speedScale = 1 + min(0.6, CGFloat(wave) * 0.02)
        let zombie = Zombie(kind: kind, hpScale: hpScale, speedScale: speedScale)
        let half = zombie.size.width / 2
        zombie.position = CGPoint(x: CGFloat.random(in: half...max(half, size.width - half)),
                                  y: size.height + zombie.size.height / 2)
        zombie.zPosition = 10
        addChild(zombie)
        zombies.append(zombie)
    }

    // MARK: Frame update

    override func update(_ currentTime: TimeInterval) {
        let rawDt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 20.0)
        lastUpdate = currentTime
        guard isRunning, let model = model else { return }
        let dt = rawDt * Double(speed) // 2x speed button doubles game time

        // Waves
        if toSpawn > 0 {
            spawnTimer -= dt
            if spawnTimer <= 0 {
                spawnZombie()
                toSpawn -= 1
                spawnTimer = spawnInterval
            }
        } else if zombies.isEmpty {
            intermission -= dt
            if intermission <= 0 {
                intermission = 2.0
                startNextWave()
            }
        }

        // Zombies walk toward the barricade.
        for zombie in zombies {
            zombie.position.y -= zombie.walkSpeed * CGFloat(dt)
            if zombie.position.y - zombie.size.height / 2 <= barricadeY + 10 {
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
        remove(zombie)
        model?.zombieKilled(reward: zombie.kind.reward)
        splat(at: zombie.position, size: zombie.size.width)
        popLabel("+\(zombie.kind.reward)", at: zombie.position)
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
            let distance = CGFloat.random(in: 10...(size * 0.9))
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

    private func showBanner(_ text: String) {
        let label = SKLabelNode(text: text)
        label.fontName = "Menlo-Bold"
        label.fontSize = 40
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        label.zPosition = 50
        label.alpha = 0
        addChild(label)
        label.run(.sequence([
            .fadeIn(withDuration: 0.2), .wait(forDuration: 1.0),
            .fadeOut(withDuration: 0.4), .removeFromParent(),
        ]))
    }
}
