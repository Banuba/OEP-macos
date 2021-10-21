#include "offscreen_render_target.h"

#include "utils.h"
#include "BNBCopyableMetalLayer.h"

#include <bnb/effect_player/utility.hpp>
#include <bnb/postprocess/interfaces/postprocess_helper.hpp>
#include <oep_framework/oep/BNBOffscreenEffectPlayer.h>

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Cocoa/Cocoa.h>
#import <CoreVideo/CoreVideo.h>

@interface MetalHelper : NSObject

@property(strong, nonatomic, readonly) id<MTLCommandQueue> commandQueue;
@property(strong, nonatomic, readonly) id<MTLDevice> device;
@property(assign, nonatomic, readonly) CVMetalTextureCacheRef textureCache;
@property(strong, nonatomic, readonly) MTLRenderPassDescriptor* renderPassDescriptor;
@property(strong, nonatomic, readonly) id<MTLRenderPipelineState> pipelineState;
@property(strong, nonatomic, readonly) id<MTLBuffer> indexBuffer;

- (void)releaseResources;

@end

//MARK: MetalHelper -- Start

@interface MetalHelper ()

@property(strong, nonatomic, readwrite) id<MTLCommandQueue> commandQueue;
@property(strong, nonatomic, readwrite) id<MTLDevice> device;
@property(strong, nonatomic, readwrite) id<MTLLibrary> library;
@property(assign, nonatomic, readwrite) CVMetalTextureCacheRef textureCache;
@property(strong, nonatomic, readwrite) MTLRenderPassDescriptor* renderPassDescriptor;
@property(strong, nonatomic, readwrite) id<MTLRenderPipelineState> pipelineState;
@property(strong, nonatomic, readwrite) id<MTLBuffer> indexBuffer;

@end

@implementation MetalHelper
{
    id<MTLDevice> _device;
}

+ (instancetype)shared
{
    static MetalHelper* instance = [MetalHelper new];
    return instance;
}

- (void)releaseResources
{
    if (self.textureCache) {
        CFRelease(self.textureCache);
        self.textureCache = nil;
    }
}

- (instancetype)init
{
    self = [super init];

    if (self) {
        //choose device which connected to display
        auto display_id = CGMainDisplayID();
        _device = CGDirectDisplayCopyCurrentMetalDevice(display_id);
        NSLog(@"GPU device name: %@", _device.name);

        if (_device) {
            _commandQueue = [_device newCommandQueue];

            if (_commandQueue) {
                NSBundle* bundle = [NSBundle mainBundle];
                NSString *libPath = [bundle pathForResource:@"OEPShaders" ofType:@"metallib"];
                NSError* error = nil;
                _library = [_device newLibraryWithFile:libPath error:&error];
                
                if (!error) {
                    CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, _device, nil, &_textureCache);

                    if (status != kCVReturnSuccess) {
                        NSLog(@"Could not create texture cache: %d", status);
                        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                                       reason:@"Could not create texture cache"
                                                     userInfo:nil];
                    }
                } else {
                    NSLog(@"Cannot create metal shaders library: %@", error);
                    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                                   reason:@"Cannot create metal shaders library"
                                                 userInfo:nil];
                }

                unsigned int indices[] = {
                    // clang-format off
                    0, 1, 3, // first triangle
                    1, 2, 3  // second triangle
                    // clang-format on
                };
                self.indexBuffer = [self.device newBufferWithBytes:indices length:sizeof(indices) options:MTLResourceOptionCPUCacheModeDefault];
            } else {
                NSLog(@"Could not create commandQueue");
                @throw [NSException exceptionWithName:NSGenericException reason:@"Could not create commandQueue" userInfo:nil];
            }
        } else {
            NSLog(@"Could not create metal device");
            @throw [NSException exceptionWithName:NSGenericException reason:@"Could not create metal device" userInfo:nil];
        }
    }

    return self;
}

- (void)flush
{
    if (self.textureCache) {
        CVMetalTextureCacheFlush(self.textureCache, 0);
    }
}

- (void)setupRenderPassDescriptorWithTexture:(id<MTLTexture>)destinationTexture
{
    self.renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    self.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    self.renderPassDescriptor.colorAttachments[0].texture = destinationTexture;
    self.renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    self.renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
}

- (void)makeRenderPipelineWithVertexFunctionName:(NSString*)vertexFunctionName
                            fragmentFunctionName:(NSString*)fragmentFunctionName
{
    id<MTLFunction> vertexFunc = [self.library newFunctionWithName:vertexFunctionName];

    if (vertexFunc) {
        id<MTLFunction> fragmentFunc = [self.library newFunctionWithName:fragmentFunctionName];

        if (fragmentFunc) {
            self.pipelineState = [self buildRenderPipelineStateWithVertexFunction:vertexFunc fragmentFunction:fragmentFunc];
        } else {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"Could not create fragment function %@", fragmentFunctionName]
                                         userInfo:nil];
        }
    } else {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"Could not create vertex function %@", vertexFunctionName]
                                     userInfo:nil];
    }
}

