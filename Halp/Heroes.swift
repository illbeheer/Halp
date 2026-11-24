import SpriteKit
import UIKit

// MARK: - Heroes

/// Playable heroes. You start with Rook and rescue the rest by clearing campaign regions.
/// One hero fights at a time; each has a weapon set, an always-on passive and a tap ability.
enum Hero: String, CaseIterable, Identifiable {
    case rook, mags, doc, vix, torch, sarge

    var id: Self { self }

    var name: String {
        switch self {
        case .rook: return "Rook"
        case .mags: return "Mags"
        case .doc: return "Doc"
        case .vix: return "Vix"
        case .torch: return "Torch"
        case .sarge: return "Sarge"
        }
    }

    var role: String {
        switch self {
        case .rook: return "Survivor"
        case .mags: return "Mechanic"
        case .doc: return "Medic"
        case .vix: return "Hunter"
        case .torch: return "Pyro"
        case .sarge: return "Soldier"
        }
    }

    /// The hero's weapon set. The first one is free and equipped at the start.
    var guns: [Gun] {
        switch self {
        case .rook: return [.pistol, .smg, .rifle]
        case .mags: return [.shotgun, .smg, .lmg]
        case .doc: return [.pistol, .crossbow, .marksman]
        case .vix: return [.crossbow, .revolver, .marksman]
        case .torch: return [.flamethrower, .shotgun, .revolver]
        case .sarge: return [.rifle, .shotgun, .lmg]
        }
    }

    var startingGun: Gun { guns[0] }

    // MARK: Passive

    var passiveName: String {
        switch self {
        case .rook: return "Steady Hands"
        case .mags: return "Tinkerer"
        case .doc: return "Field Repairs"
        case .vix: return "Ricochet"
        case .torch: return "Kindling"
        case .sarge: return "Drilled"
        }
    }

    var passiveText: String {
        switch self {
        case .rook: return "Fires 15% faster."
        case .mags: return "Turrets and catapults deal 25% more damage."
        case .doc: return "Barricade regains 1 HP every 10s during waves."
        case .vix: return "Every bullet passes through one extra zombie."
        case .torch: return "Every bullet sets zombies on fire."
        case .sarge: return "30% bigger magazines, 25% faster reloads."
        }
    }

    // MARK: Tap ability

    var abilityName: String {
        switch self {
        case .rook: return "Frag Grenade"
        case .mags: return "Overclock"
        case .doc: return "Patch Up"
        case .vix: return "Deadeye"
        case .torch: return "Firewall"
        case .sarge: return "Airstrike"
        }
    }

    var abilityText: String {
        switch self {
        case .rook: return "Lob a grenade into the nearest pack."
        case .mags: return "All turrets and catapults fire 2.5x faster for 6s."
        case .doc: return "Instantly repair 6 barricade HP."
        case .vix: return "Your shots deal 2.5x damage for 6s."
        case .torch: return "A wall of fire burns everything crossing it for 5s."
        case .sarge: return "Call in a strike that carpets the field."
        }
    }

    var abilityIcon: String {
        switch self {
        case .rook: return "circle.circle.fill"
        case .mags: return "gearshape.2.fill"
        case .doc: return "cross.case.fill"
        case .vix: return "scope"
        case .torch: return "flame.fill"
        case .sarge: return "airplane"
        }
    }

    /// Seconds of wave time between uses.
    var abilityCooldown: TimeInterval {
        switch self {
        case .rook: return 20
        case .mags: return 25
        case .doc: return 30
        case .vix: return 22
        case .torch: return 25
        case .sarge: return 30
        }
    }

    /// Which region you rescue this hero in (Rook is with you from the start).
    var rescuedIn: Region? {
        Region.allCases.first { $0.rescue == self }
    }

    // MARK: Passive numbers (read by the model and scene)

    var fireIntervalMultiplier: Double { self == .rook ? 0.87 : 1 }
    var defenseDamageMultiplier: CGFloat { self == .mags ? 1.25 : 1 }
    var extraPierce: Int { self == .vix ? 1 : 0 }
    var burnsOnHit: Bool { self == .torch }
    var magazineMultiplier: Double { self == .sarge ? 1.3 : 1 }
    var reloadMultiplier: Double { self == .sarge ? 0.75 : 1 }
    var regenerates: Bool { self == .doc }

    // MARK: Look (palette swap of the survivor sprite)

