#pragma once

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <CoreMedia/CoreMedia.h>

//MARK: BNBCopyableMetalLayer -- Start

@interface BNBCopyableMetalLayer : CAMetalLayer

@property(strong, nonatomic, readonly) id<CAMetalDrawable> currentDrawable;

@end

@interface BNBCopyableMetalLayer ()

@property(strong, nonatomic, readwrite) id<CAMetalDrawable> currentDrawable;

@end

//MARK: BNBCopyableMetalLayer -- End
