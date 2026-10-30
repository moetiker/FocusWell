#include "PrivateAPI.h"
#include <dlfcn.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

bool AR_GetProcessForPID(pid_t pid, ProcessSerialNumber *psn) {
    return GetProcessForPID(pid, psn) == noErr;
}

bool AR_SameProcess(const ProcessSerialNumber *psn1, const ProcessSerialNumber *psn2) {
    Boolean same = false;
    SameProcess(psn1, psn2, &same);
    return same;
}

#pragma clang diagnostic pop

typedef CGError (*PostEventRecordToFn)(ProcessSerialNumber *, uint8_t *);
typedef CGError (*SetFrontProcessWithOptionsFn)(ProcessSerialNumber *, uint32_t, uint32_t);
static PostEventRecordToFn postEventRecordTo = NULL;
static SetFrontProcessWithOptionsFn setFrontProcessWithOptions = NULL;

bool AR_SkyLightAvailable(void) {
    static bool loaded = false;
    if (!loaded) {
        loaded = true;
        void *skylight = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
        if (skylight) {
            postEventRecordTo = (PostEventRecordToFn) dlsym(skylight, "SLPSPostEventRecordTo");
            setFrontProcessWithOptions = (SetFrontProcessWithOptionsFn)
                dlsym(skylight, "_SLPSSetFrontProcessWithOptions");
        }
    }
    return postEventRecordTo && setFrontProcessWithOptions;
}

CGError AR_SLPSPostEventRecordTo(ProcessSerialNumber *psn, uint8_t *bytes) {
    return postEventRecordTo(psn, bytes);
}

CGError AR_SLPSSetFrontProcessWithOptions(ProcessSerialNumber *psn, uint32_t wid, uint32_t mode) {
    return setFrontProcessWithOptions(psn, wid, mode);
}
