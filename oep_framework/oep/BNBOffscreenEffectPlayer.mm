#import "BNBOffscreenEffectPlayer.h"

#import <Accelerate/Accelerate.h>

#include "effect_player.hpp"
#include "offscreen_render_target.h"

#include <interfaces/camera.hpp>


@implementation BNBOffscreenEffectPlayer
{
    NSUInteger _width;
    NSUInteger _height;

    effect_player_sptr m_ep;
    offscreen_render_target_sptr m_ort;
    offscreen_effect_player_sptr m_oep;
    camera_sptr m_camera;
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
                resourcePaths:(NSArray<NSString *> *)resourcePaths
                   completion:(BNBOEPImageReadyBlock _Nonnull)screen_completion;
{
    _width = width;
    _height = height;

    std::vector<std::string> paths;
    for (id object in resourcePaths) {
        paths.push_back(std::string([(NSString*)object UTF8String]));
    }
    
    m_ep = bnb::oep::interfaces::effect_player::create(paths, std::string([token UTF8String]));
    m_ort = std::make_shared<bnb::offscreen_render_target>(width, height);
    m_oep = bnb::oep::interfaces::offscreen_effect_player::create(m_ep, m_ort, width, height);
    
    auto push_frame_cb = [self, screen_completion](pixel_buffer_sptr pixel_buffer){
        auto get_pixel_buffer_callback = [pixel_buffer, screen_completion](image_processing_result_sptr result) {
            if (result != nullptr) {
                auto render_callback = [screen_completion](std::optional<rendered_texture_t> texture_id) {
                    if (texture_id.has_value()) {
                        CVPixelBufferRef retBuffer = (CVPixelBufferRef)texture_id.value();

                        if (screen_completion) {
                            screen_completion(retBuffer);
                        }

                        CVPixelBufferRelease(retBuffer);
                    }
                };
                result->get_texture(render_callback);
            }
        };
        
        m_oep->process_image_async(pixel_buffer, bnb::oep::interfaces::rotation::deg0, get_pixel_buffer_callback, bnb::oep::interfaces::rotation::deg180);
    };
    
    m_camera = bnb::oep::interfaces::camera::create(push_frame_cb, 0);
    return self;
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
