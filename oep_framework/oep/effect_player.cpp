#include "effect_player.hpp"

#include <iostream>
#include <thread>
#include <optional>
#include <iostream>

namespace bnb::oep
{

    class js_callback : public bnb::interfaces::js_callback
    {
    public:
        js_callback(oep_eval_js_result_cb callback)
            : m_callback(std::move(callback)){};

        void on_result(const std::string& result) override
        {
            m_callback(result);
        }

    private:
        oep_eval_js_result_cb m_callback;
    }; /* class js_callback */

} /* namespace bnb::oep */

namespace bnb::oep
{
    effect_player_sptr interfaces::effect_player::create(int32_t width, int32_t height)
    {
        return std::make_shared<bnb::oep::effect_player>(width, height);
    }

    effect_player::effect_player(int32_t width, int32_t height)
        : m_ep(bnb::interfaces::effect_player::create(bnb::interfaces::effect_player_configuration::create(
            width, // fx_width - the effect's framebuffer width
            height // fx_height - the effect's framebuffer height
            )))
    {
    }

    effect_player::~effect_player()
    {
    }

    void effect_player::surface_created(int32_t width, int32_t height)
    {
        m_ep->surface_created(width, height);
        surface_changed(width, height);
    }

    void effect_player::surface_changed(int32_t width, int32_t height)
    {
        m_ep->surface_changed(width, height);
        if (auto em = m_ep->effect_manager()) {
            em->set_effect_size(width, height);
        }
    }

    void effect_player::surface_destroyed()
    {
        m_ep->surface_destroyed();
    }

    bool effect_player::load_effect(const std::string& effect)
    {
        if (auto effect_manager = m_ep->effect_manager()) {
            effect_manager->load(effect);
            return true;
        }
        return false;
    }

    bool effect_player::call_js_method(const std::string& method, const std::string& param)
    {
        if (auto e_manager = m_ep->effect_manager()) {
            if (auto effect = e_manager->current()) {
                effect->call_js_method(method, param);
            } else {
                std::cout << "[Error] effect not loaded" << std::endl;
                return false;
            }
        } else {
            std::cout << "[Error] effect manager not initialized" << std::endl;
            return false;
        }
        return true;
    }

    /* effect_player::eval_js */
    void effect_player::eval_js(const std::string& script, oep_eval_js_result_cb result_callback)
    {
        if (auto e_manager = m_ep->effect_manager()) {
            if (auto effect = e_manager->current()) {
                std::shared_ptr<bnb::oep::js_callback> callback
                    = result_callback ? std::make_shared<bnb::oep::js_callback>(std::move(result_callback)) : nullptr;
                effect->eval_js(script, callback);
            } else {
                std::cout << "[Error] effect not loaded" << std::endl;
            }
        } else {
            std::cout << "[Error] effect manager not initialized" << std::endl;
        }
    }

    void effect_player::pause()
    {
        m_ep->playback_pause();
    }

    void effect_player::resume()
    {
        m_ep->playback_play();
    }

    void effect_player::stop()
    {
        m_ep->playback_stop();
    }

    void effect_player::push_frame(pixel_buffer_sptr image, bnb::oep::interfaces::rotation image_orientation, bool require_mirroring)
    {
        using ns = bnb::oep::interfaces::image_format;
        auto bnb_image_format = make_bnb_image_format(image, image_orientation, require_mirroring);
        switch (image->get_image_format()) {
            case ns::bpc8_rgb:
            case ns::bpc8_bgr:
            case ns::bpc8_rgba:
            case ns::bpc8_bgra:
            case ns::bpc8_argb:
                m_ep->push_frame(
                    full_image_t(bpc8_image_t(
                        color_plane(image->get_base_sptr()),
                        make_bnb_pixel_format(image),
                        bnb_image_format)));
                break;
            case ns::nv12_bt601_full:
            case ns::nv12_bt601_video:
            case ns::nv12_bt709_full:
            case ns::nv12_bt709_video:
                m_ep->push_frame(
                    full_image_t(yuv_image_t(
                        color_plane(image->get_base_sptr_of_plane(0)),
                        color_plane(image->get_base_sptr_of_plane(1)),
                        bnb_image_format,
                        make_bnb_yuv_format(image))));
                break;
            case ns::i420_bt601_full:
            case ns::i420_bt601_video:
            case ns::i420_bt709_full:
            case ns::i420_bt709_video:
                m_ep->push_frame(
                    full_image_t(yuv_image_t(
                        color_plane(image->get_base_sptr_of_plane(0)),
                        color_plane(image->get_base_sptr_of_plane(1)),
                        color_plane(image->get_base_sptr_of_plane(2)),
                        bnb_image_format,
                        make_bnb_yuv_format(image))));
                break;
            default:
                break;
        }
    }

