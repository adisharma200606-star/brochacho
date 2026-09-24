import SwiftUI

/// What sits inside the expanded notch. DynamicNotchKit builds this view once and keeps it, so it never
/// changes identity; it simply shows whichever screen the model asks for.
struct NotchRootView: View {
    @ObservedObject var model: NotchModel

    /// The expanded notch sizes itself to its content, so the width is set here.
    static let width: CGFloat = 440

    var body: some View {
        Group {
            switch model.screen {
            case .input: InputScreen(model: model)
            case .line: LineScreen(model: model)
            case .pull: PullScreen(model: model)
            case .tuner: TunerScreen(model: model)
            case .answer: AnswerScreen(model: model)
            case .chooser: ChooserScreen(model: model)
            case .timer: TimerScreen(model: model)
            case .glance: GlanceScreen(model: model)
            }
        }
        .frame(width: NotchRootView.width, alignment: .leading)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .foregroundStyle(.white)
        .animation(model.theme.spring, value: model.screen)
        .animation(model.theme.spring, value: model.rows)
    }
}

/// Shown to the left of the closed notch while a timer runs: a small dot in the glow colour.
struct CompactLeadingView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        Circle()
            .fill(model.theme.glowColors.first ?? .white)
            .frame(width: 8, height: 8)
            .opacity(model.timerText == nil ? 0 : 1)
            .padding(8)
            .contentShape(Rectangle())
            .onTapGesture { model.onTimerTap() }
    }
}

/// Shown to the right of the closed notch while a timer runs: the time left.
struct CompactTrailingView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        Text(model.timerText ?? "")
            .font(model.theme.font(13, .medium))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { model.onTimerTap() }
    }
}
