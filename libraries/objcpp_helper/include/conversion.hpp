#pragma once

#include <bnb/types/full_image.hpp>
#include <functional>

#define restrict __restrict

namespace bnb
{
    using memory_deletter = std::function<void()>;

    full_image_t make_full_image_from_rgb_planes(
        // clang-format off
        const image_format& image_format,
        const uint8_t* r_buffer, int32_t r_row_stride, int32_t r_pixel_stride,
        const uint8_t* g_buffer, int32_t g_row_stride, int32_t g_pixel_stride,
        const uint8_t* b_buffer, int32_t b_row_stride, int32_t b_pixel_stride
        // clang-format on
    );

    full_image_t make_full_image_from_nonplanar_bpc8_no_copy(
        const image_format& image_format,
        const bpc8_image_t::pixel_format_t pixel_format,
        uint8_t* buffer,
        int32_t row_stride,
        memory_deletter free_memory);

    full_image_t make_full_image_from_biplanar_yuv(
        // clang-format off
       const image_format& image_format,
       const std::vector<uint8_t>& lumo_buffer, int32_t lumo_row_stride,
       const std::vector<uint8_t>& chromo_buffer, int32_t chromo_row_stride
        // clang-format on
    );

    full_image_t make_full_image_from_biplanar_yuv(
        // clang-format off
        const image_format& image_format,
        const uint8_t* restrict lumo_buffer, int32_t lumo_row_stride,
        const uint8_t* restrict chromo_buffer, int32_t chromo_row_stride
        // clang-format on
    );

    full_image_t make_full_image_from_biplanar_yuv_no_copy(
        // clang-format off
        const image_format& image_format,
        uint8_t* restrict lumo_buffer, int32_t lumo_row_stride, memory_deletter free_lumo,
        uint8_t* restrict chromo_buffer, int32_t chromo_row_stride, memory_deletter free_chromo
        // clang-format on
    );

} // bnb
