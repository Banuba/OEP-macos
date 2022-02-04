#pragma once

#include <interfaces/effect_player.hpp>
#include <bnb/effect_player/interfaces/all.hpp>
#include <bnb/effect_player/utility.hpp>

#include "interfaces/offscreen_effect_player.hpp"

namespace bnb::oep
{
    class effect_player;
}

using macos_effect_player_sptr = std::shared_ptr<bnb::oep::effect_player>;

namespace bnb::oep
{

    class effect_player : public bnb::oep::interfaces::effect_player
    {
    public:
        effect_player(const std::vector<std::string>& path_to_resources, const std::string& client_token);

        ~effect_player();

        static macos_effect_player_sptr create(const std::vector<std::string>& path_to_resources, const std::string& client_token);

        void surface_created(int32_t width, int32_t height) override;

        void surface_changed(int32_t width, int32_t height) override;

        void surface_destroyed() override;

        bool load_effect(const std::string& effect) override;

        bool call_js_method(const std::string& method, const std::string& param) override;

        void pause() override;

        void resume() override;

        void push_frame(pixel_buffer_sptr image, bnb::oep::interfaces::rotation image_orientation) override;

        void draw() override;
        
        void set_render_surface(void* layer);

    private:
        bnb::image_format make_bnb_image_format(pixel_buffer_sptr image, interfaces::rotation orientation);
        bnb::yuv_format_t make_bnb_yuv_format(pixel_buffer_sptr image);
        bnb::interfaces::pixel_format make_bnb_pixel_format(pixel_buffer_sptr image);

    private:
        bnb::utility m_utility;
        std::shared_ptr<bnb::interfaces::effect_player> m_ep;
        std::atomic_bool m_is_surface_created {false};
    }; /* class effect_player */

} /* namespace bnb::oep */