- (id<MTLRenderPipelineState>)buildRenderPipelineStateWithVertexFunction:(id<MTLFunction>)vertexFunction
                                                        fragmentFunction:(id<MTLFunction>)fragmentFunction
{
    MTLRenderPipelineDescriptor* pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.label = @"Render Pipeline";
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;

    NSError* error = nil;

    id<MTLRenderPipelineState> renderPipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];

    if (error) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"Could not compile render pipeline state: %@", error]
                                     userInfo:nil];
    }

    return renderPipelineState;
}

@end
//MARK: MetalHelper -- End

//MARK: BNBCopyableMetalLayer -- Start
@implementation BNBCopyableMetalLayer

- (id<CAMetalDrawable>)nextDrawable
{
    self.lastDrawable = self.currentDrawable;
    self.currentDrawable = [super nextDrawable];

    return self.currentDrawable;
}

- (void)setFramebufferOnly:(BOOL)framebufferOnly
{
    [super setFramebufferOnly:NO];
}

@end
//MARK: BNBCopyableMetalLayer -- End

using namespace std::literals;

namespace bnb
{
    //MARK: offscreen_render_target -- Start //offscreen_render_target
    offscreen_render_target::offscreen_render_target(size_t width, size_t height)
        : m_width(width)
        , m_height(height)
    {
        m_pixelFormat = MTLPixelFormatRGBA8Unorm;
        m_offscreenRenderTexture = nullptr;
        activate_metal();
    }
   
    offscreen_render_target::~offscreen_render_target()
    {
        [[MetalHelper shared] releaseResources];
        cleanup_render_buffers();
    }
   
    void offscreen_render_target::cleanup_render_buffers()
    {
        if (m_offscreenRenderPixelBuffer) {
            CFRelease(m_offscreenRenderPixelBuffer);
            m_offscreenRenderPixelBuffer = nullptr;
        }
        if (std::any_cast<CVMetalTextureRef>(m_offscreenRenderTexture)) {
            CFRelease(std::any_cast<CVMetalTextureRef>(m_offscreenRenderTexture));
            m_offscreenRenderTexture = nullptr;
        }
    }
   
    void offscreen_render_target::surface_changed(int32_t width, int32_t height)
    {
        cleanup_render_buffers();
   
        m_width = width;
        m_height = height;
    }
   
    void offscreen_render_target::setup_offscreen_pixel_buffer(EPOrientation orientation)
    {
        auto [width, height] = getWidthHeight(orientation);
        NSDictionary* attrs = @{
            (__bridge NSString*) kCVPixelBufferMetalCompatibilityKey: @YES,
            (__bridge NSString*) kCVPixelBufferIOSurfacePropertiesKey: @{}
        };
   
        // We get data from oep in RGBA, macos defined kCVPixelFormatType_32RGBA but not supported
        // and we have to choose a different type. This does not in any way affect further
        // processing, inside bytes still remain in the order of the RGBA.
        CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, (__bridge    CFDictionaryRef) attrs, &m_offscreenRenderPixelBuffer);
   