    int64_t effect_player::draw()
    {
        return m_ep->draw();
    }

    void effect_player::set_render_surface(const bnb::interfaces::surface_data& data)
    {
        if (auto effect_manager = m_ep->effect_manager()) {
            effect_manager->set_render_surface(data);
        }
    }

    void effect_player::disable_surface_presentation()
    {
        if (auto effect_manager = m_ep->effect_manager()) {
            effect_manager->disable_surface_presentation();
        }
    }

    bnb::image_format effect_player::make_bnb_image_format(pixel_buffer_sptr image, interfaces::rotation orientation, bool require_mirroring)
    {
        bnb::camera_orientation camera_orient {bnb::camera_orientation::deg_0};

        using ns = bnb::oep::interfaces::rotation;
        switch (orientation) {
            case ns::deg0:
                break;
            case ns::deg90:
                camera_orient = bnb::camera_orientation::deg_90;
                break;
            case ns::deg180:
                camera_orient = bnb::camera_orientation::deg_180;
                break;
                break;
            case ns::deg270:
                camera_orient = bnb::camera_orientation::deg_270;
                break;
        }

        return {static_cast<uint32_t>(image->get_width()), static_cast<uint32_t>(image->get_height()), camera_orient, require_mirroring, 0, std::nullopt};
    }

    bnb::yuv_format_t effect_player::make_bnb_yuv_format(pixel_buffer_sptr image)
    {
        bnb::yuv_format format{bnb::yuv_format::yuv_nv12}; /* i.e. NV12 or I420 */
        bnb::color_std standard{bnb::color_std::bt601};    /* i.e. BT.601 or BT.709 */
        bnb::color_range range{bnb::color_range::full};    /* i.e. "full" or "video" */

        using ns = bnb::oep::interfaces::image_format;
        switch (image->get_image_format()) {
            case ns::nv12_bt601_full:
                break;
            case ns::nv12_bt601_video:
                range = bnb::color_range::video;
                break;
            case ns::nv12_bt709_full:
                standard = bnb::color_std::bt709;
                break;
            case ns::nv12_bt709_video:
                range = bnb::color_range::video;
                standard = bnb::color_std::bt709;
                break;
            case ns::i420_bt601_full:
                format = bnb::yuv_format::yuv_i420;
                break;
            case ns::i420_bt601_video:
                range = bnb::color_range::video;
                format = bnb::yuv_format::yuv_i420;
                break;
            case ns::i420_bt709_full:
                format = bnb::yuv_format::yuv_i420;
                standard = bnb::color_std::bt709;
                break;
            case ns::i420_bt709_video:
                range = bnb::color_range::video;
                format = bnb::yuv_format::yuv_i420;
                standard = bnb::color_std::bt709;
                break;
            default:
                break;
        }

        return {range, standard, format};
    }

    bnb::interfaces::pixel_format effect_player::make_bnb_pixel_format(pixel_buffer_sptr image)
    {
        bnb::interfaces::pixel_format fmt{bnb::interfaces::pixel_format::rgb};

        using ns = bnb::oep::interfaces::image_format;
        switch (image->get_image_format()) {
            case ns::bpc8_rgb:
                break;
            case ns::bpc8_bgr:
                fmt = bnb::interfaces::pixel_format::bgr;
                break;
            case ns::bpc8_rgba:
                fmt = bnb::interfaces::pixel_format::rgba;
                break;
            case ns::bpc8_bgra:
                fmt = bnb::interfaces::pixel_format::bgra;
                break;
            case ns::bpc8_argb:
                fmt = bnb::interfaces::pixel_format::argb;
                break;
            default:
                break;
        }
        return fmt;
    }

} /* namespace bnb::oep */
