// invert.metal - The first MetalMix effect: inverts the colours of the frame.
//
// Not meant to look good. It is the M2 test that the present hook can read the
// frame, run a pass and write the result back: if the screen turns into a
// negative, the pipeline works.

#include "metalmix.h"

using namespace metal;

struct MMInvertParameters {
    float strength; // 0 = untouched, 1 = fully inverted
};

fragment float4 mm_invert(MMFullscreenVertexOut in [[stage_in]],
                          texture2d<float> colorTexture [[texture(MMBindingColorTexture)]],
                          sampler linearSampler [[sampler(0)]],
                          constant MMInvertParameters &parameters [[buffer(MMBindingParameters)]]) {
    float4 color = colorTexture.sample(linearSampler, in.uv);
    color.rgb = mix(color.rgb, 1.0 - color.rgb, parameters.strength);
    return color;
}
