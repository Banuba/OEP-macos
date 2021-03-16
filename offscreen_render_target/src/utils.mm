#import <Accelerate/Accelerate.h>
#import <Cocoa/Cocoa.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <OpenGL/gl.h>
#import <QuartzCore/QuartzCore.h>

#include <functional>

void run_main_loop()
{
    int argc = 0;
    const char *argv[]{};
    NSApplicationMain(argc, argv);
}

void run_on_main_queue(std::function<void()> f)
{
    if ([NSThread isMainThread])
    {
        f();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), ^{
            f(); 
        });
    }
}

void* ns_GL_get_proc_address(const char *name)
{
    NSSymbol symbol;
    char *symbolName;
    symbolName = (char*)malloc (strlen (name) + 2);
    strcpy(symbolName + 1, name);
    symbolName[0] = '_';
    symbol = NULL;
    if (NSIsSymbolNameDefined (symbolName)) {
        symbol = NSLookupAndBindSymbol (symbolName);
    }
    free (symbolName);
    return symbol ? NSAddressOfSymbol (symbol) : NULL;
}

enum class vrange
{
    video_range,
    full_range
};

CVPixelBufferRef convert_rgba_to_nv12(CVPixelBufferRef inputPixelBuffer, vrange range)
{
    CVPixelBufferLockBaseAddress(inputPixelBuffer, kCVPixelBufferLock_ReadOnly);
    unsigned char* baseAddress = (unsigned char*) CVPixelBufferGetBaseAddress(inputPixelBuffer);
    auto width = CVPixelBufferGetWidth(inputPixelBuffer);
    auto height = CVPixelBufferGetHeight(inputPixelBuffer);
    auto bytesPerRow = CVPixelBufferGetBytesPerRow(inputPixelBuffer);

    NSDictionary* pixelAttributes = @{(id) kCVPixelBufferIOSurfacePropertiesKey: @{}};
    CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        (__bridge CFDictionaryRef)(pixelAttributes),
        &pixelBuffer);

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

void* get_pixel_buffer_native(int width, int height)
{
    CVPixelBufferRef pixel_buffer = NULL;

    NSDictionary* cvBufferProperties = @{
        (__bridge NSString*)kCVPixelBufferOpenGLCompatibilityKey : @YES,
    };

    CVReturn err = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        // We get data from oep in RGBA, macos defined kCVPixelFormatType_32RGBA but not supported
        // and we have to choose a different type. This does not in any way affect further
        // processing, inside bytes still remain in the order of the RGBA.
        kCVPixelFormatType_32BGRA,
        (__bridge CFDictionaryRef)(cvBufferProperties),
        &pixel_buffer);

    if (err) {
        NSLog(@"Pixel buffer not created");
        return nullptr;
    }

    CVPixelBufferLockBaseAddress(pixel_buffer, 0);
    
    GLubyte *pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixel_buffer);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
    pixel_buffer = convert_rgba_to_nv12(pixel_buffer, vrange::full_range);

    return (void*)pixel_buffer;
}
