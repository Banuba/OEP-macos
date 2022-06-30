#import "BNBOffscreenEffectPlayer.h"

#import <Accelerate/Accelerate.h>
#include <interfaces/offscreen_effect_player.hpp>

#include "effect_player.hpp"
#include "offscreen_render_target.h"

#include "utils.h"

@interface BNBOffscreenEffectPlayer ()

- (pixel_buffer_sptr)convertImage:(CVPixelBufferRef)pixelBuffer;

@end

@implementation BNBOffscreenEffectPlayer
{
    NSUInteger _width;
    NSUInteger _height;

    effect_player_sptr m_ep;
    offscreen_render_target_sptr m_ort;
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
                resourcePaths:(NSArray<NSString*>*)resourcePaths;
{
    _width = width;
    _height = height;

    std::vector<std::string> paths;
    for (id object in resourcePaths) {
        paths.push_back(std::string([(NSString*) object UTF8String]));
    }

    m_ep = bnb::oep::effect_player::create(paths, std::string([token UTF8String]));
    m_ort = std::make_shared<bnb::offscreen_render_target>();
    m_oep = bnb::oep::interfaces::offscreen_effect_player::create(m_ep, m_ort, width, height);

    auto me_ort = std::dynamic_pointer_cast<bnb::oep::interfaces::offscreen_render_target_metal_extension>(m_ort);
    if (me_ort == nullptr) {
        throw std::runtime_error("Offscreen render target must contain METAL-specific interface!\n");
    }
    auto me_ep = std::dynamic_pointer_cast<bnb::oep::interfaces::effect_player_metal_extension>(m_ep);
    if (me_ep == nullptr) {
        throw std::runtime_error("Effect player must contain METAL-specific interface!\n");
    }
    me_ep->set_render_surface(me_ort->get_layer());
    return self;
}

- (void)processImage:(CVPixelBufferRef)pixelBuffer completion:(BNBOEPImageReadyBlock _Nonnull)completion
{
    pixel_buffer_sptr pixelBuffer_sprt([self convertImage:pixelBuffer]);
    if (pixelBuffer_sprt == nullptr) {
        return;
    }

    __weak auto self_weak_ = self;
    auto get_pixel_buffer_callback = [self_weak_, pixelBuffer, completion](image_processing_result_sptr result) {
        if (result != nullptr) {
            OSType pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer);
            auto render_callback = [self_weak_, pixelFormatType, completion](std::optional<rendered_texture_t> texture_id) {
                if (texture_id.has_value()) {
                    __strong auto self = self_weak_;

                    CVPixelBufferRef textureBuffer = (CVPixelBufferRef) texture_id.value();

                    // Perform conversion of texture (its type BGRA) which contains RGBA data to the source image format
                    CVPixelBufferRef returnedBuffer = nullptr;
                    switch (pixelFormatType) {
                        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
                            returnedBuffer = bnb::convertBGRAtoNV12(textureBuffer, bnb::vrange::video_range);
                            break;
                        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
                            returnedBuffer = bnb::convertBGRAtoNV12(textureBuffer, bnb::vrange::full_range);
                            break;
                        case kCVPixelFormatType_420YpCbCr8Planar:
                            [[fallthrough]];
                        case kCVPixelFormatType_420YpCbCr8PlanarFullRange:
                            [[fallthrough]];
                        case kCVPixelFormatType_32BGRA:
                            returnedBuffer = bnb::convertBGRAtoRGBA(textureBuffer);
                            break;
                        default:
                            // Frame dropped: unsupported target pixel format.
                            break;
                    }

                    if (completion) {
                        completion(returnedBuffer);
                    }

                    CVPixelBufferRelease(textureBuffer);
                    CVPixelBufferRelease(returnedBuffer);
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
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        {
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
            auto format = pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ? bnb::oep::interfaces::image_format::nv12_bt709_full : bnb::oep::interfaces::image_format::nv12_bt709_video;
            img = ns::create(planes, bnb::oep::interfaces::image_format::nv12_bt709_full, bufferWidth, bufferHeight);
        } break;
        default:
            NSLog(@"Unsupported pixel buffer format : %d", pixelFormat);
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

- (void)surfaceChanged:(NSUInteger)width withHeight:(NSUInteger)height
{
    NSAssert(self->m_oep != nil, @"No OffscreenEffectPlayer");
    self->m_oep->surface_changed(width, height);
}

- (void)callJsMethod:(NSString* _Nonnull)method withParam:(NSString* _Nonnull)param
{
    NSAssert(self->m_oep != nil, @"No OffscreenEffectPlayer");
    m_oep->call_js_method(std::string([method UTF8String]), std::string([param UTF8String]));
}

- (void)evalJs:(NSString* _Nonnull)script resultCallback:(BNBOEPEvalJsResult _Nullable)resultCallback;
{
    NSAssert(self->m_oep != nil, @"No OffscreenEffectPlayer");
    auto result_callback = [callback=std::move(resultCallback)](const std::string& result) {
        if(callback != nullptr) {
            callback([NSString stringWithUTF8String:result.c_str()]);
        }
    };
    m_oep->eval_js(std::string([script UTF8String]), result_callback);
}

@end
