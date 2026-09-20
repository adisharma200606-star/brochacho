import BrochachoCore
import SwiftUI

/// The tuner: a huge thin note, how far off it is, a dot on a track, and the strings of the tuning.
struct TunerScreen: View {
    @ObservedObject var model: NotchModel

    private var inTune: Bool { model.tuner.inTune }
    private var accent: Color { inTune ? NotchTheme.ok : NotchTheme.off }

    /// "E2" into "E" and "2". Chromatic mode already keeps them apart.
    private var noteParts: (letter: String, octave: String) {
        guard model.tuner.state != .idle, let label = model.tuner.label else { return ("–", "") }
        if let octave = model.tuner.octave { return (label, String(octave)) }
        let letters = label.prefix { !$0.isNumber && $0 != "-" }
        return (String(letters), String(label.dropFirst(letters.count)))
    }

    private var centsText: String {
        let rounded = Int(model.tuner.cents.rounded())
        if rounded == 0 { return "0" }
        return rounded > 0 ? "+\(rounded)" : "−\(abs(rounded))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { model.onTuningStep(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(RoundButtonStyle())
                Spacer()
                Text(model.tuningName)
                    .font(model.theme.font(13))
                    .foregroundStyle(NotchTheme.dim)
                Spacer()
                Button { model.onTuningStep(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(RoundButtonStyle())
            }

            HStack(alignment: .bottom) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(noteParts.letter)
                        .font(model.theme.font(96, .ultraLight))
                        .kerning(-3)
                    Text(noteParts.octave)
                        .font(model.theme.font(32, .light))
                        .foregroundStyle(NotchTheme.dim)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if model.tuner.state == .idle {
                        Text("pluck a string")
                            .font(model.theme.font(13))
                            .foregroundStyle(NotchTheme.dim)
                    } else {
                        Text(inTune ? "in tune" : centsText)
                            .font(model.theme.font(30, .light))
                            .monospacedDigit()
                            .foregroundStyle(accent)
                        if !inTune {
                            Text(model.tuner.cents < 0 ? "cents, tune up" : "cents, tune down")
                                .font(model.theme.font(13))
                                .foregroundStyle(NotchTheme.dim)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            .frame(height: 96)
            .padding(.horizontal, 8)

            GeometryReader { proxy in
                let clamped = max(-50, min(50, model.tuner.cents))
                let x = proxy.size.width * CGFloat(0.5 + clamped / 100)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18)).frame(height: 4)
                    Capsule().fill(Color.white.opacity(0.6)).frame(width: 2, height: 18)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    Circle()
                        .fill(accent)
                        .frame(width: 18, height: 18)
                        .shadow(color: accent, radius: 8)
                        .opacity(model.tuner.state == .idle ? 0.3 : 1)
                        .position(x: x, y: proxy.size.height / 2)
                        .animation(.linear(duration: 0.09), value: model.tuner.cents)
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 8)

            HStack(spacing: 4) {
                ForEach(Array(model.tuningStrings.enumerated()), id: \.offset) { index, name in
                    let active = model.tuner.state != .idle && model.tuner.stringIndex == index
                    Text(name)
                        .font(model.theme.font(15, .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .foregroundStyle(model.lockedStrings.contains(index) ? NotchTheme.ok : (active ? Color.white : NotchTheme.dim))
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(active ? Color.white.opacity(0.16) : Color.clear))
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

struct RoundButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 32, height: 32)
            .background(Circle().fill(Color.white.opacity(configuration.isPressed ? 0.25 : 0.12)))
            .contentShape(Circle())
    }
}
