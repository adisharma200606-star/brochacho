#import "include/RotationBridge.h"

#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/graphics/IOGraphicsTypes.h>
#import <dlfcn.h>

// CGDisplayIOServicePort is still exported by ApplicationServices at run time, but recent SDK headers no
// longer declare it (it was quietly deprecated). Declaring it ourselves lets the legacy IOKit path below
// still link.
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
@end

static void BrochachoSetError(char **outError, NSString *message) {
    if (outError != NULL) {
        const char *utf8 = message.UTF8String ?: "Unknown display rotation error";
        *outError = strdup(utf8);
    }
}

/// The modern way: ask MonitorPanel to do exactly what System Settings does.
/// Returns YES on success.
static BOOL BrochachoTryMonitorPanel(CGDirectDisplayID displayID, int32_t degrees, char **outError) {
    static void *monitorPanelHandle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        monitorPanelHandle = dlopen("/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel",
                                    RTLD_LAZY | RTLD_LOCAL);
    });
    if (monitorPanelHandle == NULL) {
        BrochachoSetError(outError, @"MonitorPanel.framework is not on this Mac");
        return NO;
    }

    Class MPDisplayClass = NSClassFromString(@"MPDisplay");
    if (MPDisplayClass == Nil) {
        BrochachoSetError(outError, @"MPDisplay is missing from MonitorPanel");
        return NO;
    }
    if (![MPDisplayClass instancesRespondToSelector:@selector(initWithCGSDisplayID:)] ||
        ![MPDisplayClass instancesRespondToSelector:@selector(setOrientation:)]) {
        BrochachoSetError(outError, @"MPDisplay no longer has the methods this expects");
        return NO;
    }

    @try {
        id display = [[MPDisplayClass alloc] initWithCGSDisplayID:displayID];
        if (display == nil) {
            BrochachoSetError(outError, @"MPDisplay would not open this display");
            return NO;
        }
        [display setOrientation:(NSInteger)degrees];
        return YES;
    } @catch (NSException *exception) {
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
    if (service == MACH_PORT_NULL) {
        BrochachoSetError(outError, @"Could not find this display's IOKit service");
        return NO;
    }

    kern_return_t result = IOServiceRequestProbe(service, kIOFBSetTransform | (transform << 16));
    if (result != KERN_SUCCESS) {
        BrochachoSetError(outError, [NSString stringWithFormat:@"IOKit refused the rotation (0x%x)", result]);
        return NO;
    }
    return YES;
}

int32_t BrochachoRotateDisplay(uint32_t displayID, int32_t degrees, char **outError) {
    if (outError != NULL) { *outError = NULL; }
    if (displayID == 0 || (degrees != 0 && degrees != 90 && degrees != 180 && degrees != 270)) {
        BrochachoSetError(outError, @"Invalid display or rotation angle");
        return 1;
    }

    char *monitorPanelError = NULL;
    if (BrochachoTryMonitorPanel(displayID, degrees, &monitorPanelError)) {
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
