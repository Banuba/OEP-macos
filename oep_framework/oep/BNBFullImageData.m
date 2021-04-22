#import "BNBFullImageData.h"

@implementation BNBFullImageData
{
    __nullable CVBufferRef mCvPixelBuffer;
}

- (instancetype)init:(CVPixelBufferRef)buffer
    requireMirroring:(BOOL)requireMirroring
     faceOrientation:(NSInteger)faceOrientation
         fieldOfView:(float)fieldOfView
{
    uint32_t pixelFormat = CVPixelBufferGetPixelFormatType(buffer);
    switch (pixelFormat) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
        case kCVPixelFormatType_24RGB:
        case kCVPixelFormatType_24BGR:
        case kCVPixelFormatType_32RGBA:
        case kCVPixelFormatType_32BGRA:
        case kCVPixelFormatType_32ARGB:
            break;
        default:
            [NSException raise:NSInvalidArgumentException format:@"%@", @"Unsupported buffer type"];
            break;
    }

    self = [super init];

    if (self) {
        mCvPixelBuffer = CVPixelBufferRetain(buffer);
        _requireMirroring = requireMirroring;
        _faceOrientation = (int) faceOrientation;
        _fieldOfView = fieldOfView;
    }
    return self;
}

- (uint32_t)width
{
    if (mCvPixelBuffer)
        return (uint32_t) CVPixelBufferGetWidth(mCvPixelBuffer);
    return 0;
}

- (uint32_t)height
{
    if (mCvPixelBuffer)
        return (uint32_t) CVPixelBufferGetHeight(mCvPixelBuffer);
    return 0;
}

- (__nullable CVPixelBufferRef)pixelBuffer
{
    return mCvPixelBuffer;
}

- (void)dealloc
{
    // this is NULL safe
    CVPixelBufferRelease(mCvPixelBuffer);
    mCvPixelBuffer = NULL;
}

@end
