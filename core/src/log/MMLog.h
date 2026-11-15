/*
 * MMLog.h - Logging for the core.
 *
 * Purpose: one place for MetalMix log output, so every message lands under the
 * same os_log subsystem as the loader (MM_LOG_SUBSYSTEM, category "core").
 *
 * Use it like os_log: the format must be a string literal, and strings that
 * should be readable in Console need %{public}s (or %{public}@ for objects).
 *
 *   MMLogInfo("Loaded %{public}s in %.1f ms", name, milliseconds);
 *
 * Watch live:  log stream --predicate 'subsystem == "io.metalmix"' --level debug
 *
 * Threading: safe from any thread, including the render thread.
 *
 * Planned (M3): mirror messages to a rolling file in ~/Library/Logs/MetalMix/
 * so mm-report.command can collect them.
 */

#pragma once

#include <os/log.h>

#ifdef __cplusplus
extern "C" {
#endif

/* The shared log handle for the core. Created on first use. */
os_log_t MMLogHandle(void);

#ifdef __cplusplus
}
#endif

#define MMLogDebug(format, ...) os_log_debug(MMLogHandle(), format, ##__VA_ARGS__)
#define MMLogInfo(format, ...) os_log(MMLogHandle(), format, ##__VA_ARGS__)
#define MMLogError(format, ...) os_log_error(MMLogHandle(), format, ##__VA_ARGS__)
