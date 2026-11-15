/*
 * MMCore.h - Core-wide state and services that every subsystem can use.
 *
 * Purpose: give subsystems the paths the loader resolved and a way to report
 * frame health, without each one reaching into mm_core.mm.
 *
 * Threading: all functions are safe to call from any thread. The getters return
 * values that are fixed after mm_core_start returns.
 */

#pragma once

#include <string>

namespace mm {

/* ~/Library/Application Support/MetalMix */
const std::string &SupportDirectory();

/* True when the loader that started this core is a Dev build. */
bool IsDevBuild();

} // namespace mm

/* Call once per successfully presented frame (from the present hook). After
 * kCrashGuardHealthyFrames it deletes the loader's crash marker, on a
 * background queue. Cheap enough for the render thread: one atomic add. */
void MMCoreReportHealthyFrame(void);
