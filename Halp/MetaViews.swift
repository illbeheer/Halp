import SwiftUI
import SpriteKit

// Screens around the battle: main menu, campaign map, hero roster,
// region cleared and game over. Styling (blood, bone, gritty) lives in ContentView.swift.

// MARK: - Main menu

struct MenuOverlay: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            FlickeringTitle(text: "HALP!", size: 110)
            Text("THE DEAD DON'T STOP.\nNEITHER DO YOU.")
                .multilineTextAlignment(.center)
                .font(gritty(20))
                .tracking(1.5)
                .foregroundStyle(bone)
            Spacer()

            HeroBadge(hero: model.hero)
                .onTapGesture { model.showRoster = true }

            VStack(spacing: 10) {
                MenuButton(title: "CAMPAIGN",
                           subtitle: model.campaignGold > 0 ? "\(coin) \(model.campaignGold) gold saved"
                                                            : "Travel region to region. Rescue heroes.",
                           primary: true) { model.openMap() }
                MenuButton(title: "ENDLESS",
                           subtitle: model.bestWave > 0 ? "Best: wave \(GameModel.waveLabel(model.bestWave))"
                                                        : "How long can you hold?",
                           primary: false) { model.startEndless() }
                MenuButton(title: "HEROES",
                           subtitle: "\(model.rescuedHeroes.count) of \(Hero.allCases.count) rescued",
                           primary: false) { model.showRoster = true }
            }
            .padding(.horizontal, 32)
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DarkBackdrop())
        .transition(.opacity)
    }
}

private struct MenuButton: View {
    let title: String
    let subtitle: String
    let primary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(gritty(26))
                    .tracking(2)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .opacity(0.7)
            }
            .foregroundStyle(primary ? Color.black : bone)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 4).fill(primary ? blood : Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(primary ? blood : bone.opacity(0.4), lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Campaign map

struct CampaignMap: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    model.backToMenu()
                } label: {
                    Label("MENU", systemImage: "chevron.left")
                        .font(gritty(16))
                        .foregroundStyle(bone)
                }
                Spacer()
                Text("THE ROUTE")
                    .font(gritty(28))
                    .tracking(2)
                    .foregroundStyle(blood)
                Spacer()
                HeroBadge(hero: model.hero, compact: true)
                    .onTapGesture { model.showRoster = true }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Text("\(coin) \(model.campaignGold) GOLD · CARRIES OVER BETWEEN REGIONS")
                .font(gritty(13))
                .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.30))
                .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Region.allCases) { region in
                        RegionStop(region: region, model: model)
                        if region != Region.allCases.last {
                            // The road between regions.
                            Rectangle()
                                .fill(model.isCleared(region) ? blood.opacity(0.8) : bone.opacity(0.15))
                                .frame(width: 3, height: 22)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DarkBackdrop())
        .transition(.opacity)
    }
}

private struct RegionStop: View {
    let region: Region
    @ObservedObject var model: GameModel

    private func goldText(_ region: Region) -> String {
        let m = region.goldMultiplier
        return m < 10 ? String(format: "%.1f", m) : String(format: "%.0f", m)
    }

