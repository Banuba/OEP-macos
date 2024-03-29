#pragma once

#include <interfaces/effect_player.hpp>
#include <bnb/effect_player/interfaces/all.hpp>
#include <bnb/effect_player/utility.hpp>

#include "interfaces/effect_player_metal_extension.hpp"

namespace bnb::oep
{
    class effect_player;
}

namespace bnb::oep
{
    class effect_player : public bnb::oep::interfaces::effect_player, public bnb::oep::interfaces::effect_player_metal_extension
    {
    public:
        effect_player(int32_t width, int32_t height);

        ~effect_player();

        void surface_created(int32_t width, int32_t height) override;

        void surface_changed(int32_t width, int32_t height) override;

        void surface_destroyed() override;

        bool load_effect(const std::string& effect) override;

        bool call_js_method(const std::string& method, const std::string& param) override;
        
        void eval_js(const std::string& script, oep_eval_js_result_cb result_callback) override;

        void pause() override;

        void resume() override;

        void stop() override;

        void push_frame(pixel_buffer_sptr image, bnb::oep::interfaces::rotation image_orientation, bool require_mirroring) override;

        int64_t draw() override;

        void set_render_surface(const bnb::interfaces::surface_data& data) override;

        void disable_surface_presentation() override;

    private:
        bnb::image_format make_bnb_image_format(pixel_buffer_sptr image, interfaces::rotation orientation, bool require_mirroring);
        bnb::yuv_format_t make_bnb_yuv_format(pixel_buffer_sptr image);
        bnb::interfaces::pixel_format make_bnb_pixel_format(pixel_buffer_sptr image);

    private:
        std::shared_ptr<bnb::interfaces::effect_player> m_ep;
        std::atomic_bool m_is_surface_created{false};
    }; /* class effect_player */

} /* namespace bnb::oep */
