/*
 * MMSwizzle.h - The one helper every MetalMix hook uses to replace a method.
 *
 * Purpose: replace an Objective-C instance method on exactly one class, and
 * hand back the original implementation so the hook can call it.
 *
 * Why it needs care: Metal's concrete classes (found at runtime, see MMHooks.h)
 * often inherit the method we want. Replacing the inherited Method directly
 * would change it for the superclass and every sibling class too. Instead, when
 * the method is inherited, we add a copy to the target class first.
 *
 * Threading: call during hook installation, before the game renders. Swapping
 * implementations while another thread is calling the method is not safe.
 *
 * Status: written with the scaffold, first exercised in M1. Test it against
 * the test host before trusting it in the game.
 */

#pragma once

#import <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Replaces `selector` on `targetClass` with `replacement`.
 *
 * On success returns YES and stores the previous implementation in
 * `outOriginal` BEFORE the replacement is installed, so the hook can always
 * call through. Returns NO (and changes nothing) if the class does not respond
 * to the selector.
 */
BOOL MMSwizzleInstanceMethod(Class targetClass, SEL selector, IMP replacement, IMP *outOriginal);

#ifdef __cplusplus
}
#endif
