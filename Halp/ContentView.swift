import SwiftUI
import SpriteKit

// Gritty survival-horror look: near-black panels, blood red and bone white.
let panelColor = Color(red: 0.05, green: 0.05, blue: 0.06)
let blood = Color(red: 0.80, green: 0.08, blue: 0.06)
let bone = Color(red: 0.88, green: 0.85, blue: 0.78)
/// Kill-count glyph (text-style skull, not the color emoji).
let skull = "\u{2620}\u{FE0E}"

/// Heavy condensed type for numbers and headings.
func gritty(_ size: CGFloat) -> Font {
    .custom("Futura-CondensedExtraBold", size: size)
}

struct ContentView: View {
    @StateObject private var model = GameModel()

    var body: some View {
        ZStack {
            panelColor.ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(model: model)
                SpriteView(scene: model.scene, isPaused: model.isPaused, options: [.ignoresSiblingOrder])
                    .overlay(alignment: .bottomTrailing) {
                        FastForwardButton(model: model)
                            .padding(.trailing, 12)
                            .padding(.bottom, 146) // just above the barricade line
                    }
                    .overlay(alignment: .bottomLeading) {
                        AbilityButton(model: model)
                            .padding(.leading, 12)
                            .padding(.bottom, 140)
                    }
                    .overlay(alignment: .top) {
                        PerkBar(perks: model.activePerks)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        if model.isPaused {
                            Text("PAUSED")
                                .font(gritty(48))
                                .tracking(4)
                                .foregroundStyle(bone)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.45))
                                .allowsHitTesting(false)
                        }
                    }
                UpgradePanel(model: model)
            }

            switch model.phase {
            case .menu:
                MenuOverlay(model: model)
            case .map:
                CampaignMap(model: model)
            case .playing:
                EmptyView()
            case .regionCleared:
                RegionClearedOverlay(model: model)
            case .gameOver:
                GameOverOverlay(model: model)
            }
        }
        .statusBarHidden(true)
        .animation(.easeOut(duration: 0.25), value: model.phase)
        .sheet(isPresented: $model.showRoster) {
            HeroRoster(model: model)
        }
        .confirmationDialog(slotTitle, isPresented: slotDialogShown, titleVisibility: .visible) {
            slotButtons
        } message: {
            Text(slotMessage)
        }
    }

    // MARK: Slot menu (tap a slot on the battlefield)

    private var slotDialogShown: Binding<Bool> {
        Binding(get: { model.selectedSlot != nil },
                set: { if !$0 { model.selectedSlot = nil } })
    }

    private var slotTitle: String {
        guard let index = model.selectedSlot else { return "" }
        switch model.slots[index] {
        case .locked: return "Locked slot"
        case .empty: return "Build on this slot"
        case .turret: return "Turret · LV \(model.slotLevels[index])"
        case .catapult: return "Catapult · LV \(model.slotLevels[index])"
        }
    }

    @ViewBuilder private var slotButtons: some View {
        if let index = model.selectedSlot {
            if model.slots[index] == .locked {
                if index == model.nextLockedSlot, let cost = model.unlockCost, model.kills >= cost {
                    Button("Unlock for \(skull) \(cost)") { model.unlockSlot(index) }
                }
            } else if model.slots[index] == .empty {
                let turretCost = model.buildCost(.turret)
                let catapultCost = model.buildCost(.catapult)
                if model.kills >= turretCost {
                    Button("Turret – \(skull) \(turretCost)") { model.build(.turret, at: index) }
                }
                if model.kills >= catapultCost {
                    Button("Catapult – \(skull) \(catapultCost)") { model.build(.catapult, at: index) }
                }
            } else if let cost = model.upgradeCost(slot: index), model.kills >= cost {
                Button("Upgrade to LV \(model.slotLevels[index] + 1) – \(skull) \(cost)") {
                    model.upgradeDefense(at: index)
                }
            }
        }
        Button("Cancel", role: .cancel) {}
    }

    private var slotMessage: String {
        guard let index = model.selectedSlot else { return "" }
        switch model.slots[index] {
        case .locked:
            guard index == model.nextLockedSlot, let cost = model.unlockCost else {
                return "Slots unlock in order. Unlock the brighter padlock first."
            }
            var text = "Unlock this slot for \(skull) \(cost)."
            if model.kills < cost {
                text += "\n\nYou have \(skull) \(model.kills)."
            }
            return text
        case .empty:
            var text = "Turret (\(skull) \(model.buildCost(.turret))): fast shots at one zombie.\n"
                + "Catapult (\(skull) \(model.buildCost(.catapult))): slow, lobs rocks that hit a whole group."
            if model.kills < min(model.buildCost(.turret), model.buildCost(.catapult)) {
                text += "\n\nYou have \(skull) \(model.kills). Kill more zombies!"
            }
            return text
        case .turret:
            var text = String(format: "%.1f damage, %.1f shots/s.",
                              Double(model.turretDamage(slot: index)), 1 / model.turretInterval(slot: index))
            text += upgradeNote(index)
            return text
        case .catapult:
            var text = String(format: "%.1f splash damage every %.1fs, radius %.0f.",
                              Double(model.catapultDamage(slot: index)), model.catapultInterval(slot: index),
                              Double(model.catapultRadius(slot: index)))
            text += upgradeNote(index)
            return text
        }
    }

    private func upgradeNote(_ index: Int) -> String {
        guard let cost = model.upgradeCost(slot: index) else { return "\n\nFully upgraded." }
        if model.kills < cost {
            return "\n\nNext level: \(skull) \(cost). You have \(skull) \(model.kills)."
        }
        return ""
    }
}

