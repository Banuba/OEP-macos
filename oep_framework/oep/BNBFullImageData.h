#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface BNBFullImageData : NSObject

- (instancetype)init:(CVPixelBufferRef)buffer
    requireMirroring:(BOOL)requireMirroring
     faceOrientation:(NSInteger)faceOrientation
         fieldOfView:(float)fieldOfView;

@property(nonatomic, readonly) uint32_t width;
@property(nonatomic, readonly) uint32_t height;
@property(nonatomic, readonly) float fieldOfView;
@property(nonatomic, readonly) BOOL requireMirroring;
@property(nonatomic, readonly) int faceOrientation;

@property(nonatomic, readonly) __nullable CVPixelBufferRef pixelBuffer;

@end

NS_ASSUME_NONNULL_END
