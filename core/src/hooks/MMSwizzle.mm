/*
 * MMSwizzle.mm - See MMSwizzle.h for why this exists and how to use it.
 */

#import "hooks/MMSwizzle.h"

#import "log/MMLog.h"

BOOL MMSwizzleInstanceMethod(Class targetClass, SEL selector, IMP replacement, IMP *outOriginal) {
    if (targetClass == Nil || selector == NULL || replacement == NULL || outOriginal == NULL) {
        MMLogError("MMSwizzleInstanceMethod was called with a missing argument.");
        return NO;
    }

    // class_getInstanceMethod also finds methods the class inherits.
    Method method = class_getInstanceMethod(targetClass, selector);
    if (method == NULL) {
        MMLogError("%{public}s does not respond to %{public}s; hook not installed.",
                   class_getName(targetClass), sel_getName(selector));
        return NO;
    }

    // Publish the original first, so a call that races with installation can
    // still reach it.
    *outOriginal = method_getImplementation(method);

    // If the method is inherited, class_addMethod succeeds and gives targetClass
    // its own copy pointing at our replacement; the superclass is untouched and
    // the original IMP above is the inherited one, which is what we must call.
    // If targetClass already defines the method itself, class_addMethod fails
    // and we swap the implementation on that class's own Method.
    if (!class_addMethod(targetClass, selector, replacement, method_getTypeEncoding(method))) {
        *outOriginal = method_setImplementation(method, replacement);
    }

    MMLogDebug("Hooked -[%{public}s %{public}s]", class_getName(targetClass),
               sel_getName(selector));
    return YES;
}
