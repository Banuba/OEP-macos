#include "utils.h"

#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>

namespace bnb
{
    void runOnMainQueue(std::function<void()> f)
    {
        if ([NSThread isMainThread]) {
            f();
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
              f();
            });
        }
    }

    CVPixelBufferRef convertBGRAtoNV12(CVPixelBufferRef inputPixelBuffer, vrange range)
    {
        CVPixelBufferLockBaseAddress(inputPixelBuffer, kCVPixelBufferLock_ReadOnly);
        unsigned char* baseAddress = (unsigned char*) CVPixelBufferGetBaseAddress(inputPixelBuffer);
        auto width = CVPixelBufferGetWidth(inputPixelBuffer);
        auto height = CVPixelBufferGetHeight(inputPixelBuffer);
        auto bytesPerRow = CVPixelBufferGetBytesPerRow(inputPixelBuffer);

        NSDictionary* pixelAttributes = @{(id) kCVPixelBufferIOSurfacePropertiesKey: @{}};
        CVPixelBufferRef pixelBuffer = NULL;
        auto result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            (__bridge CFDictionaryRef)(pixelAttributes),
            &pixelBuffer);
        if (result != kCVReturnSuccess || pixelBuffer == NULL) {
            return nullptr;
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void* yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        size_t yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        size_t yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);

        void* uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        size_t uvWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        size_t uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        size_t uvBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

        vImage_Buffer sourceBufferInfo = {
            .width = static_cast<vImagePixelCount>(width),
            .height = static_cast<vImagePixelCount>(height),
            .rowBytes = bytesPerRow,
            .data = baseAddress};
        vImage_Buffer yBufferInfo = {
            .width = yWidth,
            .height = yHeight,
            .rowBytes = yBytesPerRow,
            .data = yDestPlane};
        vImage_Buffer uvBufferInfo = {
            .width = uvWidth,
            .height = uvHeight,
            .rowBytes = uvBytesPerRow,
            .data = uvDestPlane};

        const uint8_t permuteMap[4] = {3, 0, 1, 2};

        static vImage_ARGBToYpCbCr info;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
          vImage_YpCbCrPixelRange pixelRange;
          if (range == vrange::video_range) {
              pixelRange = (vImage_YpCbCrPixelRange){16, 128, 235, 240, 255, 0, 255, 1};
          } else if (range == vrange::full_range) {
              pixelRange = (vImage_YpCbCrPixelRange){0, 128, 255, 255, 255, 1, 255, 0};
          }
          vImageConvert_ARGBToYpCbCr_GenerateConversion(
              kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4,
              &pixelRange,
              &info,
              kvImageARGB8888,
              kvImage420Yp8_CbCr8,
              0);
        });

        vImageConvert_ARGB8888To420Yp8_CbCr8(
            &sourceBufferInfo,
            &yBufferInfo,
            &uvBufferInfo,
            &info,
            permuteMap,
            kvImageDoNotTile);

        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

        CVPixelBufferUnlockBaseAddress(inputPixelBuffer, kCVPixelBufferLock_ReadOnly);

        return pixelBuffer;
    }

    CVPixelBufferRef convertBGRAtoRGBA(CVPixelBufferRef inputPixelBuffer)
    {
        CVPixelBufferLockBaseAddress(inputPixelBuffer, kCVPixelBufferLock_ReadOnly);
        unsigned char* baseAddress = (unsigned char*) CVPixelBufferGetBaseAddress(inputPixelBuffer);
        auto width = CVPixelBufferGetWidth(inputPixelBuffer);
        auto height = CVPixelBufferGetHeight(inputPixelBuffer);
        auto bytesPerRow = CVPixelBufferGetBytesPerRow(inputPixelBuffer);

        NSDictionary* pixelAttributes = @{(id) kCVPixelBufferIOSurfacePropertiesKey: @{}};
        CVPixelBufferRef pixelBuffer = NULL;
        auto result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            (__bridge CFDictionaryRef)(pixelAttributes),
            &pixelBuffer);
        if (result != kCVReturnSuccess || pixelBuffer == NULL) {
            return nullptr;
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void* rgbOut = CVPixelBufferGetBaseAddress(pixelBuffer);
        size_t rgbOutWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t rgbOutHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        size_t rgbOutBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);

        vImage_Buffer sourceBufferInfo = {
            .width = static_cast<vImagePixelCount>(width),
            .height = static_cast<vImagePixelCount>(height),
            .rowBytes = bytesPerRow,
            .data = baseAddress};
        vImage_Buffer outputBufferInfo = {
            .width = rgbOutWidth,
            .height = rgbOutHeight,
            .rowBytes = rgbOutBytesPerRow,
            .data = rgbOut};

        const uint8_t permuteMap[4] = {2, 1, 0, 3}; // Convert to BGRA pixel format

        vImagePermuteChannels_ARGB8888(&sourceBufferInfo, &outputBufferInfo, permuteMap, kvImageNoFlags);

        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

        CVPixelBufferUnlockBaseAddress(inputPixelBuffer, kCVPixelBufferLock_ReadOnly);

        return pixelBuffer;
    }
} // bnb
