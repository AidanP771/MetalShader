// metalmix.h - Shared definitions for MetalMix effects written in Metal.
//
// Every native effect (.metal) and every Mix snippet includes this. The runtime
// draws a fullscreen triangle and passes MMFullscreenVertexOut to the effect's
// fragment function, with the current frame bound as texture 0.
//
// Status: draft. The exact layout is settled in M2 (first effect) and frozen
// before M4b, when users start writing their own effects against it. After
// that, only add fields at the end.

#pragma once

#include <metal_stdlib>

// What the fullscreen vertex stage hands to an effect's fragment function.
struct MMFullscreenVertexOut {
    float4 position [[position]];
    float2 uv; // 0,0 top left to 1,1 bottom right
};

// Per-frame values every effect can read from buffer(1).
struct MMFrameUniforms {
    float2 resolution;  // drawable size in pixels
    float timeSeconds;  // since MetalMix started
    float frameSeconds; // duration of the last frame
    uint frameCount;
    float3 padding;
};

// Binding slots used by the runtime. Effects use these names, not numbers.
enum MMBinding {
    MMBindingColorTexture = 0,  // texture(0): the frame so far
    MMBindingDepthTexture = 1,  // texture(1): scene depth, once found (M7)
    MMBindingParameters = 0,    // buffer(0): the effect's own parameters
    MMBindingFrameUniforms = 1, // buffer(1): MMFrameUniforms
};