        if (err != noErr) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                           reason:@"Cannot create offscreen pixel buffer"
                           userInfo:nil];
        }
    }
   
    std::tuple<int, int> offscreen_render_target::getWidthHeight(EPOrientation orientation)
     {
         auto width = orientation == EPOrientation::EPOrientationAngles90 || orientation ==    EPOrientation::EPOrientationAngles270 ? m_height : m_width;
         auto height = orientation == EPOrientation::EPOrientationAngles90 || orientation ==    EPOrientation::EPOrientationAngles270 ? m_width : m_height;
         return {m_width, m_height};
     }
   
    void offscreen_render_target::setup_offscreen_render_target(EPOrientation orientation)
    {
         auto [width, height] = getWidthHeight(orientation);
         CVMetalTextureRef m_tempOffscreenRenderTexture{nullptr};
         CVReturn err = CVMetalTextureCacheCreateTextureFromImage(
             kCFAllocatorDefault,
             [MetalHelper shared].textureCache,
             m_offscreenRenderPixelBuffer,
             NULL,
             std::any_cast<MTLPixelFormat>(m_pixelFormat),
             width,
             height,
             0,
             &m_tempOffscreenRenderTexture);
         m_offscreenRenderTexture = m_tempOffscreenRenderTexture;
   
         if (err != noErr) {
             @throw [NSException exceptionWithName:NSInternalInconsistencyException
                            reason:@"Cannot create Metal texture from pixel buffer for the class    BNBOffscreenEffectPlayer"
                           userInfo:nil];
         }
   
         m_offscreenRenderMetalTexture = CVMetalTextureGetTexture(std::any_cast<CVMetalTextureRef>(m_offscreenRenderTexture));
   
         // Create once
         [[MetalHelper shared] setupRenderPassDescriptorWithTexture:std::any_cast<id<MTLTexture>>(m_offscreenRenderMetalTexture)];
         [[MetalHelper shared] makeRenderPipelineWithVertexFunctionName:@"BNBOEPShaders::vertex_main"    fragmentFunctionName:@"BNBOEPShaders::fragment_main"];
    }
   
    void offscreen_render_target::activate_metal()
    {
        m_command_queue = [MetalHelper shared].commandQueue;
        effectPlayerLayer = [[BNBCopyableMetalLayer alloc] init];
    }
   
    void offscreen_render_target::flush_metal()
    {
        [[MetalHelper shared] flush];
    }
   
    bnb::camera_orientation offscreen_render_target::get_camera_orientation(EPOrientation orientation)
    {
        switch (orientation) {
            case EPOrientation::EPOrientationAngles180:
                return bnb::camera_orientation::deg_180;
            case EPOrientation::EPOrientationAngles90:
                return bnb::camera_orientation::deg_90;
            case EPOrientation::EPOrientationAngles270:
                return bnb::camera_orientation::deg_270;
            default:
                return bnb::camera_orientation::deg_0;
        }
    }
   
    void offscreen_render_target::draw(EPOrientation orientation)
    {
        id<MTLTexture> layerTexture = std::any_cast<BNBCopyableMetalLayer*>(effectPlayerLayer).lastDrawable.texture;
   
        if (layerTexture) {
            id<MTLCommandBuffer> commandBuffer = [std::any_cast<id<MTLCommandQueue>>(m_command_queue) commandBuffer];
   
            if (commandBuffer) {
                MetalHelper* helper = [MetalHelper shared];
                auto renderDescriptor = helper.renderPassDescriptor;
                id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer    renderCommandEncoderWithDescriptor:renderDescriptor];
   
                if (renderEncoder) {
                    uint32_t orientation_data = static_cast<uint32_t>(orientation);
                    [renderEncoder setVertexBytes:&orientation_data length:sizeof(orientation_data) atIndex:0];
   
   
                    [renderEncoder setRenderPipelineState:helper.pipelineState];
                    [renderEncoder setFragmentTexture:layerTexture atIndex:0];
                    [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6    indexType:MTLIndexTypeUInt32 indexBuffer:helper.indexBuffer indexBufferOffset:0];
   
                    [renderEncoder endEncoding];
                    [commandBuffer commit];
                    [commandBuffer waitUntilCompleted];
                } else {
                    NSLog(@"Rendering failed. Cannot create render encoder");
                }
            } else {
                NSLog(@"Rendering failed. Cannot create command buffer");
            }
        }
    }

     CVPixelBufferRef offscreen_render_target::get_oriented_image(EPOrientation orientation)
     {
         if (m_prev_orientation != static_cast<int>(orientation)) {
             if (m_offscreenRenderPixelBuffer != nullptr) {
                 cleanup_render_buffers();
             }
             m_prev_orientation = static_cast<int>(orientation);
         }
    
         if (m_offscreenRenderPixelBuffer == nullptr) {
             setup_offscreen_pixel_buffer(orientation);
             setup_offscreen_render_target(orientation);
         }
    
         draw(orientation);
         flush_metal();
         return m_offscreenRenderPixelBuffer;
     }
    
    void offscreen_render_target::init() {}
    void offscreen_render_target::activate_context() {}
    void offscreen_render_target::prepare_rendering() {}
    void offscreen_render_target::orient_image(interfaces::orient_format orient) {}
    
    void* offscreen_render_target::get_image(){
        return get_oriented_image(EPOrientationAngles180);
    }

    bnb::data_t offscreen_render_target::read_current_buffer() {
         size_t size = m_width * m_height * 4;
         data_t data = data_t{ std::make_unique<uint8_t[]>(size), size };
    
         MTLRegion region = {{ 0, 0, 0 },             // MTLOrigin
                             {m_width, m_height, 1}}; // MTLSize
    
         [std::any_cast<id<MTLTexture>>(m_offscreenRenderMetalTexture)
                                        getBytes: data.data.get()
                                     bytesPerRow: m_width * 4
                                      fromRegion: region
                                     mipmapLevel: 0];
         return data;
    }

    void* offscreen_render_target::get_layer(){
        return (void*)CFBridgingRetain(std::any_cast<BNBCopyableMetalLayer*>(effectPlayerLayer));
    }
}; // bnb
    //MARK: offscreen_render_target -- Finish
