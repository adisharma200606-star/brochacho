import SwiftUI

/// A quick look at recent notes or upcoming reminders, so what was captured does not vanish.
/// Reminders can be ticked off right here; clicking a line opens it in its own app.
struct GlanceScreen: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.glanceTitle)
                .font(model.theme.font(13))
                .foregroundStyle(NotchTheme.dim)
                .padding(.horizontal, 10)

            if model.glanceItems.isEmpty {
                Text(model.glanceEmpty)
                    .font(model.theme.font(model.theme.textSize * 0.9))
                    .foregroundStyle(NotchTheme.dim)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }

            VStack(spacing: 2) {
                ForEach(model.glanceItems) { item in
                    HStack(spacing: 10) {
                        if let done = item.done {
                            Button { model.onGlanceTick(item.id) } label: {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(done ? NotchTheme.ok : NotchTheme.dim)
                                    .frame(width: 26, height: 26)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        Button { model.onGlanceOpen(item.id) } label: {
                            HStack {
                                Text(item.title)
                                    .font(model.theme.font(model.theme.textSize * 0.9))
                                    .strikethrough(item.done == true)
                                    .foregroundStyle(item.done == true ? NotchTheme.dim : Color.white)
                                    .lineLimit(1)
                                Spacer(minLength: 10)
                                Text(item.detail)
                                    .font(model.theme.font(12))
                                    .foregroundStyle(NotchTheme.dim)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
                }
            }

            if !model.glanceButtons.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(model.glanceButtons.enumerated()), id: \.offset) { index, title in
                        Button(title) { model.onGlanceButton(index) }
                            .buttonStyle(PillButtonStyle(theme: model.theme))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
            }
        }
    }
}
