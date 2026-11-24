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
    private(set) var poisonLeft: TimeInterval = 0
    private var poisonDPS: CGFloat = 0
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
    func takeHit(_ damage: CGFloat, flash: Bool = true) -> Bool {
        hp -= damage
        hpBack.isHidden = false
        hpBar.xScale = max(0, hp / maxHP)
        if flash {
            colorBlendFactor = 0.75
            run(.colorize(withColorBlendFactor: 0, duration: 0.12), withKey: "flash")
        }
        return hp <= 0
    }

    /// Poison deals damage over time; a new dose refreshes it (keeping the stronger one).
    func poison(dps: CGFloat, duration: TimeInterval) {
        poisonDPS = max(poisonDPS, dps)
        poisonLeft = duration
        hpBack.isHidden = false
        hpBar.color = Perk.poison.color
    }

    /// Returns true if the poison killed the zombie.
    func tickPoison(_ dt: TimeInterval) -> Bool {
        guard poisonLeft > 0 else { return false }
        let step = min(dt, poisonLeft)
        poisonLeft -= step
        if poisonLeft <= 0 {
            poisonDPS = 0
            hpBar.color = .red
        }
        return takeHit(poisonDPS * CGFloat(step), flash: false)
    }
}

// MARK: - Bullet

/// A dropped perk waiting on the battlefield to be tapped.
private final class PerkToken: SKShapeNode {
    var perk: Perk = .doubleMoney
    var collected = false
}

private final class Bullet: SKSpriteNode {
    var velocity = CGVector.zero
    var damage: CGFloat = 1
    /// How many more zombies it can pass through.
    var pierce = 1
    /// Distance left before it fades out (nil = unlimited).
    var rangeLeft: CGFloat?
    /// Zombies already hit, so a piercing bullet doesn't hit the same one twice.
    var hits = Set<ObjectIdentifier>()
    /// Sets zombies on fire (flamethrower, Torch's passive).
    var burns = false
}

private extension UIColor {
    /// Blend toward another color (t = 0...1).
    func mixed(with other: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}

/// Smooth ease-in-out for 0...1.
private func smoothstep(_ x: CGFloat) -> CGFloat {
    let t = min(max(x, 0), 1)
    return t * t * (3 - 2 * t)
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
    /// Nights are considerably shorter than days: this fraction of a day wave's zombies.
    private let nightLengthMultiplier: CGFloat = 0.5
    /// The 8 turret/catapult slots: two rows of four, two each side of the survivor.
    /// (fraction of width, height above bottom), listed in unlock order:
    /// the 2 free inner-upper slots, then inner-lower, then outer-upper, then outer-lower.
    private let slotLayout: [(x: CGFloat, y: CGFloat)] = [
        (0.29, 62), (0.71, 62),
        (0.29, 8), (0.71, 8),
        (0.09, 62), (0.91, 62),
        (0.09, 8), (0.91, 8),
    ]

    // MARK: Nodes
    private let sky = SKSpriteNode(color: .white, size: .zero)
    private let stars = SKNode()
    private let background = SKNode()
    private let survivor = SKSpriteNode(texture: Hero.rook.texture,
                                        size: PixelArt.size(Sprites.survivorRows, pixel: 4))
    private var slotNodes: [SKNode] = []
    private var slotShown: [SlotState?] = []
    private var slotShownLevel: [Int] = []
    private let gunSprite = SKSpriteNode(texture: Sprites.gunTexture(.pistol))
    private let ammoLabel = SKLabelNode(fontNamed: "Futura-CondensedExtraBold")
    private var ammo: [Gun: Int] = [:]
    private var reloadLeft: TimeInterval = 0
    private var slotCooldowns: [TimeInterval] = []
    private var zombies: [Zombie] = []
    private var bullets: [Bullet] = []

    // Atmosphere
    private let fogLayer = SKNode()
    private var fogBanks: [(node: SKSpriteNode, speed: CGFloat)] = []
    private let vignette = SKSpriteNode(texture: EffectTextures.vignette)
    private let dangerVignette = SKSpriteNode(texture: EffectTextures.dangerVignette)
    private let grain = SKSpriteNode(texture: EffectTextures.grain)
    private var grainTimer: TimeInterval = 0
    private var decals: [SKNode] = []
    private var isDanger = false

    // Region look and difficulty (Endless uses the defaults)
    private var theme = RegionTheme.endless
    private var hpMultiplier: CGFloat = 1
    private var speedMultiplier: CGFloat = 1
    private var extraZombies = 0
    private var typeHeadStart = 0

    // Hero ability and passive timers (wave time)
    private var abilityLeft: TimeInterval = 0
    private var publishedAbility = 0
    private var overclockLeft: TimeInterval = 0
    private var deadeyeLeft: TimeInterval = 0
    private var firewallLeft: TimeInterval = 0
    private var firewall: SKNode?
    private var regenTimer: TimeInterval = 10
    private let groundShade = SKSpriteNode(color: .black, size: .zero)
    /// 0 = full day, 0.5 = dusk, 1 = full night. Eases toward `targetDarkness`.
    private var darkness: CGFloat = 0
    private var targetDarkness: CGFloat = 0
    private var darknessRate: CGFloat = 0.25   // change per second
    private static let duskSky = UIColor(red: 0.30, green: 0.11, blue: 0.07, alpha: 1)

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
    private var perkTime: [Perk: TimeInterval] = [:]
    private var publishedPerks: [Perk: Int] = [:]

    private func perkActive(_ perk: Perk) -> Bool { perkTime[perk, default: 0] > 0 }

    private static let daySky = Palette.daySky
    private static let nightSky = Palette.nightSky

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = Palette.sky
        guard !hasSetUp else { return }
        hasSetUp = true

        sky.anchorPoint = .zero
        sky.zPosition = -20
        sky.colorBlendFactor = 1
        sky.color = theme.daySky
        addChild(sky)
        stars.zPosition = -19
        stars.alpha = 0
        addChild(stars)
        addChild(background)

        fogLayer.zPosition = 12           // drifts over the zombies, under the bullets
        fogLayer.alpha = 0.22
        addChild(fogLayer)
        for overlay in [dangerVignette, vignette, grain] {
            overlay.anchorPoint = .zero
            addChild(overlay)
        }
        dangerVignette.zPosition = 59
        dangerVignette.alpha = 0
        vignette.zPosition = 60
        vignette.alpha = 0.85
        grain.zPosition = 61
        grain.alpha = 0.07

        survivor.anchorPoint = CGPoint(x: 0.5, y: 0)
        survivor.zPosition = 20
        addChild(survivor)
        gunSprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        gunSprite.position = CGPoint(x: 14, y: 28)   // in his raised hand
        gunSprite.zPosition = 1
        survivor.addChild(gunSprite)
        ammoLabel.fontSize = 13
        ammoLabel.fontColor = Palette.bone
        ammoLabel.zPosition = 21
        addChild(ammoLabel)
        groundShade.anchorPoint = .zero
        groundShade.zPosition = 7          // darkens the ground at night, under defenders and zombies
        groundShade.alpha = 0
        addChild(groundShade)
        weaponChanged()

        for _ in slotLayout {
            let node = SKNode()
            node.zPosition = 15
            addChild(node)
            slotNodes.append(node)
            slotShown.append(nil)
            slotShownLevel.append(0)
            slotCooldowns.append(0)
        }
        layout()
        syncSlots()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if hasSetUp && size.width > 0 && size.height > 0 { layout() }
    }