    var body: some View {
        let unlocked = model.isUnlocked(region)
        let cleared = model.isCleared(region)
        let isNext = unlocked && !cleared

        Button {
            model.startRegion(region)
        } label: {
            HStack(spacing: 12) {
                Text("\(region.rawValue + 1)")
                    .font(gritty(30))
                    .foregroundStyle(cleared ? bone.opacity(0.5) : (unlocked ? blood : bone.opacity(0.25)))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(region.name.uppercased())
                            .font(gritty(19))
                            .foregroundStyle(unlocked ? bone : bone.opacity(0.35))
                        Spacer()
                        Text(cleared ? "CLEARED" : (unlocked ? "TRAVEL ▸" : "LOCKED"))
                            .font(gritty(13))
                            .foregroundStyle(cleared ? bone.opacity(0.5) : (unlocked ? blood : bone.opacity(0.3)))
                    }
                    Text(unlocked ? region.blurb : "Clear the region before to travel here.")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(bone.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        // Difficulty: one skull per region step.
                        Text(String(repeating: skull, count: region.rawValue + 1))
                            .font(.system(size: 12))
                            .foregroundStyle(blood.opacity(unlocked ? 1 : 0.4))
                        Text("\(region.waves) WAVES · GOLD ×\(goldText(region))")
                            .font(gritty(11))
                            .foregroundStyle(bone.opacity(0.5))
                        Spacer()
                        if let hero = region.rescue {
                            HStack(spacing: 4) {
                                Text(model.isRescued(hero) ? "RESCUED" : "RESCUE")
                                    .font(gritty(11))
                                    .foregroundStyle(bone.opacity(0.6))
                                HeroPortrait(hero: hero, size: 22, silhouette: !model.isRescued(hero) && !unlocked)
                                Text(model.isRescued(hero) || unlocked ? hero.name.uppercased() : "???")
                                    .font(gritty(12))
                                    .foregroundStyle(Color(hero.accent))
                            }
                        } else {
                            Text("FINAL REGION")
                                .font(gritty(11))
                                .foregroundStyle(blood)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isNext ? Color(red: 0.16, green: 0.04, blue: 0.04) : Color.white.opacity(unlocked ? 0.05 : 0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isNext ? blood : bone.opacity(unlocked ? 0.25 : 0.08), lineWidth: isNext ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

// MARK: - Hero roster

struct HeroRoster: View {
    @ObservedObject var model: GameModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("HEROES")
                    .font(gritty(30))
                    .tracking(2)
                    .foregroundStyle(blood)
                Spacer()
                Button("DONE") { dismiss() }
                    .font(gritty(18))
                    .foregroundStyle(bone)
            }
            .padding(16)

            if !model.canSwapHero {
                Text("Heroes can only be swapped between waves.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(blood)
                    .padding(.bottom, 8)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Hero.allCases) { hero in
                        HeroCard(hero: hero, model: model) { dismiss() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .background(panelColor.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private struct HeroCard: View {
    let hero: Hero
    @ObservedObject var model: GameModel
    let chosen: () -> Void

    var body: some View {
        let rescued = model.isRescued(hero)
        let selected = model.hero == hero
        let accent = Color(hero.accent)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                HeroPortrait(hero: hero, size: 52, silhouette: !rescued)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rescued ? hero.name.uppercased() : "???")
                        .font(gritty(24))
                        .foregroundStyle(rescued ? accent : bone.opacity(0.4))
                    Text(hero.role.uppercased())
                        .font(gritty(13))
                        .tracking(1)
                        .foregroundStyle(bone.opacity(0.6))
                }
                Spacer()
                if rescued {
                    Button {
                        model.selectHero(hero)
                        chosen()
                    } label: {
                        Text(selected ? "SELECTED" : "SELECT")
                            .font(gritty(15))
                            .foregroundStyle(selected ? bone : Color.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 3).fill(selected ? Color.white.opacity(0.08) : blood))
                    }
                    .buttonStyle(.plain)
                    .disabled(selected || !model.canSwapHero)
                    .opacity(!selected && !model.canSwapHero ? 0.4 : 1)
                } else if let region = hero.rescuedIn {
                    Text("RESCUE IN\n\(region.name.uppercased())")
                        .multilineTextAlignment(.trailing)
                        .font(gritty(12))
                        .foregroundStyle(bone.opacity(0.5))
                }
            }

            if rescued {
                Text(hero.guns.map { $0.name.uppercased() }.joined(separator: " · "))
                    .font(gritty(12))
                    .foregroundStyle(bone.opacity(0.75))
                AbilityLine(kind: "PASSIVE", name: hero.passiveName, text: hero.passiveText, accent: accent)
                AbilityLine(kind: "ABILITY", name: hero.abilityName,
                            text: "\(hero.abilityText) (\(Int(hero.abilityCooldown))s)", accent: accent)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(selected ? 0.08 : 0.04)))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(selected ? accent : bone.opacity(0.12), lineWidth: selected ? 2 : 1))
    }
}

private struct AbilityLine: View {
    let kind: String
    let name: String
    let text: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Text(kind)
                    .font(gritty(10))
                    .foregroundStyle(bone.opacity(0.45))
                Text(name.uppercased())
                    .font(gritty(14))
                    .foregroundStyle(accent)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(bone.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The hero's pixel sprite, scaled up crisply. Locked heroes show as a dark silhouette.
struct HeroPortrait: View {
    let hero: Hero
    var size: CGFloat = 40
    var silhouette = false

    var body: some View {
        Image(uiImage: UIImage(cgImage: hero.texture.cgImage()))
            .resizable()
            .interpolation(.none)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .colorMultiply(silhouette ? .black : .white)
            .opacity(silhouette ? 0.6 : 1)
            .accessibilityHidden(true)
    }
}

/// Small "who's playing" badge.
private struct HeroBadge: View {
    let hero: Hero
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            HeroPortrait(hero: hero, size: compact ? 26 : 34)
            if !compact {
                VStack(alignment: .leading, spacing: 0) {
                    Text(hero.name.uppercased())
                        .font(gritty(18))
                        .foregroundStyle(Color(hero.accent))
                    Text("TAP TO CHANGE HERO")
                        .font(gritty(10))
                        .foregroundStyle(bone.opacity(0.5))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hero: \(hero.name). Tap to change")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Region cleared

struct RegionClearedOverlay: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Text(model.region?.name.uppercased() ?? "")
                .font(gritty(22))
                .tracking(2)
                .foregroundStyle(bone.opacity(0.7))
            FlickeringTitle(text: "CLEARED", size: 76)

            if let hero = model.lastRescue {
                VStack(spacing: 6) {
                    Text("RESCUED")
                        .font(gritty(16))
                        .tracking(3)
                        .foregroundStyle(bone.opacity(0.6))
                    HeroPortrait(hero: hero, size: 96)
                    Text(hero.name.uppercased())
                        .font(gritty(34))
                        .foregroundStyle(Color(hero.accent))
                    Text("\(hero.role.uppercased()) · \(hero.passiveName.uppercased()) · \(hero.abilityName.uppercased())")
                        .font(gritty(12))
                        .foregroundStyle(bone.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Text(hero.passiveText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(bone.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
            }

            if model.region == Region.allCases.last {
                Text("THE SOURCE IS DESTROYED.\nTHE DEAD STILL WALK. ENDLESS AWAITS.")
                    .multilineTextAlignment(.center)
                    .font(gritty(18))
                    .foregroundStyle(blood)
                    .padding(.top, 8)
            } else if let next = model.region.flatMap({ Region(rawValue: $0.rawValue + 1) }) {
                Text("NEXT STOP: \(next.name.uppercased())")
                    .font(gritty(16))
                    .foregroundStyle(bone.opacity(0.6))
            }

            Spacer()
            MenuButton(title: "CONTINUE", subtitle: "Back to the route", primary: true) { model.openMap() }
                .padding(.horizontal, 40)
            Spacer().frame(height: 50)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DarkBackdrop())
        .transition(.opacity)
    }
}

// MARK: - Game over

struct GameOverOverlay: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            FlickeringTitle(text: "OVERRUN", size: 72)
            if let region = model.region {
                Text(region.name.uppercased())
                    .font(gritty(18))
                    .tracking(2)
                    .foregroundStyle(bone.opacity(0.6))
            }
            Text("YOU HELD OUT TO WAVE")
                .font(gritty(20))
                .tracking(1.5)
                .foregroundStyle(bone)
            Text(model.waveLabel)
                .font(gritty(90))
                .foregroundStyle(blood)
                .shadow(color: blood.opacity(0.8), radius: 12)
            Text("\(model.totalKills) KILLS")
                .font(gritty(22))
                .foregroundStyle(bone.opacity(0.8))
            if model.mode == .endless {
                Text(model.isNewBest ? "NEW BEST" : "BEST: WAVE \(GameModel.waveLabel(model.bestWave))")
                    .font(gritty(20))
                    .foregroundStyle(model.isNewBest ? blood : bone.opacity(0.6))
            }
            Spacer()
            VStack(spacing: 10) {
                MenuButton(title: "TRY AGAIN",
                           subtitle: model.region.map { "Restart \($0.name)" } ?? "New endless run",
                           primary: true) { model.retry() }
                if model.mode == .campaign {
                    MenuButton(title: "THE ROUTE", subtitle: "Pick a region or hero", primary: false) { model.openMap() }
                } else {
                    MenuButton(title: "MENU", subtitle: "Change mode or hero", primary: false) { model.backToMenu() }
                }
            }
            .padding(.horizontal, 40)
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DarkBackdrop())
        .transition(.opacity)
    }
}

// MARK: - Shared pieces

/// Dark red-to-black vignette behind the full-screen menus.
struct DarkBackdrop: View {
    var body: some View {
        RadialGradient(colors: [Color(red: 0.20, green: 0.02, blue: 0.02).opacity(0.9), .black.opacity(0.97)],
                       center: .center, startRadius: 20, endRadius: 460)
            .ignoresSafeArea()
    }
}

/// Big blood-red title that flickers now and then like a dying neon sign.
struct FlickeringTitle: View {
    let text: String
    let size: CGFloat
    @State private var on = true
    @State private var timer: Timer?

    var body: some View {
        Text(text)
            .font(gritty(size))
            .foregroundStyle(blood)
            .shadow(color: blood.opacity(on ? 0.9 : 0.1), radius: 16)
            .shadow(color: .black, radius: 0, x: 4, y: 4)
            .opacity(on ? 1 : 0.35)
            .onAppear {
                timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
                    // Mostly on, with the occasional stutter.
                    on = Double.random(in: 0...1) > 0.06
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }
}
