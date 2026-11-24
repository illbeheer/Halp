import SpriteKit
import UIKit

/// Builds crisp pixel-art textures from little text grids, so the game needs no image files.
/// Each character in a row is one pixel; characters missing from the palette are transparent.
enum PixelArt {
    static func texture(_ rows: [String], palette: [Character: UIColor]) -> SKTexture {
        let width = rows.map(\.count).max() ?? 0
        let height = rows.count
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { ctx in
            for (y, row) in rows.enumerated() {
                for (x, char) in row.enumerated() {
                    guard let color = palette[char] else { continue }
                    color.setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest // keep pixels sharp when scaled up
        return texture
    }

    /// Size in points of a grid drawn at `pixel` points per pixel.
    static func size(_ rows: [String], pixel: CGFloat) -> CGSize {
        CGSize(width: CGFloat(rows.map(\.count).max() ?? 0) * pixel, height: CGFloat(rows.count) * pixel)
    }
}

/// All sprite designs in one place.
enum Sprites {
    // MARK: Survivor (the player)

    /// The survivor without a gun; the equipped gun is drawn on top (see `Sprites.gunRows`).
    static let survivorRows = [
        "..........",
        "...HHH....",
        "..HHHHH...",
        "..SSSSS...",
        "..SESES...",
        "..SSSSS...",
        "...SSS..S.",
        ".BBBBBBBS.",
        "S.BBBBB...",
        "..BBBBB...",
        "..PP.PP...",
        "..PP.PP...",
        ".KKK.KKK..",
    ]

    static let survivorPalette: [Character: UIColor] = [
        "H": UIColor(red: 0.45, green: 0.27, blue: 0.13, alpha: 1),
        "S": UIColor(red: 0.96, green: 0.76, blue: 0.58, alpha: 1),
        "E": .black,
        "B": UIColor(red: 0.25, green: 0.45, blue: 0.85, alpha: 1),
        "P": UIColor(red: 0.20, green: 0.22, blue: 0.30, alpha: 1),
        "K": UIColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 1),
        "G": UIColor(red: 0.55, green: 0.57, blue: 0.62, alpha: 1),
    ]

    static let survivor = PixelArt.texture(survivorRows, palette: survivorPalette)

    // MARK: Guns (held pointing up; the muzzle is the top row)

    static func gunRows(_ gun: Gun) -> [String] {
        switch gun {
        case .pistol:
            return [
                "G.",
                "GG",
                "GG",
                "DG",
            ]
        case .smg:
            return [
                ".G.",
                ".G.",
                "GGG",
                "GGG",
                "DGG",
                "D..",
            ]
        case .shotgun:
            return [
                "GG",
                "GG",
                "GG",
                "GG",
                "WW",
                "WG",
                "GG",
                "WW",
                "WW",
            ]
        case .rifle:
            return [
                ".G.",
                ".G.",
                ".G.",
                "GGG",
                "GGG",
                "DGG",
                "DGG",
                ".WW",
                ".WW",
            ]
        case .marksman:
            return [
                ".G.",
                ".G.",
                ".G.",
                ".G.",
                "SGG",
                "SGG",
                "SGG",
                ".GG",
                ".GG",
                ".WW",
                ".WW",
                ".WW",
            ]
        case .revolver:
            return [
                "G.",
                "G.",
                "GG",
                "DD",
                "GW",
                ".W",
            ]
        case .crossbow:
            return [
                "..G..",
                "W.G.W",
                ".WGW.",
                "..G..",
                "..W..",
                "..W..",
                "..W..",
            ]
        case .flamethrower:
            return [
                ".R.",
                ".G.",
                ".G.",
                "GGG",
                "TGG",
                "TGG",
                "TDG",
                ".WW",
            ]
        case .lmg:
            return [
                ".GG.",
                ".GG.",
                ".GG.",
                "GGGG",
                "GGGG",
                "DGGG",
                "DGGG",
                "DDGG",
                ".GGG",
                ".WWW",
            ]
        }
    }

    static let gunPalette: [Character: UIColor] = [
        "G": UIColor(red: 0.42, green: 0.44, blue: 0.47, alpha: 1),
        "D": UIColor(red: 0.20, green: 0.21, blue: 0.23, alpha: 1),
        "W": UIColor(red: 0.40, green: 0.26, blue: 0.14, alpha: 1),
        "S": UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1),
        "R": UIColor(red: 1.00, green: 0.45, blue: 0.10, alpha: 1),
        "T": UIColor(red: 0.60, green: 0.18, blue: 0.12, alpha: 1),
    ]

    private static var gunTextureCache: [Gun: SKTexture] = [:]

    static func gunTexture(_ gun: Gun) -> SKTexture {
        if let cached = gunTextureCache[gun] { return cached }
        let texture = PixelArt.texture(gunRows(gun), palette: gunPalette)
        gunTextureCache[gun] = texture
        return texture
    }

    // MARK: Zombies (two walk frames, palette-swapped per type)

    static let zombieFrameA = [
        "..ZZZZZ..",
        ".ZZZZZZZ.",
        ".ZRZZZRZ.",
        ".ZZZZZZZ.",
        ".ZZDDDZZ.",
        "..ZZZZZ..",
        "TTTTTTTTT",
        "Z.TTTTT.Z",
        "Z.TTTTT.Z",
        "..NNNNN..",
        "..NN.NN..",
        "..ZZ.ZZ..",
    ]

    static let zombieFrameB = Array(zombieFrameA.dropLast(2)) + [
        ".NN...NN.",
        ".ZZ...ZZ.",
    ]

    /// Tank: broad, armor-plated (A), slow.
    static let tankFrameA = [
        "...ZZZZZ...",
        "..ZZZZZZZ..",
        "..ZRZZZRZ..",
        "..ZZDDDZZ..",
        "AAAAAAAAAAA",
        "AZAAAAAAAZA",
        "ZZAATAATAZZ",
        "ZZAAAAAAAZZ",
        "ZZAATAATAZZ",
        "..NNNNNNN..",
        "..NNN.NNN..",
        "..NNN.NNN..",
        ".ZZZZ.ZZZZ.",
    ]

    static let tankFrameB = Array(tankFrameA.dropLast(3)) + [
        ".NNN...NNN.",
        ".NNN...NNN.",
        "ZZZZ...ZZZZ",
    ]

    /// Crawler: small, low to the ground, comes in packs.
    static let crawlerFrameA = [
        "..ZZZZZ..",
        ".ZRZZZRZ.",
        ".ZZDDDZZ.",
        "Z.TTTTT.Z",
        ".ZTTTTTZ.",
        "Z.NNNNN.Z",
    ]

    static let crawlerFrameB = [
        "..ZZZZZ..",
        ".ZRZZZRZ.",
        ".ZZDDDZZ.",
        ".ZTTTTTZ.",
        "Z.TTTTT.Z",
        ".ZNNNNNZ.",
    ]

    /// Bloater: swollen body (T) with pustules (P). Bursts when killed.
    static let bloaterFrameA = [
        "...ZZZZZ...",
        "..ZRZZZRZ..",
        "..ZZDDDZZ..",
        ".TTTTTTTTT.",
        "TTTTPTTTTTT",
        "TTTTTTTPTTT",
        "TTPTTTTTTTT",
        "TTTTTTTTTTT",
        ".TTTTTPTTT.",
        "..NN...NN..",
        "..ZZ...ZZ..",
    ]

    static let bloaterFrameB = Array(bloaterFrameA.dropLast(2)) + [
        "...NN.NN...",
        "...ZZ.ZZ...",
    ]

    static func zombiePalette(skin: UIColor, shirt: UIColor) -> [Character: UIColor] {
        [
            "Z": skin,
            "R": UIColor(red: 1, green: 0.15, blue: 0.1, alpha: 1),
            "D": UIColor(red: 0.15, green: 0.05, blue: 0.05, alpha: 1),
            "T": shirt,
            "N": UIColor(red: 0.22, green: 0.20, blue: 0.28, alpha: 1),
            "A": UIColor(red: 0.45, green: 0.47, blue: 0.52, alpha: 1),
            "P": UIColor(red: 0.85, green: 0.55, blue: 0.20, alpha: 1),
        ]
    }

    // MARK: Turret

    static let turretRows = [
        "....G....",
        "....G....",
        "...GGG...",
        "..MMMMM..",
        ".MMGGGMM.",
        ".MMGLGMM.",
        "..MMMMM..",
        ".DDDDDDD.",
        "DDDDDDDDD",
    ]

    static let turret = PixelArt.texture(turretRows, palette: [
        "G": UIColor(red: 0.60, green: 0.62, blue: 0.66, alpha: 1),
        "M": UIColor(red: 0.30, green: 0.42, blue: 0.30, alpha: 1),
        "L": UIColor(red: 0.45, green: 0.85, blue: 1.00, alpha: 1),
        "D": UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1),
    ])

