#pragma once

namespace bnb::oep::metal_support
{

    class offscreen_render_target
    {
    public:
        virtual ~offscreen_render_target() = default;

        /**
         * Needed for METAL only
         * Get BNBCopyableMetalLayer* used as render surface for the effect_player
         * Called by offscreen effect player.
         *
         * @return void* (BNBCopyableMetalLayer*)
         *
         * @example get_layer()
         */
        virtual void* get_layer() = 0;
    };

} /* namespace bnb::oep::metal_support */
