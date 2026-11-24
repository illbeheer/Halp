# Halp!

An endless zombie wave defense game for iPhone, built with SwiftUI and SpriteKit, with a gritty survival-horror mood: ashen daylight, blood-moon nights, drifting fog, film grain, and a flickering blood-red wave counter.

A tiny pixel survivor stands behind a barricade at the bottom of the screen. Zombies pour down from the top. The survivor shoots automatically; you spend **kills** on upgrades to keep up.

## How it plays

- **Top bar:** wave, barricade health and kills (your currency) on the left. A **sun/moon** in the top middle shows whether it's day or night. **Play** and **Pause** are top right: Play sends the next wave (or resumes), Pause freezes the current one.
- **Battlefield:** zombies walk down toward the barricade. Every one that reaches it damages the barricade. At 0 HP you're overrun.
- **>> button:** just above the barricade on the right, toggles 2x speed.
- **Defense line:** the survivor stands in the middle with **8 slots** in two rows of four, two on each side.
  - 2 slots are free from the start. The other 6 are locked and unlock **in order**: one free every 4 waves, or buy the next one early with kills.
  - Tap an unlocked slot to build a **Turret** (fast, one target) or a **Catapult** (slow, lobs rocks that splash a group). Each extra one costs more.
- **Perks:** after wave 5, killed zombies have a small chance (4%, bosses always) to drop a perk. Tap it to collect it before it blinks out (about 7 seconds); it then flies to the top and activates. Timers show at the top of the battlefield and only run down during waves.

| Perk | Lasts | Effect |
| --- | --- | --- |
| 💰 Double Money | 20s | Kills pay double |
| 💀 Insta-Kill | 8s | Every hit kills a normal zombie; bosses take +30% damage instead |
| 🧪 Poison Bullets | 15s | Bullets also poison: extra damage over 3s |

- **Day and night:** nights are half-waves that come after every 3rd day wave: 1, 2, 3, **3.5**, 4, 5, 6, **6.5**, 7… Nights are much shorter (half the zombies, spawning faster), but zombies get +60% health and +10% speed, on top of health that rises every wave. Boss waves and free slot unlocks only happen on day waves.
- **Zombie types:**

| Zombie | From wave | Notes |
| --- | --- | --- |
| Walker | 1 | The regular shambler |
| Runner | 2 | Speed zombie: fast, fragile (more common at night) |
| Crawler | 3 | Small and quick, comes in packs of 3 |
| Tank | 4 | Armored and slow, soaks damage, hits the barricade for 4 |
| Bloater | 6 | Bursts when killed, damaging zombies around it; hits the barricade for 5 |
| Boss | every 5th | Huge health, hits the barricade for 10 |

- **Upgrade panel (bottom):**

| Upgrade | Effect |
| --- | --- |
| Damage | Survivor's bullets hit harder (×1.3 per level) |
| Fire Rate | Survivor shoots faster (max level 15) |
| Multi-Shot | Fire at 2, then 3 zombies at once |
| Turret Pwr | All turrets hit harder and fire faster |
| Catapult Pwr | All catapults hit harder, fire faster, splash wider |
| Repair | Restores 5 barricade HP |

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

**Tuning:** upgrade, slot and build costs, perk drop chance and durations, the free-unlock interval and the day/night rule (`isNight(wave:)`) are in `GameModel.swift`. Zombie health, speed and rewards are in the `Zombie.Kind` enum in `GameScene.swift`; the night boost is `nightHPMultiplier`; which zombies appear when is `randomKind()`; wave size and spawn rate are in `startNextWave()`.

**Getting an IPA:** every push builds an unsigned `Halp.ipa` on GitHub Actions (see the *Build IPA* workflow, *Artifacts* section). Install it with Sideloadly or AltStore, which sign it with your Apple ID.

**Redrawing sprites:** edit the character grids in `PixelArt.swift`. Each character is one pixel, `.` is transparent.
