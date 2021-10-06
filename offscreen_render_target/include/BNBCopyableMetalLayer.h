#pragma once

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <CoreMedia/CoreMedia.h>

//MARK: BNBCopyableMetalLayer -- Start

@interface BNBCopyableMetalLayer : CAMetalLayer

@property(strong, nonatomic, readonly) id<CAMetalDrawable> lastDrawable;

@end

@interface BNBCopyableMetalLayer ()

@property(strong, nonatomic, readwrite) id<CAMetalDrawable> lastDrawable;
@property(strong, nonatomic, readwrite) id<CAMetalDrawable> currentDrawable;

@end

//MARK: BNBCopyableMetalLayer -- End