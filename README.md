# Halp!

An endless zombie wave defense game for iPhone, built with SwiftUI and SpriteKit.

A tiny pixel survivor stands behind a barricade at the bottom of the screen. Zombies pour down from the top. The survivor shoots automatically; you spend **kills** on upgrades to keep up.

## How it plays

- **Top bar:** current wave, barricade health, kill count (your currency), and a **2x** speed toggle.
- **Battlefield:** zombies walk toward the barricade. Every one that reaches it damages the barricade. At 0 HP you're overrun.
- **Upgrade panel (bottom):**

| Upgrade | Effect |
| --- | --- |
| Damage | Survivor's bullets hit harder (×1.3 per level) |
| Fire Rate | Survivor shoots faster (max level 15) |
| Multi-Shot | Fire at 2, then 3 zombies at once |
| Turret | Builds a turret on the next empty spot (4 spots) |
| Turret Pwr | All turrets hit harder and fire faster |
| Repair | Restores 5 barricade HP |

- **Zombies:** walkers; fast, fragile runners from wave 3; tanky brutes from wave 5; and a boss every 5th wave.

## Running it on a Mac

1. **Update macOS and Xcode.** Open the App Store, install any macOS updates, then install or update **Xcode** (free, large download). The project needs Xcode 15 or newer.
2. Open Xcode once and let it install its extra components.
3. **Get the code.** Either:
   - In Xcode: *Clone Git Repository…* and paste this repo's URL, then check out the branch, or
   - In Terminal: `git clone <repo url>` then `cd Halp`.
4. Double-click **`Halp.xcodeproj`**.
5. At the top of the window, pick a simulator (for example *iPhone 15*) and press **▶ Run** (⌘R).

### On your own iPhone

1. Plug in the iPhone and pick it as the run destination.
2. Click the **Halp** project in the left sidebar → **Signing & Capabilities** → set **Team** to your Apple ID (*Add an Account…* if needed). A free Apple ID works for personal testing.
3. If the bundle ID is taken, change `com.example.halp` to something unique, like `com.yourname.halp`.
4. Press Run. The first time, on the iPhone go to *Settings → General → VPN & Device Management* and trust your developer profile, and turn on *Developer Mode* if asked.

## Code layout

| File | What's in it |
| --- | --- |
| `Halp/HalpApp.swift` | App entry point |
| `Halp/ContentView.swift` | SwiftUI: top bar, 2x button, upgrade panel, menus |
| `Halp/GameModel.swift` | Waves, kills, health, upgrade costs and stats |
| `Halp/GameScene.swift` | SpriteKit battlefield: zombies, shooting, turrets, effects |
| `Halp/PixelArt.swift` | Pixel sprites drawn from text grids (no image files needed) |
| `Halp/Palette.swift` | Colors |

**Tuning:** upgrade costs and stats are in `GameModel.swift`. Zombie health, speed and rewards are in the `Zombie.Kind` enum in `GameScene.swift`. Wave size and spawn rate are in `startNextWave()`.

**Redrawing sprites:** edit the character grids in `PixelArt.swift`. Each character is one pixel, `.` is transparent.
