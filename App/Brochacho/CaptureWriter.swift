import AppKit
import BrochachoCore
import EventKit

/// Puts a thought where it belongs: Apple Notes or Apple Reminders. Both sync to the iPhone by themselves.
enum CaptureWriter {

    // MARK: Notes (AppleScript: Notes has no other way in)

    /// Makes a note without bringing Notes to the front. Returns false if Notes refused.
    static func makeNote(_ text: String) -> Bool {
        let body = htmlEscaped(text).replacingOccurrences(of: "\n", with: "<br>")
        let source = """
        tell application "Notes"
            make new note with properties {body:"\(appleScriptEscaped(body))"}
        end tell
        """
        return run(source)
    }

    /// Opens Notes on a fresh, empty note, ready to type.
    static func openFreshNote() -> Bool {
        let source = """
        tell application "Notes"
            activate
            set fresh to make new note with properties {body:""}
            show fresh
        end tell
        """
        return run(source)
    }

    private static func run(_ source: String) -> Bool {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error = error {
            NSLog("Brochacho: Notes said no: \(error)")
            return false
        }
        return true
    }

    private static func appleScriptEscaped(_ text: String) -> String {
        return text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func htmlEscaped(_ text: String) -> String {
        return text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: Reminders (EventKit)

    private static let store = EKEventStore()

    /// Makes a reminder. `due` nil means a plain to-do. `completion` runs on the main thread with true on success.
    static func makeReminder(title: String, due: Date?, completion: @escaping (Bool) -> Void) {
        let save: (Bool) -> Void = { granted in
            guard granted else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            let reminder = EKReminder(eventStore: store)
            reminder.title = title
            reminder.calendar = store.defaultCalendarForNewReminders()
            if let due = due {
                reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
                reminder.addAlarm(EKAlarm(absoluteDate: due))     // this is what makes the phone buzz
            }
            do {
                try store.save(reminder, commit: true)
                DispatchQueue.main.async { completion(true) }
            } catch {
                NSLog("Brochacho: could not save the reminder: \(error)")
                DispatchQueue.main.async { completion(false) }
            }
        }

        if #available(macOS 14.0, *) {
            store.requestFullAccessToReminders { granted, _ in save(granted) }
        } else {
            store.requestAccess(to: .reminder) { granted, _ in save(granted) }
        }
    }

    static func openReminders() {
        _ = Opener.openApp("com.apple.reminders")
    }
}