    private func layout() {
        sky.size = size
        vignette.size = size
        dangerVignette.size = size
        grain.size = CGSize(width: size.width * 1.3, height: size.height * 1.3)
        buildFog()
        drawStars()
        drawBackground()
        survivor.position = CGPoint(x: size.width / 2, y: 30)
        ammoLabel.position = CGPoint(x: size.width / 2, y: 14)
        groundShade.size = CGSize(width: size.width, height: groundHeight + 30)
        applyDarkness()
        for (index, node) in slotNodes.enumerated() {
            node.position = slotPosition(index)
        }
    }

    private func slotPosition(_ index: Int) -> CGPoint {
        CGPoint(x: size.width * slotLayout[index].x, y: slotLayout[index].y)
    }

    /// Dirt, grass line and a wooden barricade, all built from flat blocks for a pixel look.
    private func drawBackground() {
        background.removeAllChildren()
        guard size.width > 0 else { return }

        let dirt = SKSpriteNode(color: theme.dirt, size: CGSize(width: size.width, height: groundHeight))
        dirt.anchorPoint = .zero
        background.addChild(dirt)

        for _ in 0..<Int(size.width / 4) {
            let speck = SKSpriteNode(color: theme.dirtSpeck, size: CGSize(width: 4, height: 4))
            speck.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                     y: CGFloat.random(in: 4...(groundHeight - 8)))
            background.addChild(speck)
        }

