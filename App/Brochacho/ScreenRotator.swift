import AppKit
import CoreGraphics
import Darwin
import RotationBridge

/// Turns the screen upside down and back ("one eighty"). The actual private-API call lives in
/// `RotationBridge` (Objective-C; see `App/RotationBridge/Sources/RotationBridge/RotationBridge.m` for why
/// it is not written in Swift). This file only decides which display, which direction, and turns the C
/// result into something the rest of the app can use.
///
/// Private means Apple can change the underlying API in any macOS update. If "one eighty" stops working
/// after an update, `RotationBridge.m` is where to look.
enum ScreenRotator {

    enum Outcome {
        case rotated(to: Int)
        case failed(String)
    }

    /// The display to rotate: the built-in one when there is one, otherwise the main display.
    static var targetDisplay: CGDirectDisplayID {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return CGMainDisplayID() }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return CGMainDisplayID() }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 } ?? CGMainDisplayID()
    }

    /// The current rotation in whole degrees: 0, 90, 180 or 270.
    static func currentRotation(of display: CGDirectDisplayID) -> Int {
        let degrees = Int(CGDisplayRotation(display).rounded()) % 360
        return (degrees + 360) % 360
    }

    /// Upside down if it is upright, upright if it is anything else.
    static func toggleOneEighty() -> Outcome {
        let display = targetDisplay
        let target = currentRotation(of: display) == 180 ? 0 : 180
        if let problem = setRotation(target, of: display) { return .failed(problem) }
        return .rotated(to: target)
    }

    /// Returns nil on success, or a short description of what went wrong.
    static func setRotation(_ degrees: Int, of display: CGDirectDisplayID) -> String? {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = BrochachoRotateDisplay(display, Int32(degrees), &errorPointer)
        defer { if let errorPointer = errorPointer { free(errorPointer) } }
        if result == 0 { return nil }
        return errorPointer.map { String(cString: $0) } ?? "the rotation call failed (\(result))"
    }
}
