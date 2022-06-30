#include <functional>

#import <Accelerate/Accelerate.h>

namespace bnb
{
    enum class vrange
    {
        video_range,
        full_range
    };

    void runOnMainQueue(std::function<void()> f);

    CVPixelBufferRef convertBGRAtoNV12(CVPixelBufferRef inputPixelBuffer, vrange range);
    CVPixelBufferRef convertBGRAtoRGBA(CVPixelBufferRef inputPixelBuffer);
} // namespace bnb
