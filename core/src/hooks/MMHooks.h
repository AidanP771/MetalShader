/*
 * MMHooks.h - Installs every Metal and AppKit hook MetalMix needs.
 *
 * Purpose: one call that discovers Metal's concrete classes at runtime and
 * swizzles the methods listed in the "Metal hooking layer" section of
 * docs/architecture.md.
 *
 * Who calls it: mm_core_start, once, before the game renders.
 *
 * Threading: main thread, during dyld initialisation. Must be quick and must
 * not create long-lived Metal objects.
 */

#pragma once

/* Returns true if the hooks needed for this milestone were installed. On false
 * nothing was changed and the game runs vanilla. */
bool MMHooksInstall(void);
