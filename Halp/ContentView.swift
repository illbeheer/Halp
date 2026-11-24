import SwiftUI
import SpriteKit

// Gritty survival-horror look: near-black panels, blood red and bone white.
private let panelColor = Color(red: 0.05, green: 0.05, blue: 0.06)
private let blood = Color(red: 0.80, green: 0.08, blue: 0.06)
private let bone = Color(red: 0.88, green: 0.85, blue: 0.78)
/// Kill-count glyph (text-style skull, not the color emoji).
private let skull = "\u{2620}\u{FE0E}"

/// Heavy condensed type for numbers and headings.
private func gritty(_ size: CGFloat) -> Font {
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
                MenuOverlay(bestWave: model.bestWave, start: model.start)
            case .playing:
                EmptyView()
            case .gameOver:
                GameOverOverlay(wave: model.waveLabel,
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
            var text = "Unlock now for \(skull) \(cost)"
            if let freeWave = model.nextFreeUnlockWave {
                text += ", or wait: it unlocks free after wave \(freeWave)."
            }
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

    var body: some View {
        ZStack {
            // Day/night icon, centered on the screen.
            DayNightIndicator(isNight: model.isNight, upcoming: !model.waveInProgress)

            HStack(alignment: .center) {
                // Wave number (big and bloody), barricade health and kills (currency).
                VStack(alignment: .leading, spacing: 2) {
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
            Image(systemName: isNight ? "moon.fill" : "sun.haze.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(isNight ? blood : Color(red: 0.80, green: 0.62, blue: 0.35))
                .shadow(color: isNight ? blood : .clear, radius: 8)
            Text(upcoming ? (isNight ? "NIGHT FALLS" : "NEXT: DAY") : (isNight ? "NIGHT" : "DAY"))
                .font(gritty(12))
                .tracking(1)
                .foregroundStyle(bone.opacity(0.8))
        }
        .animation(.easeInOut(duration: 0.3), value: isNight)
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
        .overlay(alignment: .top) {
            Rectangle().fill(blood.opacity(0.6)).frame(height: 2)
        }
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
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: upgrade.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(upgrade.title.uppercased())
                        .font(gritty(14))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(model.detail(upgrade))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(bone.opacity(0.6))
                Text(maxed ? "MAX" : "\(skull) \(model.cost(upgrade))")
                    .font(gritty(16))
                    .foregroundStyle(maxed ? bone.opacity(0.5) : (affordable ? blood : bone.opacity(0.35)))
            }
            .foregroundStyle(bone)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
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

// MARK: - Overlays

private struct MenuOverlay: View {
    let bestWave: Double
    let start: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            FlickeringTitle(text: "HALP!", size: 110)
            Text("THE DEAD DON'T STOP.\nNEITHER DO YOU.")
                .multilineTextAlignment(.center)
                .font(gritty(20))
                .tracking(1.5)
                .foregroundStyle(bone)
            Text("Hold the barricade. Send each wave with ▶.\nTap a slot to build turrets and catapults.\nAfter every 3rd wave, night falls (3.5, 6.5…).")
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(bone.opacity(0.6))
                .padding(.horizontal, 20)
            if bestWave > 0 {
                Text("BEST: WAVE \(GameModel.waveLabel(bestWave))")
                    .font(gritty(20))
                    .foregroundStyle(blood)
            }
            Spacer()
            PulsingText("TAP TO SURVIVE")
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(colors: [Color(red: 0.18, green: 0.02, blue: 0.02).opacity(0.85), .black.opacity(0.95)],
                           center: .center, startRadius: 20, endRadius: 420)
                .ignoresSafeArea()
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: start)
        .transition(.opacity)
    }
}

private struct GameOverOverlay: View {
    let wave: String
    let kills: Int
    let bestWave: Double
    let isNewBest: Bool
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            FlickeringTitle(text: "OVERRUN", size: 72)
            Text("YOU HELD OUT TO WAVE")
                .font(gritty(20))
                .tracking(1.5)
                .foregroundStyle(bone)
            Text(wave)
                .font(gritty(90))
                .foregroundStyle(blood)
                .shadow(color: blood.opacity(0.8), radius: 12)
            Text("\(kills) KILLS")
                .font(gritty(22))
                .foregroundStyle(bone.opacity(0.8))
            Text(isNewBest ? "NEW BEST" : "BEST: WAVE \(GameModel.waveLabel(bestWave))")
                .font(gritty(20))
                .foregroundStyle(isNewBest ? blood : bone.opacity(0.6))
            Spacer()
            PulsingText("TAP TO GO AGAIN")
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(colors: [Color(red: 0.25, green: 0.0, blue: 0.0).opacity(0.75), .black.opacity(0.95)],
                           center: .center, startRadius: 20, endRadius: 420)
                .ignoresSafeArea()
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: retry)
        .transition(.opacity)
    }
}

/// Big blood-red title that flickers now and then like a dying neon sign.
private struct FlickeringTitle: View {
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

private struct PulsingText: View {
    let text: String
    @State private var dim = false

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(gritty(24))
            .tracking(2)
            .foregroundStyle(bone)
            .opacity(dim ? 0.25 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
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
