#ifndef FOCUSWELL_PRIVATE_API_H
#define FOCUSWELL_PRIVATE_API_H

#include <ApplicationServices/ApplicationServices.h>
#include <stdbool.h>

// Undocumented and subject to incompatible changes.
extern AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *out);

// Process Manager calls, deprecated since macOS 10.9 and therefore unavailable in
// Swift. They are still the only way to get a ProcessSerialNumber, which the
// SkyLight focus calls need.
bool AR_GetProcessForPID(pid_t pid, ProcessSerialNumber *psn);
bool AR_SameProcess(const ProcessSerialNumber *psn1, const ProcessSerialNumber *psn2);

// Focusing without raising relies on the private SkyLight framework, which is loaded
// at run time. AR_SkyLightAvailable returns false when either symbol is missing, the
// two calls below must not be used then.
bool AR_SkyLightAvailable(void);
CGError AR_SLPSPostEventRecordTo(ProcessSerialNumber *psn, uint8_t *bytes);
CGError AR_SLPSSetFrontProcessWithOptions(ProcessSerialNumber *psn, uint32_t wid, uint32_t mode);

#endif