    private var palette: [Character: UIColor] {
        func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
        var colors: [Character: UIColor] = ["E": .black, "K": c(0.12, 0.10, 0.08)]
        switch self {
        case .rook:
            colors["H"] = c(0.45, 0.27, 0.13); colors["S"] = c(0.96, 0.76, 0.58)
            colors["B"] = c(0.25, 0.40, 0.70); colors["P"] = c(0.20, 0.22, 0.30)
        case .mags:
            colors["H"] = c(0.10, 0.08, 0.08); colors["S"] = c(0.85, 0.62, 0.45)
            colors["B"] = c(0.85, 0.45, 0.15); colors["P"] = c(0.20, 0.30, 0.50)
        case .doc:
            colors["H"] = c(0.70, 0.70, 0.72); colors["S"] = c(0.95, 0.80, 0.68)
            colors["B"] = c(0.86, 0.88, 0.88); colors["P"] = c(0.20, 0.50, 0.50)
        case .vix:
            colors["H"] = c(0.78, 0.25, 0.10); colors["S"] = c(0.98, 0.84, 0.72)
            colors["B"] = c(0.20, 0.38, 0.22); colors["P"] = c(0.35, 0.25, 0.15)
        case .torch:
            colors["H"] = c(0.90, 0.75, 0.30); colors["S"] = c(0.55, 0.38, 0.26)
            colors["B"] = c(0.25, 0.25, 0.27); colors["P"] = c(0.15, 0.15, 0.17)
        case .sarge:
            colors["H"] = c(0.20, 0.18, 0.15); colors["S"] = c(0.40, 0.27, 0.18)
            colors["B"] = c(0.35, 0.40, 0.22); colors["P"] = c(0.25, 0.28, 0.16)
        }
        return colors
    }

    private static var textureCache: [Hero: SKTexture] = [:]

    var texture: SKTexture {
        if let cached = Hero.textureCache[self] { return cached }
        let made = PixelArt.texture(Sprites.survivorRows, palette: palette)
        Hero.textureCache[self] = made
        return made
    }

    /// Shirt color, used to tint hero cards in the UI.
    var accent: UIColor { palette["B"] ?? .gray }
}

// MARK: - Campaign regions

struct RegionTheme {
    let daySky: UIColor
    let duskSky: UIColor
    let nightSky: UIColor
    let dirt: UIColor
    let dirtSpeck: UIColor
    let grass: UIColor
    let fogDay: UIColor
    let fogNight: UIColor

    /// The look used in Endless mode.
    static let endless = RegionTheme(
        daySky: Palette.daySky, duskSky: UIColor(red: 0.30, green: 0.11, blue: 0.07, alpha: 1),
        nightSky: Palette.nightSky, dirt: Palette.dirt, dirtSpeck: Palette.dirtSpeck,
        grass: Palette.ground, fogDay: Palette.fogDay, fogNight: Palette.fogNight)
}

/// Campaign regions, traveled in order. Each is a fresh run of `waves` day waves
/// (plus nights), ending with a boss. Every region is far harder than the last.
enum Region: Int, CaseIterable, Identifiable {
    case farmlands, highway, suburbs, hospital, militaryBase, lab

    var id: Self { self }

    var name: String {
        switch self {
        case .farmlands: return "Farmlands"
        case .highway: return "Highway"
        case .suburbs: return "Suburbs"
        case .hospital: return "Hospital"
        case .militaryBase: return "Military Base"
        case .lab: return "The Lab"
        }
    }

    var blurb: String {
        switch self {
        case .farmlands: return "Where it started. Barns, mud and the first of them."
        case .highway: return "Wrecked cars for miles. They come out of the fog."
        case .suburbs: return "Picket fences, empty houses, full streets."
        case .hospital: return "Patient zero was here. So are the bloated ones."
        case .militaryBase: return "They had guns. It didn't help."
        case .lab: return "The source. End it."
        }
    }

    /// Day waves to clear (nights come after every 3rd, as usual).
    var waves: Int { 8 }

    /// Exponential difficulty: zombie health multiplier for the whole region.
    var healthMultiplier: CGFloat { pow(1.9, CGFloat(rawValue)) }
    var speedMultiplier: CGFloat { 1 + CGFloat(rawValue) * 0.06 }
    var extraZombies: Int { rawValue * 2 }
    /// Gold per kill grows as the story goes on (a bit slower than zombie health).
    var goldMultiplier: Double { pow(1.7, Double(rawValue)) }
    /// Tougher zombie types show up this many waves earlier.
    var typeHeadStart: Int { rawValue * 2 }

