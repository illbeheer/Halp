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
                SpriteView(scene: model.scene, options: [.ignoresSiblingOrder])
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WAVE \(max(model.wave, 1))")
                    .font(pixelFont)
                    .foregroundStyle(.white)
                HealthBar(value: model.baseHP, max: model.maxBaseHP)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("🧟")
                Text("\(model.kills)")
                    .font(pixelFont)
                    .foregroundStyle(.yellow)
                    .monospacedDigit()
            }

            Spacer()

            Button {
                model.isFastForward.toggle()
            } label: {
                Text("2x")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .frame(width: 56, height: 40)
                    .foregroundStyle(model.isFastForward ? Color.black : Color.white)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(model.isFastForward ? Color.yellow : Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.yellow, lineWidth: 2)
                    )
            }
            .accessibilityLabel(model.isFastForward ? "Normal speed" : "Double speed")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(panelColor)
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
            Text("Hold the barricade.\nKill zombies, buy upgrades,\nbuild turrets. Survive.")
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
