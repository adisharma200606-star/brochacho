import AppKit
import CoreGraphics
import Darwin
import IOKit

/// Turns the screen upside down and back ("one eighty").
///
/// macOS has no public way to rotate a display. System Settings does it through a private framework,
/// MonitorPanel, whose `MPDisplay` object has `setOrientation:`. This file loads that framework at run time
/// and calls it the same way, which is also how the open-source Rotator app (github.com/B-HS/rotator)
/// rotates the built-in MacBook screen. If the framework is ever missing, it falls back to the old IOKit
/// request, which works on Intel Macs.
///
/// Private means Apple can change it in any macOS update. If "one eighty" stops working after an update,
/// this file is where to look.
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
        if let problem = setWithMonitorPanel(degrees, display: display) {
            NSLog("Brochacho: MonitorPanel could not rotate (\(problem)); trying IOKit")
            return setWithIOKit(degrees, display: display) ? nil : problem
        }
        return nil
    }

    // MARK: MonitorPanel (what System Settings uses)

    private static let monitorPanel: UnsafeMutableRawPointer? = {
        return dlopen("/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel", RTLD_LAZY | RTLD_LOCAL)
    }()

    // Objective-C methods called through their C function pointers. `self` travels as a raw pointer so that
    // Swift's memory management stays out of the way: `init` consumes the object `alloc` returned.
    private typealias AllocFunction = @convention(c) (UnsafeMutableRawPointer, Selector) -> UnsafeMutableRawPointer?
    private typealias InitFunction = @convention(c) (UnsafeMutableRawPointer, Selector, UInt32) -> UnsafeMutableRawPointer?
    private typealias SetOrientationFunction = @convention(c) (UnsafeMutableRawPointer, Selector, Int) -> Void

    private static func setWithMonitorPanel(_ degrees: Int, display: CGDirectDisplayID) -> String? {
        guard monitorPanel != nil else { return "MonitorPanel is not on this Mac" }
        guard let displayClass: AnyClass = NSClassFromString("MPDisplay") else { return "MPDisplay is missing" }

        let allocSelector = NSSelectorFromString("alloc")
        let initSelector = NSSelectorFromString("initWithCGSDisplayID:")
        let setSelector = NSSelectorFromString("setOrientation:")
        guard class_respondsToSelector(displayClass, initSelector), class_respondsToSelector(displayClass, setSelector),
              let metaclass = object_getClass(displayClass),
              let allocIMP = class_getMethodImplementation(metaclass, allocSelector),
              let initIMP = class_getMethodImplementation(displayClass, initSelector),
              let setIMP = class_getMethodImplementation(displayClass, setSelector) else {
            return "MPDisplay no longer has the methods this expects"
        }

        let classPointer = Unmanaged.passUnretained(displayClass as AnyObject).toOpaque()
        guard let allocated = unsafeBitCast(allocIMP, to: AllocFunction.self)(classPointer, allocSelector),
              let object = unsafeBitCast(initIMP, to: InitFunction.self)(allocated, initSelector, display) else {
            return "MPDisplay would not open this display"
        }
        unsafeBitCast(setIMP, to: SetOrientationFunction.self)(object, setSelector, degrees)
        Unmanaged<AnyObject>.fromOpaque(object).release()      // balance the +1 from alloc/init
        return nil
    }

    // MARK: IOKit (older Macs)

    private typealias ServicePortFunction = @convention(c) (UInt32) -> io_service_t

    private static func setWithIOKit(_ degrees: Int, display: CGDirectDisplayID) -> Bool {
        let transform: UInt32
        switch degrees {
        case 0: transform = 0          // kIOScaleRotate0
        case 90: transform = 0x30      // kIOScaleRotate90
        case 180: transform = 0x60     // kIOScaleRotate180
        case 270: transform = 0x50     // kIOScaleRotate270
        default: return false
        }
        // CGDisplayIOServicePort still exists in the system, but recent SDK headers no longer declare it.
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGDisplayIOServicePort") else { return false }
        let servicePort = unsafeBitCast(symbol, to: ServicePortFunction.self)
        let service = servicePort(display)
        guard service != 0 else { return false }
        let kIOFBSetTransform: UInt32 = 0x0000_0400
        return IOServiceRequestProbe(service, kIOFBSetTransform | (transform << 16)) == KERN_SUCCESS
    }
}
