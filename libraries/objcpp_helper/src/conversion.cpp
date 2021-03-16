#include "conversion.hpp"

#include <bnb/utils/exceptions.hpp>

#include <cmath>

using namespace bnb;

using std::unique_ptr;
using std::function;
using std::invalid_argument;

template<class OnScopeExit>
class on_scope_exit final
{
public:
    on_scope_exit(OnScopeExit on_exit)
        : m_on_exit{std::move(on_exit)}
    {
    }

    ~on_scope_exit()
    {
        m_on_exit();
    }

    on_scope_exit(const on_scope_exit&) = delete;
    on_scope_exit& operator=(const on_scope_exit&) = delete;

    on_scope_exit(on_scope_exit&&) = delete;
    on_scope_exit&& operator=(on_scope_exit&&) = delete;

private:
    OnScopeExit m_on_exit;
};

full_image_t bnb::make_full_image_from_rgb_planes(
    // clang-format off
    const image_format& image_format,
    const uint8_t* r_buffer, int32_t r_row_stride, int32_t r_pixel_stride,
    const uint8_t* g_buffer, int32_t g_row_stride, int32_t g_pixel_stride,
    const uint8_t* b_buffer, int32_t b_row_stride, int32_t b_pixel_stride
    // clang-format on
)
{
    if (r_row_stride <= 0 || g_row_stride <= 0 || b_row_stride <= 0) {
        BNB_THROW(invalid_argument, "Row stride must be positive");
    }

    if (r_pixel_stride <= 0 || g_pixel_stride <= 0 || b_pixel_stride <= 0) {
        BNB_THROW(invalid_argument, "Pixel stride must be positive");
    }

    uint32_t width = image_format.width;
    uint32_t height = image_format.height;

    auto format = bnb::bpc8_image_t::pixel_format_t::rgb;
    auto channels = 3;

    auto r_ptr = r_buffer;
    auto g_ptr = g_buffer;
    auto b_ptr = b_buffer;

    bool fastpath = (r_pixel_stride == g_pixel_stride && g_pixel_stride == b_pixel_stride && (b_pixel_stride == 3 || b_pixel_stride == 4));
    fastpath = fastpath && (r_row_stride == g_row_stride && g_row_stride == b_row_stride);
    auto base_ptr = r_ptr;
    if (fastpath) {
        if (r_ptr + 1 == g_ptr && g_ptr + 1 == b_ptr) {
            channels = r_pixel_stride;
            if (channels == 4)
                format = bnb::bpc8_image_t::pixel_format_t::rgba;
        } else if (b_ptr + 1 == g_ptr && g_ptr + 1 == r_ptr) {
            format = bnb::bpc8_image_t::pixel_format_t::bgr;
            channels = r_pixel_stride;
            if (channels == 4)
                format = bnb::bpc8_image_t::pixel_format_t::bgra;
            base_ptr = b_ptr;
        } else {
            fastpath = false;
        }
    }

    std::vector<std::uint8_t> rgb_plane(width * height * channels);
    auto rgb_ptr = rgb_plane.data();

    if (fastpath) {
        if ((unsigned) r_row_stride == width * channels) {
            memcpy(rgb_plane.data(), base_ptr, rgb_plane.size());
        } else {
            for (unsigned row = 0; row != height; ++row, base_ptr += r_row_stride, rgb_ptr += width * channels)
                memcpy(rgb_ptr, base_ptr, width * channels);
        }
    } else {
        for (unsigned row = 0; row != height; ++row, r_ptr += r_row_stride, g_ptr += g_row_stride, b_ptr += b_row_stride) {
            for (unsigned column = 0; column != width; ++column) {
                *rgb_ptr++ = r_ptr[column * r_pixel_stride];
                *rgb_ptr++ = g_ptr[column * g_pixel_stride];
                *rgb_ptr++ = b_ptr[column * b_pixel_stride];
            }
        }
    }

    return full_image_t{
        bpc8_image_t{
            bnb::color_plane_vector(std::move(rgb_plane)),
            format,
            image_format,
        }};
}

