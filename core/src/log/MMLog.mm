/*
 * MMLog.mm - The core's shared os_log handle. See MMLog.h.
 *
 * Threading: dispatch_once makes the first call safe from any thread.
 */

#import "log/MMLog.h"

#import <Foundation/Foundation.h>

#include "metalmix/mm_api.h"

os_log_t MMLogHandle(void) {
    static os_log_t handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = os_log_create(MM_LOG_SUBSYSTEM, "core");
    });
    return handle;
}
