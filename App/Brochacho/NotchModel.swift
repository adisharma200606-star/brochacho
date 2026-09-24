import BrochachoCore
import SwiftUI

/// Everything the notch shows. The views read it, the `Brain` writes it. Nothing here does any work.
@MainActor
final class NotchModel: ObservableObject {

    enum Screen: Equatable {
        case input      // the box, with matches under it
        case line       // one line of text: what he said, or a confirmation
        case pull       // something handed back from the stash
        case tuner
        case answer     // the reply to a question
        case chooser    // "which one did you mean?"
        case timer      // the running timer, with Stop and more time
        case glance     // recent notes, or upcoming reminders
    }

    /// One line in the glance.
    struct GlanceItem: Identifiable, Equatable {
        let id: Int
        let title: String
        let detail: String
        /// Nil when the item cannot be ticked (notes); true or false for reminders.
        var done: Bool?
    }

    struct Row: Identifiable, Equatable {
        let id: Int
        let title: String
        let detail: String
    }

    @Published var screen: Screen = .input
    @Published var theme: NotchTheme

    // input
    @Published var text = ""
    @Published var rows: [Row] = []
    @Published var selected = 0
    @Published var isUnknown = false
    @Published var isListening = false
    /// Bumped each time the box opens, so the text field can take the keyboard again.
    @Published var focusToken = 0

    // line
    @Published var lineText = ""

    // pull
    @Published var pullTitle = ""
    @Published var pullDetail = ""

    // tuner
    @Published var tuner = TunerDisplay.idle
    @Published var tuningName = ""
    @Published var tuningStrings: [String] = []
    @Published var lockedStrings: [Int] = []

    // answer
    @Published var question = ""
    @Published var answerText = ""
    @Published var answerCommand: String? = nil
    @Published var isThinking = false
    @Published var didCopy = false

    // chooser
    @Published var chooserTitle = ""
    @Published var chooserOptions: [String] = []

    // timer, shown beside the closed notch and on its own screen
    @Published var timerText: String? = nil
    @Published var timerFraction: Double = 0

    // glance
    @Published var glanceTitle = ""
    @Published var glanceItems: [GlanceItem] = []
    @Published var glanceEmpty = ""
    @Published var glanceButtons: [String] = []

    // What the views call. The Brain fills these in.
    var onTextChange: (String) -> Void = { _ in }
    var onSubmit: (Int?) -> Void = { _ in }
    var onAnother: () -> Void = {}
    var onChoose: (Int) -> Void = { _ in }
    var onTuningStep: (Int) -> Void = { _ in }
    var onCopyCommand: () -> Void = {}
    var onTimerTap: () -> Void = {}
    var onStopTimer: () -> Void = {}
    var onAddTime: (Int) -> Void = { _ in }
    var onGlanceOpen: (Int) -> Void = { _ in }
    var onGlanceTick: (Int) -> Void = { _ in }
    var onGlanceButton: (Int) -> Void = { _ in }

    init(theme: NotchTheme) {
        self.theme = theme
    }

    func moveSelection(_ delta: Int) {
        guard !rows.isEmpty else { return }
        selected = max(0, min(rows.count - 1, selected + delta))
    }
}