    /// The hero rescued by clearing this region.
    var rescue: Hero? {
        switch self {
        case .farmlands: return .mags
        case .highway: return .doc
        case .suburbs: return .vix
        case .hospital: return .torch
        case .militaryBase: return .sarge
        case .lab: return nil
        }
    }

    var theme: RegionTheme {
        func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
        switch self {
        case .farmlands:
            return RegionTheme(daySky: c(0.33, 0.31, 0.24), duskSky: c(0.36, 0.16, 0.07), nightSky: c(0.06, 0.03, 0.02),
                               dirt: c(0.22, 0.16, 0.10), dirtSpeck: c(0.30, 0.22, 0.13), grass: c(0.30, 0.30, 0.12),
                               fogDay: c(0.75, 0.72, 0.60), fogNight: c(0.45, 0.15, 0.08))
        case .highway:
            return RegionTheme(daySky: c(0.27, 0.28, 0.30), duskSky: c(0.28, 0.13, 0.10), nightSky: c(0.04, 0.04, 0.06),
                               dirt: c(0.16, 0.16, 0.17), dirtSpeck: c(0.24, 0.24, 0.22), grass: c(0.55, 0.50, 0.20),
                               fogDay: c(0.70, 0.72, 0.75), fogNight: c(0.35, 0.12, 0.12))
        case .suburbs:
            return RegionTheme(daySky: c(0.26, 0.29, 0.26), duskSky: c(0.33, 0.12, 0.12), nightSky: c(0.05, 0.03, 0.05),
                               dirt: c(0.13, 0.16, 0.10), dirtSpeck: c(0.18, 0.22, 0.13), grass: c(0.20, 0.30, 0.14),
                               fogDay: c(0.68, 0.72, 0.66), fogNight: c(0.40, 0.10, 0.14))
        case .hospital:
            return RegionTheme(daySky: c(0.25, 0.30, 0.30), duskSky: c(0.20, 0.18, 0.14), nightSky: c(0.02, 0.05, 0.05),
                               dirt: c(0.20, 0.22, 0.22), dirtSpeck: c(0.28, 0.30, 0.30), grass: c(0.35, 0.40, 0.38),
                               fogDay: c(0.65, 0.78, 0.72), fogNight: c(0.20, 0.40, 0.25))
        case .militaryBase:
            return RegionTheme(daySky: c(0.30, 0.29, 0.22), duskSky: c(0.35, 0.18, 0.06), nightSky: c(0.05, 0.04, 0.02),
                               dirt: c(0.24, 0.21, 0.14), dirtSpeck: c(0.32, 0.28, 0.18), grass: c(0.30, 0.32, 0.18),
                               fogDay: c(0.72, 0.68, 0.55), fogNight: c(0.45, 0.20, 0.05))
        case .lab:
            return RegionTheme(daySky: c(0.20, 0.22, 0.26), duskSky: c(0.22, 0.08, 0.20), nightSky: c(0.04, 0.01, 0.05),
                               dirt: c(0.12, 0.12, 0.15), dirtSpeck: c(0.20, 0.20, 0.26), grass: c(0.25, 0.55, 0.30),
                               fogDay: c(0.55, 0.75, 0.60), fogNight: c(0.35, 0.10, 0.40))
        }
    }
}

// MARK: - Saved progress

enum SavedProgress {
    private static let rescuedKey = "halp.rescuedHeroes"
    private static let clearedKey = "halp.regionsCleared"
    private static let heroKey = "halp.selectedHero"

    static var rescued: Set<Hero> {
        get {
            let raw = UserDefaults.standard.stringArray(forKey: rescuedKey) ?? []
            return Set(raw.compactMap(Hero.init(rawValue:))).union([.rook])
        }
        set { UserDefaults.standard.set(newValue.map(\.rawValue), forKey: rescuedKey) }
    }

    /// How many regions are cleared (0 = only Farmlands open).
    static var regionsCleared: Int {
        get { UserDefaults.standard.integer(forKey: clearedKey) }
        set { UserDefaults.standard.set(newValue, forKey: clearedKey) }
    }

    private static let goldKey = "halp.campaignGold"

    /// Campaign gold, carried from region to region and run to run.
    static var campaignGold: Int {
        get { UserDefaults.standard.integer(forKey: goldKey) }
        set { UserDefaults.standard.set(newValue, forKey: goldKey) }
    }

    static var selectedHero: Hero {
        get { Hero(rawValue: UserDefaults.standard.string(forKey: heroKey) ?? "") ?? .rook }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: heroKey) }
    }
}
