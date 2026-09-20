import SwiftUI

/// One line: what he just said, or a confirmation such as "call mom · Tomorrow 17:00".
struct LineScreen: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        Text(model.lineText)
            .font(model.theme.font(model.theme.textSize * 1.1, .medium))
            .foregroundStyle(model.theme.tint)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }
}

/// Something handed back from the stash, with a way to ask for a different one.
struct PullScreen: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.pullTitle)
                .font(model.theme.font(model.theme.textSize, .medium))
                .lineLimit(3)
            Text(model.pullDetail)
                .font(model.theme.font(13))
                .foregroundStyle(NotchTheme.dim)
                .lineLimit(1)
            Button("another") { model.onAnother() }
                .buttonStyle(PillButtonStyle(theme: model.theme))
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}

/// "Which one did you mean?" Used when two living bookmarks fit the same page.
struct ChooserScreen: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.chooserTitle)
                .font(model.theme.font(13))
                .foregroundStyle(NotchTheme.dim)
                .padding(.horizontal, 10)
            ForEach(Array(model.chooserOptions.enumerated()), id: \.offset) { index, option in
                Button {
                    model.onChoose(index)
                } label: {
                    Text(option)
                        .font(model.theme.font(model.theme.textSize))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(NotchTheme.row))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The soft translucent pill used for "another" and "Copy".
struct PillButtonStyle: ButtonStyle {
    let theme: NotchTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.font(14, .medium))
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.28 : 0.16)))
            .contentShape(Capsule())
    }
}
