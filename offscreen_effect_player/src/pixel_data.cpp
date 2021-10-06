#include "pixel_data.hpp"

#include <bnb/types/full_image.hpp>

#include <iostream>

namespace bnb
{
    pixel_data::pixel_data(oep_sptr oep_sptr, uint32_t width, uint32_t height, camera_orientation orientation)
        : m_oep_ptr(oep_sptr)
        , m_width(width)
        , m_height(height)
        , m_orientation(orientation) {}

    void pixel_data::lock()
    {
        ++lock_count;
    }

    void pixel_data::unlock()
    {
        if (lock_count > 0) {
            --lock_count;
            return;
        }

        throw std::runtime_error("pixel_data already unlocked");
    }

    bool pixel_data::is_locked()
    {
        if (lock_count == 0) {
            return false;
        }
        return true;
    }

    void pixel_data::get_image(oep_image_ready_pb_cb callback)
    {
        if (!is_locked()) {
            std::cout << "[WARNING] The pixel buffer must be locked" << std::endl;
            callback(nullptr);
            return;
        }

        if (auto oep_sp = m_oep_ptr.lock()) {
            oep_sp->read_pixel_buffer(callback);
        }
        else {
            std::cout << "[ERROR] Offscreen effect player destroyed" << std::endl;
        }
    }
} // bnb
