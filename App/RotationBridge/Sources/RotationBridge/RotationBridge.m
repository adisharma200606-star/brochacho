#import "include/RotationBridge.h"

#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/graphics/IOGraphicsTypes.h>
#import <dlfcn.h>

// CGDisplayIOServicePort is still exported by ApplicationServices, but recent SDK headers no longer
// declare it (it was quietly deprecated).
extern io_service_t CGDisplayIOServicePort(CGDirectDisplayID display);

// System Settings rotates the screen through a private class, MPDisplay, in a private framework,
// MonitorPanel. Neither is in any public header, so the compiler has no idea `-initWithCGSDisplayID:` or
// `-setOrientation:` exist on anything. This category is a one-line white lie that fixes that: it tells
// the compiler "some class somewhere implements these two methods", which is all Objective-C needs to let
// us write a normal `[[cls alloc] initWithCGSDisplayID:...]` call below. At run time, since MPDisplayClass
// really is MPDisplay, the real implementation runs — nothing here overrides anything.
@interface NSObject (BrochachoMonitorPanel)
- (instancetype)initWithCGSDisplayID:(CGDirectDisplayID)displayID;
- (void)setOrientation:(NSInteger)orientation;
- (NSInteger)orientation;
@end

static void BrochachoSetError(char **outError, NSString *message) {
    if (outError != NULL) {
        const char *utf8 = message.UTF8String ?: "Unknown display rotation error";
        *outError = strdup(utf8);
    }
}

/// The modern way: ask MonitorPanel to do exactly what System Settings does.
/// Logs every step unconditionally (NSLog, visible in Console.app / `log stream`), because the first
/// version of this file failed *silently* on real hardware — no exception, no error, no rotation — and
/// that is precisely the failure mode these logs exist to catch next time.
static BOOL BrochachoTryMonitorPanel(CGDirectDisplayID displayID, int32_t degrees, char **outError) {
    static void *monitorPanelHandle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        monitorPanelHandle = dlopen("/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel",
                                    RTLD_LAZY | RTLD_LOCAL);
    });
    NSLog(@"Brochacho: [rotate] dlopen MonitorPanel -> %s", monitorPanelHandle ? "loaded" : "FAILED");
    if (monitorPanelHandle == NULL) {
        BrochachoSetError(outError, @"MonitorPanel.framework is not on this Mac");
        return NO;
    }

    Class MPDisplayClass = NSClassFromString(@"MPDisplay");
    NSLog(@"Brochacho: [rotate] MPDisplay class -> %@", MPDisplayClass ? NSStringFromClass(MPDisplayClass) : @"MISSING");
    if (MPDisplayClass == Nil) {
        BrochachoSetError(outError, @"MPDisplay is missing from MonitorPanel");
        return NO;
    }

    BOOL respondsInit = [MPDisplayClass instancesRespondToSelector:@selector(initWithCGSDisplayID:)];
    BOOL respondsSet = [MPDisplayClass instancesRespondToSelector:@selector(setOrientation:)];
    NSLog(@"Brochacho: [rotate] responds to initWithCGSDisplayID: %d, setOrientation: %d", respondsInit, respondsSet);
    if (!respondsInit || !respondsSet) {
        BrochachoSetError(outError, @"MPDisplay no longer has the methods this expects");
        return NO;
    }

    @try {
        id display = [[MPDisplayClass alloc] initWithCGSDisplayID:displayID];
        NSLog(@"Brochacho: [rotate] initWithCGSDisplayID:%u -> %@", displayID, display ? @"got an object" : @"nil");
        if (display == nil) {
            BrochachoSetError(outError, @"MPDisplay would not open this display");
            return NO;
        }
        if ([display respondsToSelector:@selector(orientation)]) {
            NSLog(@"Brochacho: [rotate] orientation before setOrientation: -> %ld", (long)[display orientation]);
        }
        NSLog(@"Brochacho: [rotate] calling setOrientation:%d", degrees);
        [display setOrientation:(NSInteger)degrees];
        NSLog(@"Brochacho: [rotate] setOrientation: returned (no exception thrown)");
        if ([display respondsToSelector:@selector(orientation)]) {
            NSLog(@"Brochacho: [rotate] orientation right after -> %ld", (long)[display orientation]);
        }
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"Brochacho: [rotate] EXCEPTION calling MPDisplay: %@ — %@", exception.name, exception.reason);
        BrochachoSetError(outError, exception.reason ?: @"MPDisplay raised an exception");
        return NO;
    }
}

/// The old way, kept for Intel Macs and anything MonitorPanel refuses: ask the framebuffer directly.
/// Apple Silicon's display pipeline usually ignores this, which is exactly why the modern path is tried first.
static BOOL BrochachoTryLegacyIOKit(CGDirectDisplayID displayID, int32_t degrees, char **outError) {
    const IOOptionBits kIOFBSetTransform = 0x00000400;
    IOOptionBits transform;
    switch (degrees) {
        case 0: transform = kIOScaleRotate0; break;
        case 90: transform = kIOScaleRotate90; break;
        case 180: transform = kIOScaleRotate180; break;
        case 270: transform = kIOScaleRotate270; break;
        default:
            BrochachoSetError(outError, @"degrees must be 0, 90, 180 or 270");
            return NO;
    }

    io_service_t service = CGDisplayIOServicePort(displayID);
    NSLog(@"Brochacho: [rotate] legacy IOKit service port -> %u", service);
    if (service == MACH_PORT_NULL) {
        BrochachoSetError(outError, @"Could not find this display's IOKit service");
        return NO;
    }

    kern_return_t result = IOServiceRequestProbe(service, kIOFBSetTransform | (transform << 16));
    NSLog(@"Brochacho: [rotate] legacy IOKit IOServiceRequestProbe -> 0x%x", result);
    if (result != KERN_SUCCESS) {
        BrochachoSetError(outError, [NSString stringWithFormat:@"IOKit refused the rotation (0x%x)", result]);
        return NO;
    }
    return YES;
}

int32_t BrochachoRotateDisplay(uint32_t displayID, int32_t degrees, char **outError) {
    NSLog(@"Brochacho: [rotate] BrochachoRotateDisplay(displayID: %u, degrees: %d)", displayID, degrees);
    if (outError != NULL) { *outError = NULL; }
    if (displayID == 0 || (degrees != 0 && degrees != 90 && degrees != 180 && degrees != 270)) {
        BrochachoSetError(outError, @"Invalid display or rotation angle");
        return 1;
    }

    char *monitorPanelError = NULL;
    BOOL monitorPanelWorked = BrochachoTryMonitorPanel(displayID, degrees, &monitorPanelError);
    NSLog(@"Brochacho: [rotate] MonitorPanel path -> %@", monitorPanelWorked ? @"reported success" : @"failed");
    if (monitorPanelWorked) {
        free(monitorPanelError);
        return 0;
    }
    NSLog(@"Brochacho: MonitorPanel could not rotate (%s); trying the legacy IOKit path",
          monitorPanelError ? monitorPanelError : "no detail");
    free(monitorPanelError);

    if (BrochachoTryLegacyIOKit(displayID, degrees, outError)) {
        return 0;
    }
    return 2;
}
