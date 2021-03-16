#pragma once

#include <bnb/types/full_image.hpp>

#include "pixel_buffer.hpp"

using pb_sptr = std::shared_ptr<bnb::interfaces::pixel_buffer>;

namespace bnb {

    using oep_pb_ready_cb = std::function<void(std::optional<pb_sptr>)>;

namespace interfaces
{
    struct orient_format
    {
        bnb::camera_orientation orientation;
        bool is_y_flip;
    };

    class offscreen_effect_player
    {
    public:
        virtual ~offscreen_effect_player() = default;

        /**
         * An asynchronous method for passing a frame to effect player,
         * and calling callback as a frame will be processed
         * 
         * @param image full_image_t - containing a frame for processing 
         * @param callback calling when frame will be processed, containing pointer of pixel_buffer for get bytes
         * @param target_orient 
         * 
         * Example process_image_async(image_sptr, [](pb_sptr sptr){})
         */
        virtual void process_image_async(std::shared_ptr<full_image_t> image, oep_pb_ready_cb callback,
                                         std::optional<orient_format> target_orient) = 0;

        /**
         * Notify about rendering surface being resized.
         * Must be called from the render thread.
         * 
         * @param width New width for the rendering surface
         * @param height New height for the rendering surface
         * 
         * Example surface_changed(1280, 720)
         */
        virtual void surface_changed(int32_t width, int32_t height) = 0;

        /**
         * Load and activate effect async. May be called from any thread
         * 
         * @param effect_path Path to directory of effect
         * 
         * Example load_effect("effects/test_BG")
         */
        virtual void load_effect(const std::string& effect_path) = 0;

        /**
         * Empty effect loaded. The previous effect stays in the cache.
         * 
         * Example unload_effect()
         */
        virtual void unload_effect() = 0;

        /**
         * Call js method defined in config.js file of active effect
         * 
         * @param method JS function name. Member functions are not supported.
         * @param param function arguments as JSON string.
         * 
         * Example call_js_method("just_bg", "{ "recordDuration": 15, "rotation_vector": true }")
         */
        virtual void call_js_method(const std::string& method, const std::string& param) = 0;
    };
}
} // bnb::interfaces