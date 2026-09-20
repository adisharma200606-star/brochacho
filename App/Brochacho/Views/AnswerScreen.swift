import SwiftUI

/// The reply to a question: at most three sentences, and a command to copy when there is one.
struct AnswerScreen: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.question)
                .font(model.theme.font(13))
                .foregroundStyle(NotchTheme.dim)
                .lineLimit(1)

            Text(model.isThinking ? "Thinking…" : model.answerText)
                .font(model.theme.font(model.theme.textSize * 0.92))
                .foregroundStyle(model.isThinking ? NotchTheme.dim : Color.white)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if let command = model.answerCommand {
                HStack(spacing: 8) {
                    Text(command)
                        .font(.system(size: 13, design: .monospaced))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    Button(model.didCopy ? "Copied" : "Copy") { model.onCopyCommand() }
                        .buttonStyle(PillButtonStyle(theme: model.theme))
                }
                .padding(.leading, 12)
                .padding(.trailing, 6)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.12)))
            }
        }
        .padding(.horizontal, 10)
    }
}
