#pragma once

#include <vector>

namespace bnb::oep::interfaces
{
    class effect_player_metal_extension
    {
    public:
        virtual ~effect_player_metal_extension() = default;

        /**
         * Needed for METAL only
         * Set the render surface for the effect player.
         *
         * @param layer BNBCopyableMetalLayer* from offscreen_render_target
         *
         * @example set_render_surface(layer)
         */
        virtual void set_render_surface(void* layer) = 0;
    };

} /* namespace bnb::oep::interfaces */
