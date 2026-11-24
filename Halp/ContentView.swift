import SwiftUI
import SpriteKit

private let panelColor = Color(red: 0.13, green: 0.12, blue: 0.16)
private let pixelFont = Font.system(size: 15, weight: .heavy, design: .monospaced)

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
                    .overlay(alignment: .top) {
                        PerkBar(perks: model.activePerks)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        if model.isPaused {
                            Text("PAUSED")
                                .font(.system(size: 36, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.45))
                                .allowsHitTesting(false)
                        }
                    }
                UpgradePanel(model: model)
            }

            switch model.phase {
            case .menu:
                MenuOverlay(bestWave: model.bestWave, start: model.start)
            case .playing:
                EmptyView()
            case .gameOver:
                GameOverOverlay(wave: model.wave,
                                kills: model.totalKills,
                                bestWave: model.bestWave,
                                isNewBest: model.isNewBest,
                                retry: model.start)
            }
        }
        .statusBarHidden(true)
        .animation(.easeOut(duration: 0.25), value: model.phase)
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
        return model.slots[index] == .locked ? "Locked slot" : "Build on this slot"
    }

    @ViewBuilder private var slotButtons: some View {
        if let index = model.selectedSlot {
            if model.slots[index] == .locked {
                if index == model.nextLockedSlot, let cost = model.unlockCost, model.kills >= cost {
                    Button("Unlock for 🧟 \(cost)") { model.unlockSlot(index) }
                }
            } else if model.slots[index] == .empty {
                let turretCost = model.buildCost(.turret)
                let catapultCost = model.buildCost(.catapult)
                if model.kills >= turretCost {
                    Button("Turret – 🧟 \(turretCost)") { model.build(.turret, at: index) }
                }
                if model.kills >= catapultCost {
                    Button("Catapult – 🧟 \(catapultCost)") { model.build(.catapult, at: index) }
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
            var text = "Unlock now for 🧟 \(cost)"
            if let freeWave = model.nextFreeUnlockWave {
                text += ", or wait: it unlocks free after wave \(freeWave)."
            }
            if model.kills < cost {
                text += "\n\nYou have 🧟 \(model.kills)."
            }
            return text
        case .empty:
            var text = "Turret (🧟 \(model.buildCost(.turret))): fast shots at one zombie.\n"
                + "Catapult (🧟 \(model.buildCost(.catapult))): slow, lobs rocks that hit a whole group."
            if model.kills < min(model.buildCost(.turret), model.buildCost(.catapult)) {
                text += "\n\nYou have 🧟 \(model.kills). Kill more zombies!"
            }
            return text
        case .turret, .catapult:
            return ""
        }
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
                        Text("\(secondsLeft)s")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .overlay(Capsule().stroke(Color(perk.color), lineWidth: 2))
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

    var body: some View {
        ZStack {
            // Day/night icon, centered on the screen.
            DayNightIndicator(isNight: model.isNight, upcoming: !model.waveInProgress)

            HStack(alignment: .center) {
                // Wave, barricade health and kills (currency).
                VStack(alignment: .leading, spacing: 4) {
                    Text("WAVE \(max(model.wave, 1))")
                        .font(pixelFont)
                        .foregroundStyle(.white)
                    HealthBar(value: model.baseHP, max: model.maxBaseHP)
                    HStack(spacing: 4) {
                        Text("🧟")
                        Text("\(model.kills)")
                            .font(pixelFont)
                            .foregroundStyle(.yellow)
                            .monospacedDigit()
                    }
                }

                Spacer()

                // Play and pause, top right.
                HStack(spacing: 8) {
                    ControlButton(icon: "play.fill", tint: .green, enabled: model.canPlay,
                                  highlight: model.canPlay, label: "Play",
                                  action: model.playPressed)
                    ControlButton(icon: "pause.fill", tint: .white, enabled: model.canPause,
                                  highlight: false, label: "Pause",
                                  action: model.pausePressed)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(panelColor)
    }
}

/// Moon or sun, as in the sketch. Between waves it previews the next phase.
private struct DayNightIndicator: View {
    let isNight: Bool
    let upcoming: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: isNight ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(isNight ? Color(red: 0.85, green: 0.85, blue: 1.0) : Color.orange)
            Text(upcoming ? (isNight ? "NEXT: NIGHT" : "NEXT: DAY") : (isNight ? "NIGHT" : "DAY"))
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
        }
        .animation(.easeInOut(duration: 0.3), value: isNight)
        .accessibilityElement(children: .combine)
    }
}

/// A square top-bar button. `highlight` makes it glow to say "press me".
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
                .foregroundStyle(highlight ? Color.black : Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(highlight ? tint : Color.white.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(tint, lineWidth: 2)
                )
                .scaleEffect(highlight && glow ? 1.08 : 1)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        .accessibilityLabel(label)
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
                .foregroundStyle(model.isFastForward ? Color.black : Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(model.isFastForward ? Color.yellow : Color.black.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow, lineWidth: 2)
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
            Rectangle().fill(Color.white.opacity(0.15))
            Rectangle()
                .fill(fraction > 0.3 ? Color.green : Color.red)
                .frame(width: 110 * fraction)
        }
        .frame(width: 110, height: 10)
        .overlay(Rectangle().stroke(Color.white.opacity(0.5), lineWidth: 1))
        .animation(.easeOut(duration: 0.2), value: value)
        .accessibilityLabel("Barricade health \(value) of \(max)")
    }
}

// MARK: - Upgrades

private struct UpgradePanel: View {
    @ObservedObject var model: GameModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Upgrade.allCases) { upgrade in
                UpgradeCard(upgrade: upgrade, model: model)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(panelColor)
    }
}

private struct UpgradeCard: View {
    let upgrade: Upgrade
    @ObservedObject var model: GameModel

    var body: some View {
        let maxed = model.isMaxed(upgrade)
        let affordable = model.canBuy(upgrade)

        Button {
            model.buy(upgrade)
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: upgrade.icon)
                        .font(.system(size: 12, weight: .bold))
                    Text(upgrade.title)
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(model.detail(upgrade))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                Text(maxed ? "MAX" : "🧟 \(model.cost(upgrade))")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(maxed ? Color.white.opacity(0.6) : (affordable ? Color.yellow : Color.red.opacity(0.8)))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(affordable ? Color(red: 0.22, green: 0.30, blue: 0.20) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(affordable ? Color.green.opacity(0.8) : Color.white.opacity(0.15), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(!affordable)
        .opacity(model.isAvailable(upgrade) || maxed ? 1 : 0.5)
    }
}

// MARK: - Overlays

private struct MenuOverlay: View {
    let bestWave: Int
    let start: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("HALP!")
                .font(.system(size: 76, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .shadow(color: .green.opacity(0.6), radius: 0, x: 4, y: 4)
            Text("Hold the barricade.\nPress ▶ to send each wave.\nTap a slot to build turrets\nand catapults. Every 3rd wave\nis a short, brutal night.")
                .multilineTextAlignment(.center)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
            if bestWave > 0 {
                Text("Best: wave \(bestWave)")
                    .font(pixelFont)
                    .foregroundStyle(.yellow)
            }
            Spacer()
            PulsingText("TAP TO START")
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.75).ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture(perform: start)
        .transition(.opacity)
    }
}

private struct GameOverOverlay: View {
    let wave: Int
    let kills: Int
    let bestWave: Int
    let isNewBest: Bool
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("OVERRUN!")
                .font(.system(size: 52, weight: .black, design: .monospaced))
                .foregroundStyle(.red)
            Text("Reached wave \(wave)")
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
            Text("\(kills) zombies killed")
                .font(pixelFont)
                .foregroundStyle(.white.opacity(0.8))
            Text(isNewBest ? "NEW BEST!" : "Best: wave \(bestWave)")
                .font(pixelFont)
                .foregroundStyle(.yellow)
            Spacer()
            PulsingText("TAP TO TRY AGAIN")
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.75).ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture(perform: retry)
        .transition(.opacity)
    }
}

private struct PulsingText: View {
    let text: String
    @State private var dim = false

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .opacity(dim ? 0.3 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    dim = true
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
