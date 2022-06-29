#import "BNBOffscreenEffectPlayer.h"

#import <Accelerate/Accelerate.h>
#include <interfaces/offscreen_effect_player.hpp>

#include "effect_player.hpp"
#include "offscreen_render_target.h"

@interface BNBOffscreenEffectPlayer ()

- (CVPixelBufferRef)processOutputInBGRA:(CVPixelBufferRef)inputPixelBuffer CF_RETURNS_RETAINED;
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
    
    auto me_ort = std::dynamic_pointer_cast<bnb::oep::interfaces::offscreen_render_target_metal_extension>(m_ort);
    if (me_ort == nullptr){
        throw std::runtime_error("Offscreen render target must contain METAL-specific interface!\n");
    }
    auto me_ep = std::dynamic_pointer_cast<bnb::oep::interfaces::effect_player_metal_extension>(m_ep);
    if (me_ep == nullptr){
        throw std::runtime_error("Effect player must contain METAL-specific interface!\n");
    }
    me_ep->set_render_surface(me_ort->get_layer());
    return self;
}

- (void)processImage:(CVPixelBufferRef)pixelBuffer completion:(BNBOEPImageReadyBlock _Nonnull)completion
{
    pixel_buffer_sptr pixelBuffer_sprt([self convertImage:pixelBuffer]);
    __weak auto self_weak_ = self;
    auto get_pixel_buffer_callback = [self_weak_, pixelBuffer, completion](image_processing_result_sptr result) {
        if (result != nullptr) {
            OSType pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer);
            auto render_callback = [self_weak_, pixelFormatType, completion](std::optional<rendered_texture_t> texture_id) {
                if (texture_id.has_value()) {
                    __strong auto self = self_weak_;

                    CVPixelBufferRef textureBuffer = (CVPixelBufferRef)texture_id.value();

                    // Perform conversion of texture (its type BGRA) which contains RGBA data to BGRA
                    // For demonstration the conversion to RGBA only suported similarly can be done conversions to other formats
                    CVPixelBufferRef returnedBuffer = nullptr;
                    switch (pixelFormatType) {
                        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
                        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
                        case kCVPixelFormatType_420YpCbCr8Planar:
                        case kCVPixelFormatType_420YpCbCr8PlanarFullRange:
                        case kCVPixelFormatType_32BGRA:
                            returnedBuffer = [self processOutputInBGRA:textureBuffer];
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
        callback([NSString stringWithUTF8String:result.c_str()]);
    };
    m_oep->eval_js(std::string([script UTF8String]), result_callback);
}

- (CVPixelBufferRef)processOutputInBGRA:(CVPixelBufferRef)inputPixelBuffer
{
    CVPixelBufferLockBaseAddress(inputPixelBuffer, kCVPixelBufferLock_ReadOnly);
    unsigned char* baseAddress = (unsigned char*) CVPixelBufferGetBaseAddress(inputPixelBuffer);
    auto width = CVPixelBufferGetWidth(inputPixelBuffer);
    auto height = CVPixelBufferGetHeight(inputPixelBuffer);
    auto bytesPerRow = CVPixelBufferGetBytesPerRow(inputPixelBuffer);

    NSDictionary* pixelAttributes = @{(id) kCVPixelBufferIOSurfacePropertiesKey: @{}};
    CVPixelBufferRef pixelBuffer = NULL;
    auto result = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        (__bridge CFDictionaryRef)(pixelAttributes),
        &pixelBuffer);
    NSParameterAssert(result == kCVReturnSuccess && pixelBuffer != NULL);

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void* rgbOut = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t rgbOutWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
    size_t rgbOutHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    size_t rgbOutBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);

    vImage_Buffer sourceBufferInfo = {
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = bytesPerRow,
        .data = baseAddress};
    vImage_Buffer outputBufferInfo = {
        .width = rgbOutWidth,
        .height = rgbOutHeight,
        .rowBytes = rgbOutBytesPerRow,
        .data = rgbOut};

    const uint8_t permuteMap[4] = {2, 1, 0, 3}; // Convert to BGRA pixel format

    vImagePermuteChannels_ARGB8888(&sourceBufferInfo, &outputBufferInfo, permuteMap, kvImageNoFlags);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    CVPixelBufferUnlockBaseAddress(inputPixelBuffer, kCVPixelBufferLock_ReadOnly);

    return pixelBuffer;
}

@end