// MARK: - Active perks

/// Little timers along the top of the battlefield for each active perk.
private struct PerkBar: View {
    let perks: [Perk: Int]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Perk.allCases, id: \.self) { perk in
                if let secondsLeft = perks[perk] {
                    HStack(spacing: 4) {
                        Text(perk.emoji)
                        Text("\(secondsLeft)")
                            .font(gritty(16))
                            .monospacedDigit()
                    }
                    .foregroundStyle(bone)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(perk.color), lineWidth: 2))
                    .shadow(color: Color(perk.color).opacity(0.7), radius: 6)
                    .accessibilityLabel("\(perk.title), \(secondsLeft) seconds left")
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: perks.keys.count)
    }
}

// MARK: - Top bar

private struct TopBar: View {
    @ObservedObject var model: GameModel

    /// "FARMLANDS · 3/8" in Campaign, "ENDLESS" otherwise.
    private var regionCaption: String {
        if let region = model.region, let waves = model.regionWaves {
            return "\(region.name.uppercased()) · \(min(max(model.wave, 1), waves))/\(waves)"
        }
        return "ENDLESS"
    }

    var body: some View {
        ZStack {
            // Day/night icon, centered on the screen.
            DayNightIndicator(isNight: model.isNight, upcoming: !model.waveInProgress)

            HStack(alignment: .center) {
                // Wave number (big and bloody), barricade health and kills (currency).
                VStack(alignment: .leading, spacing: 2) {
                    Text(regionCaption)
                        .font(gritty(11))
                        .tracking(1)
                        .foregroundStyle(bone.opacity(0.6))
                        .lineLimit(1)
                    WaveNumber(label: model.waveLabel, isNight: model.isNightWave && model.waveInProgress)
                    HealthBar(value: model.baseHP, max: model.maxBaseHP)
                    HStack(spacing: 4) {
                        Text(skull)
                            .foregroundStyle(blood)
                        Text("\(model.kills)")
                            .font(gritty(17))
                            .foregroundStyle(bone)
                            .monospacedDigit()
                    }
                }

                Spacer()

                // Play and pause, top right.
                HStack(spacing: 8) {
                    ControlButton(icon: "play.fill", tint: blood, enabled: model.canPlay,
                                  highlight: model.canPlay, label: "Play",
                                  action: model.playPressed)
                    ControlButton(icon: "pause.fill", tint: bone, enabled: model.canPause,
                                  highlight: false, label: "Pause",
                                  action: model.pausePressed)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(panelColor)
        .overlay(alignment: .bottom) {
            Rectangle().fill(blood.opacity(0.6)).frame(height: 2)
        }
    }
}

/// The wave number in blood red. It flickers like a failing light when it changes.
private struct WaveNumber: View {
    let label: String
    let isNight: Bool
    @State private var flicker = 1.0

    var body: some View {
        Text(label)
            .font(gritty(38))
            .foregroundStyle(blood)
            .shadow(color: blood.opacity(0.8), radius: isNight ? 10 : 4)
            .shadow(color: .black, radius: 0, x: 2, y: 2)
            .opacity(flicker)
            .onChange(of: label) { _ in runFlicker() }
            .accessibilityLabel("Wave \(label)")
    }

    private func runFlicker() {
        let steps: [(Double, Double)] = [(0.15, 0.05), (1, 0.08), (0.3, 0.06), (1, 0.12), (0.5, 0.05), (1, 0.1)]
        var delay = 0.0
        for (opacity, duration) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { flicker = opacity }
            delay += duration
        }
    }
}

/// Sun, or a blood moon at night. Between waves it previews the next phase.
private struct DayNightIndicator: View {
    let isNight: Bool
    let upcoming: Bool

    var body: some View {
        VStack(spacing: 1) {
            // Sun and moon crossfade (the moon rises as the sun sinks).
            ZStack {
                Image(systemName: "sun.haze.fill")
                    .foregroundStyle(Color(red: 0.80, green: 0.62, blue: 0.35))
                    .opacity(isNight ? 0 : 1)
                    .offset(y: isNight ? 10 : 0)
                Image(systemName: "moon.fill")
                    .foregroundStyle(blood)
                    .shadow(color: blood, radius: 8)
                    .opacity(isNight ? 1 : 0)
                    .offset(y: isNight ? 0 : 10)
            }
            .font(.system(size: 32, weight: .bold))
            .frame(height: 36)
            .clipped()
            Text(upcoming ? (isNight ? "NIGHT FALLS" : "NEXT: DAY") : (isNight ? "NIGHT" : "DAY"))
                .font(gritty(12))
                .tracking(1)
                .foregroundStyle(bone.opacity(0.8))
        }
        .animation(.easeInOut(duration: 1.5), value: isNight)
        .accessibilityElement(children: .combine)
    }
}

/// A square top-bar button. `highlight` makes it throb to say "press me".
private struct ControlButton: View {
    let icon: String
    let tint: Color
    let enabled: Bool
    let highlight: Bool
    let label: String
    let action: () -> Void
    @State private var glow = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .black))
                .frame(width: 48, height: 48)
                .foregroundStyle(highlight ? Color.black : bone)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(highlight ? tint : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(tint, lineWidth: 2)
                )
                .shadow(color: highlight ? tint.opacity(glow ? 0.9 : 0.3) : .clear, radius: 8)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        .accessibilityLabel(label)
    }
}

