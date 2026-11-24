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

    static let survivorRows = [
        "........GG",
        "...HHH..GG",
        "..HHHHH.G.",
        "..SSSSS.G.",
        "..SESES.G.",
        "..SSSSS.G.",
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
