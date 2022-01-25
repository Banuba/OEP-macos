#pragma once

//#include <bnb/types/base_types.hpp>

#include <interfaces/offscreen_render_target.hpp>
#import <CoreMedia/CoreMedia.h>

namespace bnb
{
    enum EPOrientation{
        EPOrientationAngles0,
        EPOrientationAngles90,
        EPOrientationAngles180,
        EPOrientationAngles270
    };

    class offscreen_render_target : public bnb::oep::interfaces::offscreen_render_target
    {
    public:
        offscreen_render_target(size_t width, size_t height);

        ~offscreen_render_target();
        void cleanup_render_buffers();
        void setup_offscreen_pixel_buffer(EPOrientation orientation);
        std::tuple<int, int> getWidthHeight(EPOrientation orientation);
        void setup_offscreen_render_target(EPOrientation orientation);
        void activate_metal();
        void flush_metal();
        bnb::camera_orientation get_camera_orientation(EPOrientation orientation);
        void draw(EPOrientation orientation);
        CVPixelBufferRef get_oriented_image(EPOrientation orientation);
        
        void init(int32_t width, int32_t height) override;
        void deinit() override;
        void surface_changed(int32_t width, int32_t height) override;
        void activate_context() override;
        void deactivate_context() override;
        void prepare_rendering() override;
        void orient_image(bnb::oep::interfaces::rotation orient) override;
        pixel_buffer_sptr read_current_buffer(bnb::oep::interfaces::image_format format) override;
        rendered_texture_t get_current_buffer_texture() override;
        
//        void* get_image() override;
//        bnb::data_t read_current_buffer() override;
//        void* get_layer() override;
        
    private:
        struct impl;
        std::unique_ptr<impl> m_impl;
    };
} // bnb
