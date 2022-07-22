#pragma once

namespace bnb::interfaces
{
    class surface_data;
}

namespace bnb::oep::interfaces
{
    class offscreen_render_target_metal_extension
    {
    public:
        virtual ~offscreen_render_target_metal_extension() = default;

        /**
         * Needed for METAL only
         * Get BNBCopyableMetalLayer* used as render surface for the effect_player
         * Called by offscreen effect player.
         *
         * @return void* (BNBCopyableMetalLayer*)
         *
         * @example get_layer()
         */
        virtual bnb::interfaces::surface_data get_layer() = 0;
    };

} /* namespace bnb::oep::interfaces */
