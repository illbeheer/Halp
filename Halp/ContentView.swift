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
    }
}

// MARK: - Top bar

private struct TopBar: View {
    @ObservedObject var model: GameModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
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

            DayNightIndicator(isNight: model.isNight, upcoming: !model.waveInProgress)

            Spacer()

            PlayButton(model: model)
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

/// Starts the next wave; while a wave is running it pauses and resumes.
private struct PlayButton: View {
    @ObservedObject var model: GameModel
    @State private var glow = false

    var body: some View {
        let waiting = !model.waveInProgress && model.phase == .playing
        let icon = model.waveInProgress ? (model.isPaused ? "play.fill" : "pause.fill") : "play.fill"

        Button(action: model.playPressed) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .black))
                .frame(width: 56, height: 56)
                .foregroundStyle(waiting ? Color.black : Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(waiting ? Color.green : Color.white.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green, lineWidth: 2)
                )
                .scaleEffect(waiting && glow ? 1.08 : 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        .accessibilityLabel(waiting ? "Start next wave" : (model.isPaused ? "Resume" : "Pause"))
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
            Text("Hold the barricade.\nPress ▶ to send each wave.\nNights bring tougher zombies.")
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