/// The hero's tap ability, bottom-left of the battlefield, with its cooldown.
private struct AbilityButton: View {
    @ObservedObject var model: GameModel

    var body: some View {
        let ready = model.abilityReady
        let usable = model.canUseAbility
        let accent = Color(model.hero.accent)

        Button(action: model.useAbility) {
            ZStack {
                Circle()
                    .fill(ready ? accent.opacity(0.9) : Color.black.opacity(0.6))
                Circle()
                    .stroke(ready ? bone : bone.opacity(0.3), lineWidth: 2)
                if ready {
                    Image(systemName: model.hero.abilityIcon)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(bone)
                } else {
                    Text("\(model.abilityCooldown)")
                        .font(gritty(20))
                        .foregroundStyle(bone.opacity(0.7))
                        .monospacedDigit()
                }
            }
            .frame(width: 52, height: 52)
            .shadow(color: ready && usable ? accent : .clear, radius: 8)
        }
        .disabled(!usable)
        .opacity(model.phase == .playing ? (usable || !ready ? 1 : 0.6) : 0)
        .accessibilityLabel(ready ? "\(model.hero.abilityName), ready" : "\(model.hero.abilityName), \(model.abilityCooldown) seconds")
    }
}

/// The ">>" 2x speed toggle, sitting just above the barricade on the right.
private struct FastForwardButton: View {
    @ObservedObject var model: GameModel

    var body: some View {
        Button {
            model.isFastForward.toggle()
        } label: {
            Image(systemName: "forward.fill")
                .font(.system(size: 20, weight: .black))
                .frame(width: 52, height: 40)
                .foregroundStyle(model.isFastForward ? Color.black : bone)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(model.isFastForward ? bone : Color.black.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(bone.opacity(0.8), lineWidth: 2)
                )
        }
        .accessibilityLabel(model.isFastForward ? "Normal speed" : "Double speed")
    }
}