full_image_t bnb::make_full_image_from_nonplanar_bpc8_no_copy(
    const image_format& image_format,
    const bpc8_image_t::pixel_format_t pixel_format,
    uint8_t* buffer,
    int32_t row_stride,
    memory_deletter free_memory)
{
    auto channels = bpc8_image_t::bytes_per_pixel(pixel_format);

    if (image_format.width * channels == row_stride) {
        return full_image_t{
            bpc8_image_t{
                unique_ptr<uint8_t, function<void(uint8_t*)>>(
                    buffer,
                    [=](uint8_t*) { free_memory(); }),
                pixel_format,
                image_format}};
    }

     // path with copy

     auto [r, g, b] = bpc8_image_t::rgb_offsets(pixel_format);
     on_scope_exit on_exit{free_memory};

     return make_full_image_from_rgb_planes(
         // clang-format off
         image_format,
         buffer + r, row_stride, channels,
         buffer + g, row_stride, channels,
         buffer + b, row_stride, channels
         // clang-format on
     );
 }

full_image_t bnb::make_full_image_from_biplanar_yuv(
    const image_format& image_format,
    const std::vector<uint8_t>& lumo_buffer,
    int32_t lumo_row_stride,
    const std::vector<uint8_t>& chromo_buffer,
    int32_t chromo_row_stride)
{
    return make_full_image_from_biplanar_yuv(
        image_format,
        lumo_buffer.data(),
        lumo_row_stride,
        chromo_buffer.data(),
        chromo_row_stride);
}

full_image_t bnb::make_full_image_from_biplanar_yuv(
    // clang-format off
    const image_format& image_format,
    const uint8_t* restrict lumo_buffer, int32_t lumo_row_stride,
    const uint8_t* restrict chromo_buffer, int32_t chromo_row_stride
    // clang-format on
)
{
    const auto width = image_format.width;
    const auto height = image_format.height;

    std::vector<std::uint8_t> y_plane(width * height);
    std::vector<std::uint8_t> uv_plane((width / 2) * (height / 2) * 2);

    if (lumo_row_stride == width) {
        memcpy(y_plane.data(), lumo_buffer, y_plane.size());
    } else {
        auto y_ptr_dst = y_plane.data();
        for (int row = 0; row != height;
             ++row, lumo_buffer += lumo_row_stride, y_ptr_dst += width) {
            memcpy(y_ptr_dst, lumo_buffer, width);
        }
    }

    if (chromo_row_stride == width / 2 * 2) {
        memcpy(uv_plane.data(), chromo_buffer, uv_plane.size());
    } else {
        auto uv_ptr_dst = uv_plane.data();
        for (int row = 0; row != height / 2;
             ++row, chromo_buffer += chromo_row_stride, uv_ptr_dst += width / 2 * 2) {
            memcpy(uv_ptr_dst, chromo_buffer, width / 2 * 2);
        }
    }

    return full_image_t{
        yuv_image_t{
            bnb::color_plane_vector(std::move(y_plane)),
            bnb::color_plane_vector(std::move(uv_plane)),
            image_format,
        }};
}

full_image_t bnb::make_full_image_from_biplanar_yuv_no_copy(
    // clang-format off
    const image_format& image_format,
    uint8_t* restrict lumo_buffer, int32_t lumo_row_stride, memory_deletter free_lumo,
    uint8_t* restrict chromo_buffer, int32_t chromo_row_stride, memory_deletter free_chromo
    // clang-format on
)
{
    if (lumo_row_stride == image_format.width && chromo_row_stride == image_format.width) {
        return full_image_t{
            yuv_image_t{
                bnb::color_plane(lumo_buffer, [free_lumo](bnb::color_plane_data_t*) {
                    free_lumo();
                }),
                bnb::color_plane(chromo_buffer, [free_chromo](bnb::color_plane_data_t*) {
                    free_chromo();
                }),
                image_format}};
    } else {
        auto result = bnb::make_full_image_from_biplanar_yuv(
            // clang-format off
            image_format,
            lumo_buffer, lumo_row_stride,
            chromo_buffer, chromo_row_stride
            // clang-format on
        );
        free_lumo();
        free_chromo();
        return result;
    }
}