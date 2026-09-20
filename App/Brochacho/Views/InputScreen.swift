import SwiftUI

/// The box. Type a name and the matches appear under it. Enter opens the highlighted one.
struct InputScreen: View {
    @ObservedObject var model: NotchModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("", text: $model.text)
                    .textFieldStyle(.plain)
                    .font(model.theme.font(model.theme.textSize * 2.1, .medium))
                    .kerning(-0.6)
                    .focused($focused)
                    .disableAutocorrection(true)
                    .onSubmit { model.onSubmit(nil) }
                    .onChange(of: model.text) { newValue in model.onTextChange(newValue) }

                if model.isListening {
                    ListeningDots(color: model.theme.glowColors.first ?? .white)
                } else {
                    Text("hold to talk")
                        .font(model.theme.font(12))
                        .foregroundStyle(NotchTheme.dim)
                }
            }
            .padding(.horizontal, 8)

            VStack(spacing: 2) {
                ForEach(model.rows) { row in
                    Button {
                        model.onSubmit(row.id)
                    } label: {
                        HStack {
                            Text(row.title)
                                .font(model.theme.font(model.theme.textSize, row.id == model.selected ? .medium : .regular))
                                .lineLimit(1)
                            Spacer(minLength: 12)
                            Text(row.detail)
                                .font(model.theme.font(13))
                                .foregroundStyle(NotchTheme.dim)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .foregroundStyle(row.id == model.selected ? Color.white : Color(white: 0.78))
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(row.id == model.selected ? NotchTheme.row : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if model.isUnknown {
                    Text("?")
                        .font(model.theme.font(model.theme.textSize))
                        .foregroundStyle(NotchTheme.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                }
            }
        }
        .onAppear { focused = true }
        .onChange(of: model.focusToken) { _ in focused = true }
    }
}

/// Three dots that pulse while he is listening.
struct ListeningDots: View {
    let color: Color
    @State private var on = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .opacity(on ? 1 : 0.25)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(index) * 0.15), value: on)
            }
        }
        .onAppear { on = true }
    }
}