private struct HealthBar: View {
    let value: Int
    let max: Int

    var body: some View {
        let fraction = CGFloat(value) / CGFloat(Swift.max(max, 1))
        ZStack(alignment: .leading) {
            Rectangle().fill(Color.white.opacity(0.08))
            Rectangle()
                .fill(fraction > 0.3 ? bone.opacity(0.85) : blood)
                .frame(width: 110 * fraction)
        }
        .frame(width: 110, height: 8)
        .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
        .animation(.easeOut(duration: 0.2), value: value)
        .accessibilityLabel("Barricade health \(value) of \(max)")
    }
}

// MARK: - Armory (bottom panel): pick a gun, then upgrade it

private struct UpgradePanel: View {
    @ObservedObject var model: GameModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(spacing: 8) {
            GunSelector(model: model)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button {
                    model.showRoster = true
                } label: {
                    HStack(spacing: 3) {
                        Text(model.hero.name.uppercased())
                            .font(gritty(14))
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color(model.hero.accent))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(model.hero.accent), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(!model.canSwapHero)
                .opacity(model.canSwapHero ? 1 : 0.4)
                .accessibilityLabel("Hero: \(model.hero.name). Change hero")
                Text(model.equippedGun.name.uppercased())
                    .font(gritty(16))
                    .foregroundStyle(blood)
                Text(model.equippedGun.blurb)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(bone.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Upgrade.allCases) { upgrade in
                    UpgradeCard(upgrade: upgrade, model: model)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(panelColor)
        .overlay(alignment: .top) {
            Rectangle().fill(blood.opacity(0.6)).frame(height: 2)
        }
    }
}

/// Row of the six gun classes: owned ones switch, others show their price.
private struct GunSelector: View {
    @ObservedObject var model: GameModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.hero.guns) { gun in
                    GunChip(gun: gun, model: model)
                }
            }
        }
    }
}

private struct GunChip: View {
    let gun: Gun
    @ObservedObject var model: GameModel

    var body: some View {
        let owned = model.owns(gun)
        let equipped = model.equippedGun == gun
        let affordable = model.canBuyGun(gun)

        Button {
            model.gunTapped(gun)
        } label: {
            VStack(spacing: 1) {
                Text(gun.shortName.uppercased())
                    .font(gritty(13))
                    .lineLimit(1)
                Text(owned ? (equipped ? "EQUIPPED" : "OWNED") : "\(skull) \(model.price(gun))")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(owned ? bone.opacity(equipped ? 1 : 0.6)
                                           : (affordable ? blood : bone.opacity(0.35)))
            }
            .foregroundStyle(equipped ? bone : bone.opacity(owned ? 0.9 : 0.5))
            .frame(minWidth: 84)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(equipped ? blood.opacity(0.85) : Color.white.opacity(owned ? 0.08 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(equipped ? blood : (affordable ? blood.opacity(0.8) : Color.white.opacity(0.12)),
                            lineWidth: affordable && !owned ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!owned && !affordable)
        .accessibilityLabel(owned ? "\(gun.name)\(equipped ? ", equipped" : "")" : "Buy \(gun.name) for \(model.price(gun)) kills")
    }
}

private struct UpgradeCard: View {
    let upgrade: Upgrade
    @ObservedObject var model: GameModel

    var body: some View {
        let maxed = model.isMaxed(upgrade)
        let affordable = model.canBuy(upgrade)
        let level = model.level(upgrade)

        Button {
            model.buy(upgrade)
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: upgrade.icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(upgrade.title.uppercased())
                        .font(gritty(13))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(upgrade == .repair ? model.detail(upgrade) : "LV \(level) · \(model.detail(upgrade))")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(bone.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(maxed ? "MAX" : "\(skull) \(model.cost(upgrade))")
                    .font(gritty(15))
                    .foregroundStyle(maxed ? bone.opacity(0.5) : (affordable ? blood : bone.opacity(0.35)))
            }
            .foregroundStyle(bone)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(affordable ? Color(red: 0.16, green: 0.05, blue: 0.05) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(affordable ? blood : Color.white.opacity(0.12), lineWidth: affordable ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!affordable)
        .opacity(model.isAvailable(upgrade) || maxed ? 1 : 0.45)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
