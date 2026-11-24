import UIKit

/// Central place for the game's colors. Gritty, desaturated survival-horror look.
enum Palette {
    static let sky = UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
    static let daySky = UIColor(red: 0.24, green: 0.25, blue: 0.23, alpha: 1)    // overcast, ashen
    static let nightSky = UIColor(red: 0.06, green: 0.02, blue: 0.03, alpha: 1)  // near-black, red cast
    static let dirt = UIColor(red: 0.14, green: 0.12, blue: 0.10, alpha: 1)
    static let dirtSpeck = UIColor(red: 0.20, green: 0.17, blue: 0.13, alpha: 1)
    static let ground = UIColor(red: 0.18, green: 0.20, blue: 0.14, alpha: 1)
    static let plank = UIColor(red: 0.40, green: 0.28, blue: 0.17, alpha: 1)
    static let plankDark = UIColor(red: 0.26, green: 0.17, blue: 0.10, alpha: 1)
    static let bullet = UIColor(red: 1.00, green: 0.82, blue: 0.40, alpha: 1)
    static let turretBullet = UIColor(red: 1.00, green: 0.55, blue: 0.25, alpha: 1)
    static let blood = UIColor(red: 0.55, green: 0.04, blue: 0.04, alpha: 1)
    static let bloodDark = UIColor(red: 0.30, green: 0.02, blue: 0.02, alpha: 1)
    static let bloodRed = UIColor(red: 0.80, green: 0.08, blue: 0.06, alpha: 1)
    static let bone = UIColor(red: 0.88, green: 0.85, blue: 0.78, alpha: 1)
    static let fogDay = UIColor(red: 0.70, green: 0.70, blue: 0.66, alpha: 1)
    static let fogNight = UIColor(red: 0.45, green: 0.10, blue: 0.10, alpha: 1)
}