    // MARK: Catapult

    static let catapultRows = [
        "........RR.",
        ".......RRRR",
        "......WWRR.",
        ".....WW....",
        "....WW.....",
        "...WW......",
        ".FFFFFFFFF.",
        ".F.......F.",
        "OO.......OO",
        "OO.......OO",
    ]

    static let catapult = PixelArt.texture(catapultRows, palette: [
        "R": UIColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1),
        "W": UIColor(red: 0.62, green: 0.43, blue: 0.24, alpha: 1),
        "F": UIColor(red: 0.42, green: 0.28, blue: 0.15, alpha: 1),
        "O": UIColor(red: 0.20, green: 0.18, blue: 0.16, alpha: 1),
    ])

    // MARK: Locked slot

    static let lockRows = [
        "...LLL...",
        "..L...L..",
        "..L...L..",
        ".BBBBBBB.",
        ".BBBKBBB.",
        ".BBBKBBB.",
        ".BBBBBBB.",
    ]

    static let lock = PixelArt.texture(lockRows, palette: [
        "L": UIColor(white: 0.75, alpha: 0.8),
        "B": UIColor(red: 0.75, green: 0.60, blue: 0.20, alpha: 0.85),
        "K": UIColor(white: 0.1, alpha: 0.9),
    ])

    // MARK: Empty turret spot

    static let padRows = [
        "W.W.W.W.W",
        ".........",
        "W...P...W",
        "....P....",
        "W.PPPPP.W",
        "....P....",
        "W...P...W",
        ".........",
        "W.W.W.W.W",
    ]

    static let pad = PixelArt.texture(padRows, palette: [
        "W": UIColor(white: 1, alpha: 0.18),
        "P": UIColor(white: 1, alpha: 0.30),
    ])
}

