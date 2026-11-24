# Halp!

An endless zombie wave defense game for iPhone, built with SwiftUI and SpriteKit, with a gritty survival-horror mood: ashen daylight, blood-moon nights, drifting fog, film grain, and a flickering blood-red wave counter.

A tiny pixel survivor stands behind a barricade at the bottom of the screen. Zombies pour down from the top. The survivor shoots automatically; you spend **kills** on upgrades to keep up.

## Modes

- **Campaign:** travel the route through 6 regions: Farmlands → Highway → Suburbs → Hospital → Military Base → The Lab. Each region is a fresh run of 8 waves (plus nights) ending with a boss, with its own colors, and is far harder than the last (zombie health ×1.9 per region, more zombies, tough types earlier). Clearing a region unlocks the next and **rescues a hero**.
- **Endless:** the classic mode. Survive as long as you can with any hero you've rescued.

## Heroes

One hero fights at a time. Swap from the menu, the route, the armory's hero button, or by tapping your hero between waves. Each has a 3-gun set (the first is free), an always-on passive and a tap ability (button at the bottom-left of the battlefield, recharges during waves).

| Hero | Rescued in | Guns | Passive | Ability |
| --- | --- | --- | --- | --- |
| Rook (Survivor) | start | Pistol, SMG, Assault Rifle | Fires 15% faster | Frag Grenade into the nearest pack (20s) |
| Mags (Mechanic) | Farmlands | Shotgun, SMG, LMG | Turrets/catapults +25% damage | Overclock: defenses fire 2.5x faster for 6s (25s) |
| Doc (Medic) | Highway | Pistol, Crossbow, Marksman | Barricade +1 HP every 10s | Patch Up: +6 HP (30s) |
| Vix (Hunter) | Suburbs | Crossbow, Revolver, Marksman | Bullets pierce one extra zombie | Deadeye: 2.5x damage for 6s (22s) |
| Torch (Pyro) | Hospital | Flamethrower, Shotgun, Revolver | Bullets set zombies on fire | Firewall across the field for 5s (25s) |
| Sarge (Soldier) | Military Base | Assault Rifle, Shotgun, LMG | +30% magazine, 25% faster reload | Airstrike: 6 blasts down the field (30s) |

Progress (cleared regions, rescued heroes, chosen hero, best endless wave) is saved on the device.

## How it plays

- **Top bar:** wave, barricade health and kills (your currency) on the left. A **sun/moon** in the top middle shows whether it's day or night. **Play** and **Pause** are top right: Play sends the next wave (or resumes), Pause freezes the current one.
- **Battlefield:** zombies walk down toward the barricade. Every one that reaches it damages the barricade. At 0 HP you're overrun.
- **>> button:** just above the barricade on the right, toggles 2x speed.
- **Defense line:** the survivor stands in the middle with **8 slots** in two rows of four, two on each side.
  - Only 2 slots are free. The other 6 are locked and must be **bought, in order**.
  - Tap an unlocked slot to build a **Turret** (fast, one target) or a **Catapult** (slow, lobs rocks that splash a group). Each extra one costs more.
  - Tap a built turret or catapult to **upgrade it** (up to LV 10). Each one levels up separately.
- **Guns:** each hero carries 3 of these (their first one is free). Buy and switch in the armory row at the bottom; each gun has its own magazine, reload and upgrades (Damage, Fire Rate, Magazine). Better guns cost more to upgrade.

| Gun | Price | Plays like |
| --- | --- | --- |
| Pistol | free | Reliable sidearm, 8 rounds |
| SMG | 60 | Very fast, weak hits, 30 rounds |
| Shotgun | 120 | 5 pellets per shot, short range, 6 shells |
| Assault Rifle | 250 | Fast and hard-hitting, 30 rounds |
| Marksman | 400 | Slow, huge damage, each shot pierces up to 4 zombies |
| LMG | 800 | 100-round belt, very fast, long reload |
| Revolver | 120 | Six heavy rounds |
| Crossbow | 150 | Bolts skewer up to 5 zombies |
| Flamethrower | 300 | Short-range stream that sets zombies on fire |

- **Perks:** after wave 5, killed zombies have a small chance (4%, bosses always) to drop a perk. Tap it to collect it before it blinks out (about 7 seconds); it then flies to the top and activates. Timers show at the top of the battlefield and only run down during waves.

| Perk | Lasts | Effect |
| --- | --- | --- |
| 💰 Double Money | 20s | Kills pay double |
| 💀 Insta-Kill | 8s | Every hit kills a normal zombie; bosses take +30% damage instead |
| 🧪 Poison Bullets | 15s | Bullets also poison: extra damage over 3s |

- **Day and night:** nights are half-waves that come after every 3rd day wave: 1, 2, 3, **3.5**, 4, 5, 6, **6.5**, 7… Nights are much shorter (half the zombies, spawning faster), but zombies get +60% health and +10% speed, on top of health that rises every wave. Boss waves only happen on day waves. The light changes gradually: dusk creeps in while you shop before a night, it goes fully dark as the night starts, and dawn breaks after it.
- **Zombie types:**

| Zombie | From wave | Notes |
| --- | --- | --- |
| Walker | 1 | The regular shambler |
| Runner | 2 | Speed zombie: fast, fragile (more common at night) |
| Crawler | 3 | Small and quick, comes in packs of 3 |
| Tank | 4 | Armored and slow, soaks damage, hits the barricade for 4 |
| Bloater | 6 | Bursts when killed, damaging zombies around it; hits the barricade for 5 |
| Boss | every 5th | Huge health, hits the barricade for 10 |

- **Armory (bottom):** the gun row, then upgrades for the equipped gun:

| Upgrade | Effect |
| --- | --- |
| Damage | ×1.3 damage per level |
| Fire Rate | Faster shots (max LV 10) |
| Magazine | +25% rounds and faster reload per level (max LV 8) |
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
| `Halp/Heroes.swift` | Heroes (guns, passives, abilities), campaign regions, saved progress |
| `Halp/MetaViews.swift` | Menu, campaign route, hero roster, region cleared, game over |
| `Halp/PixelArt.swift` | Pixel sprites drawn from text grids (no image files needed) |
| `Halp/Palette.swift` | Colors |

**Tuning:** upgrade, slot and build costs, perk drop chance and durations, the free-unlock interval and the day/night rule (`isNight(wave:)`) are in `GameModel.swift`. Zombie health, speed and rewards are in the `Zombie.Kind` enum in `GameScene.swift`; the night boost is `nightHPMultiplier`; which zombies appear when is `randomKind()`; wave size and spawn rate are in `startNextWave()`.

**Getting an IPA:** every push builds an unsigned `Halp.ipa` on GitHub Actions (see the *Build IPA* workflow, *Artifacts* section). Install it with Sideloadly or AltStore, which sign it with your Apple ID.

**Redrawing sprites:** edit the character grids in `PixelArt.swift`. Each character is one pixel, `.` is transparent.

## Planned

- **Idle mode** (after the core game has been playtested): the defense keeps fighting on its own, and you come back to collect kills earned while away.
- **Sound:** gunshots, zombie groans, the wave-start sting.
- **Economy check:** keep kills as the currency, or switch to points per hit plus a kill bonus.
