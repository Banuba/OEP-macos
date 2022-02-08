#import "BNBOffscreenEffectPlayer.h"

#import <Accelerate/Accelerate.h>
#include <interfaces/offscreen_effect_player.hpp>

#include "effect_player.hpp"
#include "offscreen_render_target.h"

@implementation BNBOffscreenEffectPlayer
{
    NSUInteger _width;
    NSUInteger _height;
    macos_effect_player_sptr m_ep;
    std::shared_ptr<bnb::offscreen_render_target> m_ort;
    offscreen_effect_player_sptr m_oep;
}

- (id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class BNBOffscreenEffectPlayer"
                                 userInfo:nil];
}

- (instancetype)initWithWidth:(NSUInteger)width
                       height:(NSUInteger)height
                  manualAudio:(BOOL)manual
                        token:(NSString*)token
                resourcePaths:(NSArray<NSString *> *)resourcePaths;
{
    _width = width;
    _height = height;

    std::vector<std::string> paths;
    for (id object in resourcePaths) {
        paths.push_back(std::string([(NSString*)object UTF8String]));
    }
    
    m_ep = bnb::oep::effect_player::create(paths, std::string([token UTF8String]));
    m_ort = std::make_shared<bnb::offscreen_render_target>();
    m_oep = bnb::oep::interfaces::offscreen_effect_player::create(m_ep, m_ort, width, height);
    return self;
}

- (void)processImage:(CVPixelBufferRef)pixelBuffer completion:(BNBOEPImageReadyBlock _Nonnull)completion
{
    pixel_buffer_sptr pixelBuffer_sprt([self convertImage:pixelBuffer]);
    auto get_pixel_buffer_callback = [pixelBuffer, completion](image_processing_result_sptr result) {
        if (result != nullptr) {
            auto render_callback = [completion](std::optional<rendered_texture_t> texture_id) {
                if (texture_id.has_value()) {
                    CVPixelBufferRef retBuffer = (CVPixelBufferRef)texture_id.value();

                    if (completion) {
                        completion(retBuffer);
                    }

                    CVPixelBufferRelease(retBuffer);
                }
            };
            result->get_texture(render_callback);
        }
    };
    
    m_oep->process_image_async(pixelBuffer_sprt, bnb::oep::interfaces::rotation::deg0, get_pixel_buffer_callback, bnb::oep::interfaces::rotation::deg180);
}

- (pixel_buffer_sptr)convertImage:(CVPixelBufferRef)pixelBuffer
{
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    pixel_buffer_sptr img;

    switch (pixelFormat) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: {
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            uint8_t* lumo = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
            uint8_t* chromo = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
            int bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
            int bufferHeight = CVPixelBufferGetHeight(pixelBuffer);

            // Retain twice. Each plane will release once.
            CVPixelBufferRetain(pixelBuffer);
            CVPixelBufferRetain(pixelBuffer);

            using ns = bnb::oep::interfaces::pixel_buffer;
            ns::plane_data y_plane{std::shared_ptr<uint8_t>(lumo, [pixelBuffer](uint8_t*) {
                                       CVPixelBufferRelease(pixelBuffer);
                                   }),
                                   0,
                                   static_cast<int32_t>(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0))};
            ns::plane_data uv_plane{std::shared_ptr<uint8_t>(chromo, [pixelBuffer](uint8_t*) {
                                        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
                                        CVPixelBufferRelease(pixelBuffer);
                                    }),
                                    0,
                                    static_cast<int32_t>(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0))};

            std::vector<ns::plane_data> planes{y_plane, uv_plane};
            img = ns::create(planes, bnb::oep::interfaces::image_format::nv12_bt709_full, bufferWidth, bufferHeight);
        } break;
        default:
            NSLog(@"ERROR TYPE : %d", pixelFormat);
            return nil;
    }
        return std::move(img);
}

- (void)loadEffect:(NSString* _Nonnull)effectName
{
    NSAssert(self->m_oep != nil, @"No OffscreenEffectPlayer");
    m_oep->load_effect(std::string([effectName UTF8String]));
}

- (void)unloadEffect
{
    NSAssert(self->m_oep != nil, @"No OffscreenEffectPlayer");
    m_oep->unload_effect();
}

- (void)callJsMethod:(NSString* _Nonnull)method withParam:(NSString* _Nonnull)param
{
    NSAssert(self->m_oep != nil, @"No OffscreenEffectPlayer");
    m_oep->call_js_method(std::string([method UTF8String]), std::string([param UTF8String]));
}

@end
