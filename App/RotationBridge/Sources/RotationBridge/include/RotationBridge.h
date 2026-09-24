#ifndef BROCHACHO_ROTATION_BRIDGE_H
#define BROCHACHO_ROTATION_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Rotates a display to 0, 90, 180 or 270 degrees, using the same private macOS API System Settings uses.
/// Returns 0 on success.
/// On failure, and only if outError is not NULL, *outError is set to a short, human-readable, malloc'd
/// C string describing what went wrong — the caller must free() it.
int32_t BrochachoRotateDisplay(uint32_t displayID, int32_t degrees, char **outError);

#ifdef __cplusplus
}
#endif

#endif
