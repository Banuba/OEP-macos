#pragma once
#include <bnb/types/full_image.hpp>

@class BNBFullImageData;

namespace bnb::objcpp
{
    class full_image_data
    {
    public:
        using CppType = ::bnb::full_image_t;
        using CppOptType = ::bnb::full_image_t;
        using ObjcType = BNBFullImageData*;

        using Boxed = full_image_data;

        static CppType toCpp(ObjcType objc);
        static ObjcType fromCppOpt(const CppOptType& cpp);
        static ObjcType fromCpp(const CppType& cpp)
        {
            return fromCppOpt(cpp);
        }

    private:
        class ObjcProxy;
    };

} // bnb::objcpp