// MARK: - Atmosphere textures (fog, vignette, film grain)

enum EffectTextures {
    /// Soft white blob, tinted and stretched into drifting fog banks.
    static let fog = radial(size: 256,
                            colors: [UIColor(white: 1, alpha: 0.55), UIColor(white: 1, alpha: 0.2), .clear],
                            locations: [0, 0.5, 1])

    /// Clear in the middle, dark at the edges. Stretched over the whole battlefield.
    static let vignette = radial(size: 256,
                                 colors: [.clear, .clear, UIColor(white: 0, alpha: 0.9)],
                                 locations: [0, 0.5, 1])

    /// Same shape in blood red, pulsed when the barricade is about to fall.
    static let dangerVignette = radial(size: 256,
                                       colors: [.clear, .clear, UIColor(red: 0.7, green: 0, blue: 0, alpha: 0.85)],
                                       locations: [0, 0.45, 1])

    /// Random speckle for film grain.
    static let grain: SKTexture = {
        let side = 96
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            for y in 0..<side {
                for x in 0..<side where Int.random(in: 0..<3) == 0 {
                    UIColor(white: CGFloat.random(in: 0...1), alpha: CGFloat.random(in: 0.2...0.7)).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }()

    private static func radial(size: CGFloat, colors: [UIColor], locations: [CGFloat]) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { ctx in
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors.map(\.cgColor) as CFArray,
                                            locations: locations) else { return }
            let center = CGPoint(x: size / 2, y: size / 2)
            ctx.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                             endCenter: center, endRadius: size / 2,
                                             options: [.drawsAfterEndLocation])
        }
        return SKTexture(image: image)
    }
}
