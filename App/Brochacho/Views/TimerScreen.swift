import SwiftUI

/// The running timer: time left, a bar that drains, and the controls.
/// Opened by clicking the time beside the closed notch, or by typing "timer" while one runs.
struct TimerScreen: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.timerText ?? "0:00")
                    .font(model.theme.font(64, .ultraLight))
                    .monospacedDigit()
                    .kerning(-2)
                Spacer()
                Text("left")
                    .font(model.theme.font(13))
                    .foregroundStyle(NotchTheme.dim)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(LinearGradient(colors: model.theme.glowColors, startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * CGFloat(max(0, min(1, model.timerFraction))))
                        .animation(.linear(duration: 0.5), value: model.timerFraction)
                }
            }
            .frame(height: 6)

            HStack(spacing: 8) {
                Button("Stop") { model.onStopTimer() }
                    .buttonStyle(PillButtonStyle(theme: model.theme))
                Spacer()
                Button("+1 min") { model.onAddTime(60) }
                    .buttonStyle(PillButtonStyle(theme: model.theme))
                Button("+5 min") { model.onAddTime(300) }
                    .buttonStyle(PillButtonStyle(theme: model.theme))
            }
        }
        .padding(.horizontal, 10)
    }
}