        let grass = SKSpriteNode(color: theme.grass, size: CGSize(width: size.width, height: 6))
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
        for _ in 0..<30 {
            let star = SKSpriteNode(color: UIColor(white: 1, alpha: CGFloat.random(in: 0.15...0.5)),
                                    size: CGSize(width: 2, height: 2))
            star.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                    y: CGFloat.random(in: (groundHeight + 40)...size.height))
            stars.addChild(star)
        }
        // Blood moon with a soft red halo.
        let moonPosition = CGPoint(x: size.width * 0.82, y: size.height - 50)
        let halo = SKSpriteNode(texture: EffectTextures.fog, size: CGSize(width: 130, height: 130))
        halo.color = Palette.bloodRed
        halo.colorBlendFactor = 1
        halo.alpha = 0.6
        halo.position = moonPosition
        stars.addChild(halo)
        let moon = SKShapeNode(circleOfRadius: 18)
        moon.fillColor = UIColor(red: 0.72, green: 0.12, blue: 0.08, alpha: 1)
        moon.strokeColor = UIColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 0.6)
        moon.lineWidth = 1.5
        moon.position = moonPosition
        stars.addChild(moon)
    }

    private func setNight(_ night: Bool) {
        isNight = night
        fadeDarkness(to: night ? 1 : 0, over: night ? 3.5 : 6)
    }

    /// Start a slow blend of the whole scene toward a darkness level.
    private func fadeDarkness(to target: CGFloat, over seconds: TimeInterval) {
        targetDarkness = target
        darknessRate = max(0.01, abs(target - darkness) / CGFloat(seconds))
    }

    /// Paint sky, stars, moon, fog, vignette and ground for the current darkness.
    /// Day -> dusk (burnt red) -> blood-moon night, each step eased.
    private func applyDarkness() {
        let d = darkness
        sky.color = d <= 0.5
            ? theme.daySky.mixed(with: theme.duskSky, smoothstep(d / 0.5))
            : theme.duskSky.mixed(with: theme.nightSky, smoothstep((d - 0.5) / 0.5))
        let nightAmount = smoothstep((d - 0.4) / 0.6)
        stars.alpha = nightAmount
        stars.position.y = (1 - nightAmount) * 40          // the moon rises as night falls
        fogLayer.alpha = 0.22 + 0.16 * smoothstep(d)
        let fogColor = theme.fogDay.mixed(with: theme.fogNight, smoothstep(d))
        for bank in fogBanks { bank.node.color = fogColor }
        vignette.alpha = 0.85 + 0.15 * smoothstep(d)
        groundShade.alpha = 0.45 * smoothstep(d)
    }

    // MARK: Atmosphere

    private func buildFog() {
        fogLayer.removeAllChildren()
        fogBanks.removeAll()
        guard size.width > 0, size.height > groundHeight + 60 else { return }
        for _ in 0..<6 {
            let bank = SKSpriteNode(texture: EffectTextures.fog,
                                    size: CGSize(width: size.width * CGFloat.random(in: 0.8...1.3),
                                                 height: CGFloat.random(in: 110...190)))
            bank.color = theme.fogDay.mixed(with: theme.fogNight, smoothstep(darkness))
            bank.colorBlendFactor = 1
            bank.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                    y: CGFloat.random(in: (groundHeight + 30)...(size.height * 0.85)))
            fogLayer.addChild(bank)
            let speed = CGFloat.random(in: 6...16) * (Bool.random() ? 1 : -1)
            fogBanks.append((bank, speed))
        }
    }

    /// Fog drifts and grain jitters all the time, even between waves.
    private func animateAtmosphere(_ dt: TimeInterval) {
        if darkness != targetDarkness {
            let step = darknessRate * CGFloat(dt)
            darkness = darkness < targetDarkness ? min(targetDarkness, darkness + step)
                                                  : max(targetDarkness, darkness - step)
            applyDarkness()
        }
        for bank in fogBanks {
            bank.node.position.x += bank.speed * CGFloat(dt)
            let half = bank.node.size.width / 2
            if bank.speed > 0 && bank.node.position.x - half > size.width { bank.node.position.x = -half }
            if bank.speed < 0 && bank.node.position.x + half < 0 { bank.node.position.x = size.width + half }
        }
        grainTimer -= dt
        if grainTimer <= 0 {
            grainTimer = 0.05
            grain.position = CGPoint(x: -CGFloat.random(in: 0...(size.width * 0.3)),
                                     y: -CGFloat.random(in: 0...(size.height * 0.3)))
        }
    }

    /// Red pulsing edges when the barricade is about to fall.
    func setDanger(_ on: Bool) {
        guard on != isDanger else { return }
        isDanger = on
        dangerVignette.removeAllActions()
        if on {
            dangerVignette.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.9, duration: 0.45), .fadeAlpha(to: 0.3, duration: 0.45),
            ])))
        } else {
            dangerVignette.run(.fadeOut(withDuration: 0.3))
        }
    }

    /// Blood stays on the ground for a while, then soaks away.
    private func bloodDecal(at point: CGPoint, size spread: CGFloat) {
        let decal = SKNode()
        decal.position = point
        decal.zPosition = 2
        let pieces = spread > 40 ? 14 : 7
        for _ in 0..<pieces {
            let side = [4, 4, 6, 8].randomElement() ?? 4
            let drop = SKSpriteNode(color: Bool.random() ? Palette.blood : Palette.bloodDark,
                                    size: CGSize(width: side, height: side))
            drop.position = CGPoint(x: CGFloat.random(in: -spread * 0.45...spread * 0.45),
                                    y: CGFloat.random(in: -spread * 0.25...spread * 0.25))
            decal.addChild(drop)
        }
        addChild(decal)
        decals.append(decal)
        if decals.count > 50 {
            decals.removeFirst().removeFromParent()
        }
        decal.run(.sequence([.wait(forDuration: 8), .fadeOut(withDuration: 4), .removeFromParent()]))
    }

    /// Flickering blood-red wave number with a red flash, like a dying light.
    private func showWaveIntro(night: Bool, label: String) {
        let flash = SKSpriteNode(color: Palette.bloodRed, size: size)
        flash.anchorPoint = .zero
        flash.zPosition = 65
        flash.alpha = night ? 0.45 : 0.3
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.6), .removeFromParent()]))

        let heading = SKLabelNode(text: night ? "NIGHT FALLS" : "WAVE")
        heading.fontName = "Futura-CondensedExtraBold"
        heading.fontSize = 24
        heading.fontColor = Palette.bone
        heading.position = CGPoint(x: size.width / 2, y: size.height * 0.62)

        let number = SKLabelNode(text: label)
        number.fontName = "Futura-CondensedExtraBold"
        number.fontSize = 104
        number.fontColor = Palette.bloodRed
        number.position = CGPoint(x: size.width / 2, y: size.height * 0.62 - 100)

        let flicker = SKAction.sequence([
            .fadeAlpha(to: 1, duration: 0.04), .wait(forDuration: 0.08),
            .fadeAlpha(to: 0.15, duration: 0.03), .wait(forDuration: 0.07),
            .fadeAlpha(to: 1, duration: 0.03), .wait(forDuration: 1.1),
            .fadeAlpha(to: 0.3, duration: 0.04), .fadeAlpha(to: 1, duration: 0.04),
            .wait(forDuration: 0.25), .fadeOut(withDuration: 0.5), .removeFromParent(),
        ])
        for label in [heading, number] {
            label.zPosition = 70
            label.alpha = 0
            label.name = "fx"
            addChild(label)
            label.run(flicker)
        }
        number.setScale(1.6)
        number.run(.scale(to: 1, duration: 0.25))
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // MARK: Game flow

    func startGame() {
        zombies.forEach { $0.removeFromParent() }
        zombies.removeAll()
        bullets.forEach { $0.removeFromParent() }
        bullets.removeAll()
        enumerateChildNodes(withName: "fx") { node, _ in node.removeFromParent() }
        wave = 0
        waveActive = false
        toSpawn = 0
        playerCooldown = 0
        configureForRun()
        isNight = false
        darkness = 0
        targetDarkness = 0
        applyDarkness()
        ammo = [:]
        reloadLeft = 0
        weaponChanged()
        decals.forEach { $0.removeFromParent() }
        decals.removeAll()
        isDanger = true
        setDanger(false)
        perkTime = [:]
        publishedPerks = [:]
        model?.perksChanged([:])
        slotCooldowns = slotCooldowns.map { _ in 0 }
        syncSlots()
        isRunning = true
        showBanner("PRESS ▶ TO START", size: 24, hold: 2.0)
    }

    /// Pick up the region's look and difficulty, and the hero, for a new run.
    private func configureForRun() {
        let region = model?.region
        theme = region?.theme ?? .endless
        hpMultiplier = region?.healthMultiplier ?? 1
        speedMultiplier = region?.speedMultiplier ?? 1
        extraZombies = region?.extraZombies ?? 0
        typeHeadStart = region?.typeHeadStart ?? 0
        resetHeroTimers()
        survivor.texture = model?.hero.texture ?? Hero.rook.texture
        if size.width > 0 { layout() }   // redraw ground and fog in the region's colors
    }

    private func resetHeroTimers() {
        abilityLeft = 0
        publishedAbility = -1
        overclockLeft = 0
        deadeyeLeft = 0
        firewallLeft = 0
        firewall?.removeFromParent()
        firewall = nil
        regenTimer = 10
        survivor.colorBlendFactor = 0
        publishAbility()
    }

    /// Swap the survivor's look and gun when a different hero is chosen between waves.
    func heroChanged() {
        guard let model = model else { return }
        survivor.texture = model.hero.texture
        resetHeroTimers()
        weaponChanged(refill: true)
        pop(survivor)
    }

    func endGame() {
        isRunning = false
        waveActive = false
        zombies.forEach { $0.removeAction(forKey: "walk") }
    }

    /// Called when the player presses Play between waves.
    func startNextWave() {
        guard isRunning, !waveActive, let model = model else { return }
        // A night is a half-wave (e.g. 3.5) that keeps the day's number; otherwise move to the next day.
        let night = model.nextIsNight
        if !night { wave += 1 }
        waveActive = true
        if night != isNight { setNight(night) }

        let dayCount = min(70, 5 + wave * 2 + extraZombies)
        totalThisWave = night ? max(4, Int(CGFloat(dayCount) * nightLengthMultiplier)) : dayCount
        toSpawn = totalThisWave
        spawnInterval = max(0.35, 1.1 - Double(wave) * 0.04) * (night ? 0.8 : 1)
        spawnTimer = 0.6
        model.waveStarted(wave, night: night)
        showWaveIntro(night: night, label: model.waveLabel)
    }

    private func waveCleared() {
        waveActive = false
        let label = model?.waveLabel ?? "\(wave)"
        model?.waveCleared()
        // Campaign: clearing the region's last day wave ends the region.
        if !isNight, let limit = model?.regionWaves, wave >= limit {
            model?.regionCompleted()
            return
        }
        showBanner("WAVE \(label) CLEARED", size: 26, hold: 1.2)
        // Dusk creeps in while you shop before a night; dawn breaks after one.
        if isNight {
            fadeDarkness(to: 0, over: 6)
        } else if model?.nextIsNight == true {
            fadeDarkness(to: 0.5, over: 5)
        }
        // Fresh magazine between waves.
        if let model = model {
            ammo[model.equippedGun] = model.magazineSize
            reloadLeft = 0
            updateAmmoLabel()
        }
    }

    /// Redraw each slot to match the model: padlock, empty pad, turret or catapult.
    func syncSlots() {
        guard let model = model, !slotNodes.isEmpty else { return }
        for (index, node) in slotNodes.enumerated() {
            let state = model.slots[index]
            let isNextLocked = index == model.nextLockedSlot
            let level = model.slotLevels[index]
            // Locked slots are redrawn every time so the "next unlock" price stays current.
            guard slotShown[index] != state || state == .locked || slotShownLevel[index] != level else { continue }
            let wasShown = slotShown[index]
            let wasUpgrade = wasShown == state && slotShownLevel[index] < level
            slotShown[index] = state
            slotShownLevel[index] = level
            node.removeAllChildren()
            if state == .turret || state == .catapult {
                let badge = SKLabelNode(text: "LV\(level)")
                badge.fontName = "Futura-CondensedExtraBold"
                badge.fontSize = 10
                badge.fontColor = level >= GameModel.maxDefenseLevel ? Palette.bloodRed : Palette.bone
                badge.horizontalAlignmentMode = .left
                badge.position = CGPoint(x: 12, y: 36)
                badge.zPosition = 2
                node.addChild(badge)
                if wasUpgrade {
                    pop(node)
                    burstSparks(at: CGPoint(x: node.position.x, y: node.position.y + 20))
                }
            }

            switch state {
            case .locked:
                let pad = SKSpriteNode(texture: Sprites.pad, size: PixelArt.size(Sprites.padRows, pixel: 4))
                pad.anchorPoint = CGPoint(x: 0.5, y: 0)
                pad.alpha = 0.4
                node.addChild(pad)
                let lock = SKSpriteNode(texture: Sprites.lock, size: PixelArt.size(Sprites.lockRows, pixel: 3))
                lock.position = CGPoint(x: 0, y: 18)
                lock.alpha = isNextLocked ? 1 : 0.45
                node.addChild(lock)
                if isNextLocked, let cost = model.unlockCost {
                    let price = SKLabelNode(text: "\u{2620}\u{FE0E}\(cost)")
                    price.fontName = "Futura-CondensedExtraBold"
                    price.fontSize = 12
                    price.fontColor = Palette.bloodRed
                    price.position = CGPoint(x: 0, y: -2)
                    node.addChild(price)
                }
            case .empty:
                let pad = SKSpriteNode(texture: Sprites.pad, size: PixelArt.size(Sprites.padRows, pixel: 4))
                pad.anchorPoint = CGPoint(x: 0.5, y: 0)
                node.addChild(pad)
                pad.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.6),
                                                   .fadeAlpha(to: 1, duration: 0.6)])))
                if wasShown == .locked {
                    pop(node)
                }
            case .turret:
                let turret = SKSpriteNode(texture: Sprites.turret, size: PixelArt.size(Sprites.turretRows, pixel: 4))
                turret.anchorPoint = CGPoint(x: 0.5, y: 0)
                turret.name = "body"
                node.addChild(turret)
                slotCooldowns[index] = 0
                if wasShown != nil { pop(node) }
            case .catapult:
                let catapult = SKSpriteNode(texture: Sprites.catapult, size: PixelArt.size(Sprites.catapultRows, pixel: 4))
                catapult.anchorPoint = CGPoint(x: 0.5, y: 0)
                catapult.name = "body"
                node.addChild(catapult)
                slotCooldowns[index] = 0.5
                if wasShown != nil { pop(node) }
            }
        }
    }

    /// Little shower of sparks when a defense levels up.
    private func burstSparks(at point: CGPoint) {
        for _ in 0..<10 {
            let spark = SKSpriteNode(color: Palette.bullet, size: CGSize(width: 3, height: 3))
            spark.position = point
            spark.zPosition = 40
            spark.name = "fx"
            addChild(spark)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let move = SKAction.moveBy(x: cos(angle) * 30, y: sin(angle) * 30, duration: 0.35)
            spark.run(.sequence([.group([move, .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        }
    }

    private func pop(_ node: SKNode) {
        node.setScale(0.2)
        node.run(.scale(to: 1, duration: 0.2))
    }

    /// A short banner, e.g. for a slot unlocking or a perk.
    func announce(_ text: String) {
        showBanner(text, size: 24, hold: 1.0, y: 0.45)
    }

    /// Which zombie types can appear, and how often, by wave.
    private func randomKind() -> Zombie.Kind {
        // Harder regions bring the nasty types in earlier.
        let wave = self.wave + typeHeadStart
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
        let isFinalWave = !isNight && model?.regionWaves == wave
        if !isNight && (wave % 5 == 0 || isFinalWave) && toSpawn == totalThisWave {
            kind = .boss
        } else {
            kind = randomKind()
        }
        let count = kind == .crawler ? 3 : 1
        for _ in 0..<count {
            spawnZombie(kind)
        }
    }

    /// Zombie health multiplier right now: per wave, night boost, and the region's
    /// exponential difficulty. Abilities scale their damage with this too.
    private var currentHPScale: CGFloat {
        var scale = pow(1.17, CGFloat(max(wave, 1) - 1) + (isNight ? 0.5 : 0)) * hpMultiplier
        if isNight { scale *= nightHPMultiplier }
        return scale
    }

    private func spawnZombie(_ kind: Zombie.Kind) {
        // Health climbs every wave, and night waves get an extra boost.
        // Nights sit half a wave further along (3.5) on the health curve.
        let hpScale = currentHPScale
        var speedScale = (1 + min(0.6, CGFloat(wave) * 0.02)) * speedMultiplier
        if isNight {
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
        animateAtmosphere(rawDt)
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

        // Perk timers only run down during a wave, not while you shop between waves.
        if waveActive {
            tickPerks(dt)
            tickHero(dt, model: model)
        }

        // Poison damage over time
        for zombie in zombies where zombie.poisonLeft > 0 {
            if zombie.tickPoison(dt) { kill(zombie) }
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

        // The survivor fires the equipped gun.
        updateGun(dt, model: model)

        // Turrets and catapults
        for index in slotNodes.indices {
            let state = model.slots[index]
            guard state == .turret || state == .catapult else { continue }
            slotCooldowns[index] -= dt * (overclockLeft > 0 ? 2.5 : 1)
            guard slotCooldowns[index] <= 0, let target = closestZombies(1).first else { continue }
            let node = slotNodes[index]
            if state == .turret {
                let muzzle = CGPoint(x: node.position.x, y: node.position.y + 36)
                fire(from: muzzle, at: target, damage: model.turretDamage(slot: index), color: Palette.turretBullet)
                flash(at: muzzle)
                slotCooldowns[index] = model.turretInterval(slot: index)
            } else {
                launchRock(from: CGPoint(x: node.position.x + 12, y: node.position.y + 40), at: target,
                           damage: model.catapultDamage(slot: index), radius: model.catapultRadius(slot: index))
                if let body = node.childNode(withName: "body") {
                    body.run(.sequence([.scaleY(to: 0.85, duration: 0.06), .scaleY(to: 1, duration: 0.12)]))
                }
                slotCooldowns[index] = model.catapultInterval(slot: index)
            }
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

    // MARK: Hero abilities and passives

    private func tickHero(_ dt: TimeInterval, model: GameModel) {
        if abilityLeft > 0 {
            abilityLeft = max(0, abilityLeft - dt)
            publishAbility()
        }
        overclockLeft = max(0, overclockLeft - dt)
        if deadeyeLeft > 0 {
            deadeyeLeft -= dt
            if deadeyeLeft <= 0 { survivor.run(.colorize(withColorBlendFactor: 0, duration: 0.2)) }
        }
        if firewallLeft > 0 {
            firewallLeft -= dt
            burnFirewall(dt)
            if firewallLeft <= 0 {
                firewall?.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
                firewall = nil
            }
        }
        // Doc's passive: slow barricade repairs during waves.
        if model.hero.regenerates {
            regenTimer -= dt
            if regenTimer <= 0 {
                regenTimer = 10
                if model.baseHP < model.maxBaseHP {
                    model.repairBarricade(1)
                    popLabel("+1 HP", at: CGPoint(x: size.width / 2, y: barricadeY + 30))
                }
            }
        }
    }

    private func publishAbility() {
        let seconds = Int(abilityLeft.rounded(.up))
        if seconds != publishedAbility {
            publishedAbility = seconds
            model?.abilityCooldownChanged(seconds)
        }
    }

    /// Fire the current hero's tap ability.
    func useAbility() {
        guard isRunning, waveActive, abilityLeft <= 0, let model = model else { return }
        let hero = model.hero
        abilityLeft = hero.abilityCooldown
        publishAbility()
        announce(hero.abilityName.uppercased() + "!")
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let power = currentHPScale

        switch hero {
        case .rook:
            // Frag grenade into the nearest pack.
            let target = closestZombies(1).first?.position ?? CGPoint(x: size.width / 2, y: size.height * 0.5)
            lob(to: target, from: gunMuzzle) { [weak self] in
                self?.explode(at: target, radius: 85, damage: 8 * power)
            }
        case .mags:
            overclockLeft = 6
            for node in slotNodes where !node.children.isEmpty {
                burstSparks(at: CGPoint(x: node.position.x, y: node.position.y + 20))
            }
        case .doc:
            model.repairBarricade(6)
            popLabel("+6 HP", at: CGPoint(x: size.width / 2, y: barricadeY + 30))
            burstSparks(at: CGPoint(x: size.width / 2, y: barricadeY + 10))
        case .vix:
            deadeyeLeft = 6
            survivor.color = Palette.bloodRed
            survivor.run(.colorize(withColorBlendFactor: 0.45, duration: 0.15))
        case .torch:
            startFirewall()
        case .sarge:
            airstrike(damage: 5 * power)
        }
    }

    /// A grenade arc from the hero to a point, then a callback on landing.
    private func lob(to target: CGPoint, from origin: CGPoint, landed: @escaping () -> Void) {
        let grenade = SKSpriteNode(color: UIColor(red: 0.25, green: 0.30, blue: 0.20, alpha: 1),
                                   size: CGSize(width: 7, height: 7))
        grenade.position = origin
        grenade.zPosition = 35
        grenade.name = "fx"
        addChild(grenade)
        let flight: TimeInterval = 0.55
        let move = SKAction.move(to: target, duration: flight)
        move.timingMode = .easeOut
        let arc = SKAction.sequence([.scale(to: 2, duration: flight / 2), .scale(to: 1, duration: flight / 2)])
        grenade.run(.sequence([.group([move, arc, .rotate(byAngle: .pi * 4, duration: flight)]),
                               .run(landed), .removeFromParent()]))
    }

    /// Fiery blast that damages everything in range.
    private func explode(at point: CGPoint, radius: CGFloat, damage: CGFloat) {
        guard isRunning else { return }
        let blast = SKShapeNode(circleOfRadius: radius)
        blast.position = point
        blast.fillColor = UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 0.45)
        blast.strokeColor = UIColor(red: 1.0, green: 0.85, blue: 0.40, alpha: 0.9)
        blast.lineWidth = 3
        blast.zPosition = 36
        blast.setScale(0.2)
        blast.name = "fx"
        addChild(blast)
        blast.run(.sequence([.group([.scale(to: 1, duration: 0.15), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        background.run(.sequence([.moveBy(x: 5, y: 0, duration: 0.03), .moveBy(x: -10, y: 0, duration: 0.06),
                                  .moveBy(x: 5, y: 0, duration: 0.03)]))
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        let caught = zombies.filter { hypot($0.position.x - point.x, $0.position.y - point.y) < radius }
        for victim in caught {
            applyDamage(damage, to: victim, canPoison: false)
        }
    }

    /// Sarge: a line of blasts walking down the field over the zombies.
    private func airstrike(damage: CGFloat) {
        var targets = zombies.filter { $0.position.y < size.height }.shuffled().prefix(6).map(\.position)
        while targets.count < 6 {
            targets.append(CGPoint(x: CGFloat.random(in: 30...max(31, size.width - 30)),
                                   y: CGFloat.random(in: (barricadeY + 60)...max(barricadeY + 61, size.height * 0.85))))
        }
        for (index, point) in targets.enumerated() {
            run(.sequence([.wait(forDuration: 0.3 + Double(index) * 0.15),
                           .run { [weak self] in self?.explode(at: point, radius: 70, damage: damage) }]))
        }
    }

    /// Torch: a band of fire across the field that burns zombies walking through it.
    private func startFirewall() {
        firewall?.removeFromParent()
        let wall = SKNode()
        wall.position = CGPoint(x: 0, y: firewallY)
        wall.zPosition = 11
        wall.name = "fx"
        var x: CGFloat = 0
        while x < size.width {
            let flame = SKSpriteNode(color: UIColor(red: 1.0, green: CGFloat.random(in: 0.3...0.6), blue: 0.1, alpha: 0.85),
                                     size: CGSize(width: 8, height: CGFloat.random(in: 14...30)))
            flame.anchorPoint = CGPoint(x: 0.5, y: 0)
            flame.position = CGPoint(x: x, y: -14)
            let flicker = SKAction.sequence([.scaleY(to: CGFloat.random(in: 0.5...0.8), duration: 0.08),
                                             .scaleY(to: CGFloat.random(in: 1.0...1.4), duration: 0.1)])
            flame.run(.repeatForever(flicker))
            wall.addChild(flame)
            x += 8
        }
        addChild(wall)
        firewall = wall
        firewallLeft = 5
    }

    private var firewallY: CGFloat { barricadeY + (size.height - barricadeY) * 0.35 }

    private func burnFirewall(_ dt: TimeInterval) {
        let band = (firewallY - 20)...(firewallY + 20)
        let dps = 2.5 * currentHPScale
        for zombie in zombies where band.contains(zombie.position.y) {
            if zombie.takeHit(dps * CGFloat(dt), flash: false) { kill(zombie) }
        }
    }

    // MARK: The survivor's gun

    /// Swap the gun art and ammo after buying, switching or a magazine upgrade.
    func weaponChanged(refill: Bool = false) {
        guard let model = model else { return }
        let gun = model.equippedGun
        gunSprite.removeAction(forKey: "reload")
        gunSprite.zRotation = 0
        gunSprite.texture = Sprites.gunTexture(gun)
        gunSprite.size = PixelArt.size(Sprites.gunRows(gun), pixel: 4)
        let mag = model.magazineSize
        if refill || ammo[gun] == nil {
            ammo[gun] = mag
        }
        ammo[gun] = min(ammo[gun] ?? mag, mag)
        reloadLeft = (ammo[gun] ?? 0) <= 0 ? model.reloadTime : 0
        playerCooldown = min(playerCooldown, 0.2)
        updateAmmoLabel()
    }

    private var gunMuzzle: CGPoint {
        CGPoint(x: survivor.position.x + gunSprite.position.x,
                y: survivor.position.y + gunSprite.position.y + gunSprite.size.height)
    }

    private func updateGun(_ dt: TimeInterval, model: GameModel) {
        let gun = model.equippedGun
        if reloadLeft > 0 {
            reloadLeft -= dt
            if reloadLeft <= 0 {
                ammo[gun] = model.magazineSize
                updateAmmoLabel()
            }
            return
        }
        playerCooldown -= dt
        guard playerCooldown <= 0, let target = closestZombies(1).first else { return }

        let muzzle = gunMuzzle
        let damage = model.gunDamage * (deadeyeLeft > 0 ? 2.5 : 1)
        for _ in 0..<gun.pellets {
            fire(from: muzzle, at: target, damage: damage, color: gun.bulletColor,
                 spread: gun.spread, pierce: gun.pierce + model.hero.extraPierce, range: gun.range,
                 burns: gun.burns || model.hero.burnsOnHit, bulletSize: gun.bulletSize)
        }
        flash(at: muzzle)
        let restY: CGFloat = 28
        gunSprite.run(.sequence([.moveTo(y: restY - 3, duration: 0.02), .moveTo(y: restY, duration: 0.05)]),
                      withKey: "recoil")
        playerCooldown = model.gunInterval

        let left = (ammo[gun] ?? model.magazineSize) - 1
        ammo[gun] = left
        if left <= 0 {
            reloadLeft = model.reloadTime
            gunSprite.run(.sequence([.rotate(toAngle: -0.6, duration: 0.1),
                                     .wait(forDuration: max(0, model.reloadTime - 0.2)),
                                     .rotate(toAngle: 0, duration: 0.1)]), withKey: "reload")
        }
        updateAmmoLabel()
    }

    private func updateAmmoLabel() {
        guard let model = model else { return }
        ammoLabel.removeAction(forKey: "blink")
        ammoLabel.alpha = 1
        if reloadLeft > 0 {
            ammoLabel.text = "RELOADING"
            ammoLabel.fontColor = Palette.bloodRed
            ammoLabel.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.2),
                                                    .fadeAlpha(to: 1, duration: 0.2)])), withKey: "blink")
        } else {
            let left = ammo[model.equippedGun] ?? model.magazineSize
            ammoLabel.text = "\(left) / \(model.magazineSize)"
            ammoLabel.fontColor = left * 4 <= model.magazineSize ? Palette.bloodRed : Palette.bone
        }
    }

    // MARK: Shooting

    private func fire(from origin: CGPoint, at target: Zombie, damage: CGFloat, color: UIColor,
                      spread: CGFloat = 0, pierce: Int = 1, range: CGFloat? = nil,
                      burns: Bool = false, bulletSize: CGSize = CGSize(width: 3, height: 9)) {
        // Lead the target slightly so shots land on walking zombies.
        let distance = hypot(target.position.x - origin.x, target.position.y - origin.y)
        let travel = distance / bulletSpeed
        let aim = CGPoint(x: target.position.x,
                          y: target.position.y - target.walkSpeed * CGFloat(travel))
        let dx = aim.x - origin.x, dy = aim.y - origin.y

        let bullet = Bullet(color: perkActive(.poison) ? Perk.poison.color : color, size: bulletSize)
        bullet.burns = burns
        bullet.position = origin
        bullet.zPosition = 25
        let angle = atan2(dy, dx) + (spread > 0 ? CGFloat.random(in: -spread / 2...spread / 2) : 0)
        bullet.zRotation = angle - .pi / 2
        bullet.velocity = CGVector(dx: cos(angle) * bulletSpeed, dy: sin(angle) * bulletSpeed)
        bullet.damage = damage
        bullet.pierce = pierce
        bullet.rangeLeft = range
        addChild(bullet)
        bullets.append(bullet)
    }

    private func moveBullets(_ dt: TimeInterval) {
        var spent: [Bullet] = []
        for bullet in bullets {
            bullet.position.x += bullet.velocity.dx * CGFloat(dt)
            bullet.position.y += bullet.velocity.dy * CGFloat(dt)

            if let range = bullet.rangeLeft {
                let left = range - bulletSpeed * CGFloat(dt)
                bullet.rangeLeft = left
                bullet.alpha = min(1, left / 60)
                if left <= 0 {
                    spent.append(bullet)
                    continue
                }
            }

            if let hit = zombies.first(where: {
                $0.frame.contains(bullet.position) && !bullet.hits.contains(ObjectIdentifier($0))
            }) {
                bullet.hits.insert(ObjectIdentifier(hit))
                applyDamage(bullet.damage, to: hit, burn: bullet.burns)
                bullet.pierce -= 1
                if bullet.pierce <= 0 { spent.append(bullet) }
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

    /// All damage from bullets, rocks and bursts goes through here so perks apply everywhere.
    private func applyDamage(_ amount: CGFloat, to zombie: Zombie, canPoison: Bool = true, burn: Bool = false) {
        guard zombie.parent != nil else { return }
        var damage = amount
        if perkActive(.instaKill) {
            // Insta-kill doesn't apply to bosses: they take 30% more damage instead.
            damage = zombie.kind == .boss ? amount * 1.3 : zombie.hp + 1
        }
        if canPoison && perkActive(.poison) {
            zombie.poison(dps: amount * 0.5, duration: 3)
        } else if burn {
            zombie.poison(dps: amount * 0.6, duration: 2)
        }
        if zombie.takeHit(damage) {
            kill(zombie)
        }
    }

    private func kill(_ zombie: Zombie) {
        guard zombie.parent != nil else { return } // already dead
        remove(zombie)
        let reward = zombie.kind.reward * (perkActive(.doubleMoney) ? 2 : 1)
        model?.zombieKilled(reward: reward)
        splat(at: zombie.position, size: zombie.size.width)
        bloodDecal(at: CGPoint(x: zombie.position.x, y: zombie.position.y - zombie.size.height * 0.3),
                   size: zombie.size.width)
        popLabel("+\(reward)", at: zombie.position)
        if zombie.kind == .bloater {
            burst(from: zombie)
        }
        maybeDropPerk(from: zombie)
    }

    // MARK: Perks

    /// How long a dropped perk waits to be tapped before it vanishes (blinks for the last 2.5s).
    private let perkTokenLifetime: TimeInterval = 7

    /// After wave 5, zombies have a small chance to drop a perk (bosses always do).
    /// The perk stays where the zombie died until you tap it, or it fades away.
    private func maybeDropPerk(from zombie: Zombie) {
        guard wave > GameModel.perksAfterWave else { return }
        guard zombie.kind == .boss || CGFloat.random(in: 0...1) < GameModel.perkDropChance else { return }
        guard let perk = Perk.allCases.randomElement() else { return }

        let token = PerkToken()
        token.path = CGPath(ellipseIn: CGRect(x: -16, y: -16, width: 32, height: 32), transform: nil)
        token.perk = perk
        token.fillColor = perk.color.withAlphaComponent(0.35)
        token.strokeColor = perk.color
        token.lineWidth = 3
        // Keep it clear of the defense line so it doesn't cover the slots.
        token.position = CGPoint(x: min(max(zombie.position.x, 24), size.width - 24),
                                 y: max(zombie.position.y, barricadeY + 48))
        token.zPosition = 45
        token.name = "fx"
        let icon = SKLabelNode(text: perk.emoji)
        icon.fontSize = 18
        icon.verticalAlignmentMode = .center
        token.addChild(icon)
        addChild(token)

        // Pop out and bob in place; blink near the end, then disappear if not collected.
        token.setScale(0.3)
        token.run(.sequence([.scale(to: 1.3, duration: 0.15), .scale(to: 1, duration: 0.1)]))
        let bob = SKAction.sequence([.moveBy(x: 0, y: 5, duration: 0.4), .moveBy(x: 0, y: -5, duration: 0.4)])
        token.run(.repeatForever(bob), withKey: "bob")
        let blink = SKAction.repeat(.sequence([.fadeAlpha(to: 0.25, duration: 0.125),
                                               .fadeAlpha(to: 1, duration: 0.125)]), count: 10)
        token.run(.sequence([
            .wait(forDuration: perkTokenLifetime - 2.5), blink,
            .fadeOut(withDuration: 0.2), .removeFromParent(),
        ]), withKey: "life")
    }

    /// Collect a tapped perk: it flies up to the HUD and switches on.
    private func collect(_ token: PerkToken) {
        guard !token.collected else { return }
        token.collected = true
        token.removeAllActions()
        token.alpha = 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let fly = SKAction.move(to: CGPoint(x: size.width / 2, y: size.height - 24), duration: 0.35)
        fly.timingMode = .easeIn
        let perk = token.perk
        token.run(.sequence([
            .group([fly, .scale(to: 0.6, duration: 0.35)]),
            .run { [weak self] in self?.activate(perk) },
            .removeFromParent(),
        ]))
    }

    private func activate(_ perk: Perk) {
        guard isRunning else { return }
        perkTime[perk] = perk.duration
        announce(perk.title + "!")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        publishPerks()
    }

    private func tickPerks(_ dt: TimeInterval) {
        guard !perkTime.isEmpty else { return }
        for (perk, left) in perkTime {
            perkTime[perk] = left - dt > 0 ? left - dt : nil
        }
        publishPerks()
    }

    /// Tell the HUD only when a whole second changes, to keep SwiftUI updates light.
    private func publishPerks() {
        let rounded = perkTime.mapValues { Int($0.rounded(.up)) }
        if rounded != publishedPerks {
            publishedPerks = rounded
            model?.perksChanged(rounded)
        }
    }

    // MARK: Catapult

    /// Lob a rock in an arc to where the target will be, then splash everything nearby.
    private func launchRock(from origin: CGPoint, at target: Zombie, damage: CGFloat, radius: CGFloat) {
        let flight: TimeInterval = 0.7
        let landing = CGPoint(x: target.position.x,
                              y: max(barricadeY + 20, target.position.y - target.walkSpeed * CGFloat(flight)))
        let rock = SKSpriteNode(color: UIColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1),
                                size: CGSize(width: 9, height: 9))
        rock.position = origin
        rock.zPosition = 35
        rock.name = "fx"
        addChild(rock)

        let move = SKAction.move(to: landing, duration: flight)
        move.timingMode = .easeInEaseOut
        // Grow then shrink to fake the height of the arc.
        let arc = SKAction.sequence([.scale(to: 2.2, duration: flight / 2), .scale(to: 1, duration: flight / 2)])
        rock.run(.sequence([
            .group([move, arc, .rotate(byAngle: .pi * 3, duration: flight)]),
            .run { [weak self] in self?.rockLanded(at: landing, damage: damage, radius: radius) },
            .removeFromParent(),
        ]))
    }

    private func rockLanded(at point: CGPoint, damage: CGFloat, radius: CGFloat) {
        guard isRunning else { return }
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = point
        ring.strokeColor = UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 0.9)
        ring.fillColor = UIColor(red: 0.6, green: 0.5, blue: 0.35, alpha: 0.3)
        ring.zPosition = 30
        ring.setScale(0.3)
        addChild(ring)
        ring.run(.sequence([.group([.scale(to: 1, duration: 0.15), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        splat(at: point, size: 20)

        let caught = zombies.filter { hypot($0.position.x - point.x, $0.position.y - point.y) < radius }
        for victim in caught {
            applyDamage(damage, to: victim, canPoison: false)
        }
    }

    // MARK: Touch: tap a slot to unlock or build on it

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isRunning, let point = touches.first?.location(in: self) else { return }

        // Perks first: tap one to collect it (generous hit area for thumbs).
        let tokens = children.compactMap { $0 as? PerkToken }.filter { !$0.collected }
        if let token = tokens.min(by: { hypot($0.position.x - point.x, $0.position.y - point.y)
                                        < hypot($1.position.x - point.x, $1.position.y - point.y) }),
           hypot(token.position.x - point.x, token.position.y - point.y) < 34 {
            collect(token)
            return
        }

        // Tap the hero (between waves) to swap heroes.
        if survivor.frame.insetBy(dx: -12, dy: -8).contains(point) {
            model?.heroTapped()
            return
        }

        for (index, node) in slotNodes.enumerated() {
            let center = CGPoint(x: node.position.x, y: node.position.y + 18)
            if abs(point.x - center.x) < 26 && abs(point.y - center.y) < 26 {
                model?.slotTapped(index)
                return
            }
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
        for victim in caught {
            applyDamage(damage, to: victim, canPoison: false)
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
        label.fontName = "Futura-CondensedExtraBold"
        label.fontSize = 16
        label.fontColor = Palette.bone
        label.position = point
        label.zPosition = 40
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 36, duration: 0.6), .fadeOut(withDuration: 0.6)]),
            .removeFromParent(),
        ]))
    }

    private func showBanner(_ text: String, size fontSize: CGFloat, hold: TimeInterval, y: CGFloat = 0.6) {
        let label = SKLabelNode(text: text)
        label.fontName = "Futura-CondensedExtraBold"
        label.fontSize = fontSize
        label.fontColor = Palette.bone
        label.position = CGPoint(x: size.width / 2, y: size.height * y)
        label.zPosition = 70
        label.alpha = 0
        addChild(label)
        label.run(.sequence([
            .fadeIn(withDuration: 0.2), .wait(forDuration: hold),
            .fadeOut(withDuration: 0.4), .removeFromParent(),
        ]))
    }
}
