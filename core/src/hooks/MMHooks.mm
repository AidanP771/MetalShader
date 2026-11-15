/*
 * MMHooks.mm - Hook installation. See MMHooks.h and hooks/README.md.
 *
 * Status: scaffold. Hook installation is milestone M1 work; the steps are laid
 * out below so the implementation can follow them one at a time.
 */

#import "hooks/MMHooks.h"

#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

#import "MMCore.h"
#import "hooks/MMSwizzle.h"
#import "log/MMLog.h"

bool MMHooksInstall(void) {
    // M1 plan, in order. Each step logs what it found so the first in-game run
    // (M5) tells us exactly which classes the game uses on the M4.
    //
    // 1. Class discovery
    //    - id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    //    - Make a throwaway command queue and command buffer.
    //    - object_getClass() on the command buffer gives the concrete class
    //      (for example an AGX class on Apple Silicon). Log its name.
    //    - Release the throwaway objects before returning.
    //
    // 2. Present hook
    //    - MMSwizzleInstanceMethod(commandBufferClass, @selector(presentDrawable:), ...)
    //    - Also presentDrawable:atTime: and presentDrawable:afterMinimumDuration:.
    //    - The replacement calls MMCoreReportHealthyFrame(), logs a frame count
    //      every 600 frames (M1 exit criterion), then calls the original.
    //
    // 3. Debug and capture wrappers
    //    - With MTL_DEBUG_LAYER or a GPU capture active, Metal wraps command
    //      buffers in other classes. Repeat discovery with those on so both
    //      are hooked (check in the test host with MTL_DEBUG_LAYER=1).
    //
    // Later milestones add CAMetalLayer, render encoder, texture creation and
    // NSApplication sendEvent: hooks (see docs/architecture.md).

    MMLogInfo("Hook installation is not implemented yet (milestone M1). Running pass-through.");
    return true;
}
