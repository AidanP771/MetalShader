/*
 * main.mm - MetalMix test host: a minimal Metal app that stands in for the game.
 *
 * Purpose: give MetalMix a predictable target on the dev Mac. Each frame it
 * clears the screen, draws one spinning triangle with depth testing on, and
 * presents the drawable, which is the call MetalMix hooks first.
 *
 * Who calls it: you, via scripts/inject-testhost.sh or by opening testhost.app.
 *
 * Threading: MTKView calls drawInMTKView: on the main thread at the display's
 * refresh rate.
 */

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

// Shaders are compiled at runtime from source so the test host needs no
// separate .metallib build step.
static const char *const kShaderSource = R"(
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 color;
};

vertex VertexOut testhost_vertex(uint vertexId [[vertex_id]],
                                 constant float &timeSeconds [[buffer(0)]]) {
    const float2 corners[3] = { float2(0.0, 0.6), float2(-0.6, -0.5), float2(0.6, -0.5) };
    const float3 colors[3] = { float3(1.0, 0.35, 0.35), float3(0.35, 1.0, 0.35),
                               float3(0.35, 0.35, 1.0) };
    float s = sin(timeSeconds);
    float c = cos(timeSeconds);
    float2 p = corners[vertexId];
    VertexOut out;
    out.position = float4(p.x * c - p.y * s, p.x * s + p.y * c, 0.5, 1.0);
    out.color = colors[vertexId];
    return out;
}

fragment float4 testhost_fragment(VertexOut in [[stage_in]]) {
    return float4(in.color, 1.0);
}
)";

static const NSSize kWindowSize = {1280, 720};

// ---- Renderer -------------------------------------------------------------

@interface MMTestRenderer : NSObject <MTKViewDelegate>
- (nullable instancetype)initWithView:(MTKView *)view;
@end

@implementation MMTestRenderer {
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipeline;
    id<MTLDepthStencilState> _depthState;
    CFTimeInterval _startTime;
}

- (nullable instancetype)initWithView:(MTKView *)view {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    id<MTLDevice> device = view.device;
    _commandQueue = [device newCommandQueue];

    NSError *error = nil;
    NSString *source = [NSString stringWithUTF8String:kShaderSource];
    id<MTLLibrary> library = [device newLibraryWithSource:source options:nil error:&error];
    if (library == nil) {
        NSLog(@"testhost: shader compile failed: %@", error);
        return nil;
    }

    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.label = @"testhost scene";
    pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"testhost_vertex"];
    pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"testhost_fragment"];
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    _pipeline = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (_pipeline == nil) {
        NSLog(@"testhost: pipeline creation failed: %@", error);
        return nil;
    }

    MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthDescriptor.depthWriteEnabled = YES;
    _depthState = [device newDepthStencilStateWithDescriptor:depthDescriptor];

    _startTime = CACurrentMediaTime();
    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Nothing to resize: MTKView recreates its own depth texture.
}

- (void)drawInMTKView:(MTKView *)view {
    MTLRenderPassDescriptor *pass = view.currentRenderPassDescriptor;
    id<CAMetalDrawable> drawable = view.currentDrawable;
    if (pass == nil || drawable == nil) {
        return; // Window hidden or minimised.
    }

    float timeSeconds = (float)(CACurrentMediaTime() - _startTime);

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"testhost frame";

    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
    encoder.label = @"testhost scene pass";
    [encoder setRenderPipelineState:_pipeline];
    [encoder setDepthStencilState:_depthState];
    [encoder setVertexBytes:&timeSeconds length:sizeof timeSeconds atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];

    // The call MetalMix hooks first (milestone M1).
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

@end

// ---- App delegate ---------------------------------------------------------

@interface MMTestAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation MMTestAppDelegate {
    NSWindow *_window;
    MMTestRenderer *_renderer; // MTKView holds its delegate weakly; keep it alive here.
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) {
        NSLog(@"testhost: this Mac has no Metal device.");
        [NSApp terminate:nil];
        return;
    }

    NSRect frame = NSMakeRect(0, 0, kWindowSize.width, kWindowSize.height);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                              NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable;
    _window = [[NSWindow alloc] initWithContentRect:frame
                                          styleMask:style
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    _window.title = @"MetalMix Test Host";

    MTKView *view = [[MTKView alloc] initWithFrame:frame device:device];
    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    view.clearColor = MTLClearColorMake(0.12, 0.12, 0.16, 1.0);
    view.preferredFramesPerSecond = 60;

    _renderer = [[MMTestRenderer alloc] initWithView:view];
    if (_renderer == nil) {
        [NSApp terminate:nil];
        return;
    }
    view.delegate = _renderer;

    _window.contentView = view;
    [_window center];
    [_window makeKeyAndOrderFront:nil];
    [NSApp activate];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        app.activationPolicy = NSApplicationActivationPolicyRegular;
        MMTestAppDelegate *delegate = [MMTestAppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
