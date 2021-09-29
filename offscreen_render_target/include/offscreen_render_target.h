#pragma once

#include <bnb/types/base_types.hpp>

#include "interfaces/offscreen_render_target.hpp"

//#include "program.hpp"

//#include <glad/glad.h>

typedef NS_ENUM(NSUInteger, EPOrientation) {
    EPOrientationAngles0,
    EPOrientationAngles90,
    EPOrientationAngles180,
    EPOrientationAngles270
};

namespace bnb
{

    class offscreen_renderer : public interfaces::offscreen_render_target
    {
    public:
        offscreen_renderer(size_t width, size_t height);

        ~offscreen_renderer();
        void cleanup_render_buffers();
        void surface_changed(int32_t width, int32_t height) override;
        void setup_offscreen_pixel_buffer(EPOrientation orientation);
        std::tuple<int, int> getWidthHeight(EPOrientation orientation);
        void setup_offscreen_render_target(EPOrientation orientation);
        void activate_metal(BNBCopyableMetalLayer* metalLayer);
        void flush_metal();
        bnb::camera_orientation get_camera_orientation(EPOrientation orientation);
        void draw(EPOrientation orientation);
        CVPixelBufferRef get_oriented_image(EPOrientation orientation);
        
        void init() override;
        void activate_context(BNBCopyableMetalLayer* layer) override;
        void prepare_rendering() override;
        void orient_image(interfaces::orient_format orient) override;
        void* get_image(interfaces::image_format format) override;
        bnb::data_t read_current_buffer() override;
        
    private:
        size_t m_width;
        size_t m_height;
        int m_prev_orientation = -1;
        id<MTLCommandQueue> m_command_queue;
        id<MTLBuffer> m_uniformBuffer;
        BNBCopyableMetalLayer* effectPlayerLayer;
        id<MTLBuffer> m_vertexBuffer;
        id<MTLBuffer> m_indicesBuffer;
        CVMetalTextureRef texture;
        id<MTLBuffer> m_framebuffer{0};
        id<MTLBuffer> m_postProcessingFramebuffer{0};
        MTLPixelFormat m_pixelFormat = MTLPixelFormatRGBA8Unorm;
        CVPixelBufferRef m_offscreenRenderPixelBuffer{nullptr};
        CVMetalTextureRef m_offscreenRenderTexture{nullptr};
        id<MTLTexture> m_offscreenRenderMetalTexture;
    };
} // bnb
