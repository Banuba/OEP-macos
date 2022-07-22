#include "offscreen_render_target.h"

#include "utils.h"

#include <bnb/effect_player/utility.hpp>

#include "BNBCopyableMetalLayer.h"

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface MetalHelper : NSObject

@property(strong, nonatomic, readonly) id<MTLCommandQueue> commandQueue;
@property(strong, nonatomic, readonly) id<MTLDevice> device;
@property(assign, nonatomic, readonly) CVMetalTextureCacheRef textureCache;
@property(strong, nonatomic, readonly) MTLRenderPassDescriptor* renderPassDescriptor;
@property(strong, nonatomic, readonly) id<MTLRenderPipelineState> pipelineState;
@property(strong, nonatomic, readonly) id<MTLBuffer> indexBuffer;

@end

// MARK: MetalHelper -- Start

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
}

- (CVMetalTextureCacheRef)textureCache
{
    if (!_textureCache) {
        CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device, nil, &_textureCache);

        if (status != kCVReturnSuccess) {
            NSLog(@"Could not create texture cache: %d", status);
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:@"Could not create texture cache"
                                         userInfo:nil];
        }
    }
    return _textureCache;
}

- (id<MTLDevice>)device
{
    if (!_device) {
        _device = MTLCreateSystemDefaultDevice();
        if (!_device) {
            NSLog(@"Could not create metal device");
            @throw [NSException exceptionWithName:NSGenericException reason:@"Could not create metal device" userInfo:nil];
        }
    }
    return _device;
}

- (id<MTLCommandQueue>)commandQueue
{
    if (!_commandQueue) {
        _commandQueue = [self.device newCommandQueue];
        if (!_commandQueue) {
            NSLog(@"Could not create commandQueue");
            @throw [NSException exceptionWithName:NSGenericException reason:@"Could not create commandQueue" userInfo:nil];
        }
    }
    return _commandQueue;
}

- (id<MTLLibrary>)library
{
    if (!_library) {
        NSBundle* bundle = [NSBundle bundleForClass:[MetalHelper class]];
        NSError* error = nil;
        _library = [self.device newDefaultLibraryWithBundle:bundle error:&error];

        if (error) {
            NSLog(@"Cannot create metal shaders library: %@", error);
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:@"Cannot create metal shaders library"
                                         userInfo:nil];
        }
    }
    return _library;
}

- (id<MTLBuffer>)indexBuffer
{
    if (!_indexBuffer) {
        unsigned int indices[] = {
            // clang-format off
            0, 1, 3, // first triangle
            1, 2, 3  // second triangle
            // clang-format on
        };
        _indexBuffer = [self.device newBufferWithBytes:indices length:sizeof(indices) options:MTLResourceOptionCPUCacheModeDefault];
    }
    return _indexBuffer;
}

- (void)dealloc
{
    if (_textureCache) {
        CFRelease(_textureCache);
        _textureCache = nil;
    }
    _indexBuffer = nil;
    _library = nil;
    _commandQueue = nil;
    _device = nil;
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
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

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

// MARK: MetalHelper -- End
//MARK: BNBCopyableMetalLayer -- Start
@implementation BNBCopyableMetalLayer

- (id<CAMetalDrawable>)nextDrawable
{
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
    //MARK: impl -- Start
    struct offscreen_render_target::impl
    {
    public:
        explicit impl();
        ~impl() = default;

        void cleanup_render_buffers();
        void setup_offscreen_pixel_buffer(bnb::oep::interfaces::rotation orientation);
        std::tuple<int, int> getWidthHeight(bnb::oep::interfaces::rotation orientation);
        void setup_offscreen_render_target(bnb::oep::interfaces::rotation orientation);
        void activate_metal();
        void flush_metal();
        bnb::camera_orientation get_camera_orientation(bnb::oep::interfaces::rotation orientation);
        void draw(bnb::oep::interfaces::rotation orientation);
        CVPixelBufferRef get_current_buffer_texture();
        void orient_image(bnb::oep::interfaces::rotation orientation);

        void init(int32_t width, int32_t height);
        void deinit();
        void surface_changed(int32_t width, int32_t height);
        interfaces::surface_data get_layer();

        MetalHelper* get_metal_helper();

    private:
        size_t m_width;
        size_t m_height;
        int m_prev_orientation = -1;
        id<MTLCommandQueue> m_command_queue;
        id<MTLBuffer> m_uniformBuffer;
        BNBCopyableMetalLayer* effectPlayerLayer;
        id<MTLBuffer> m_vertexBuffer;
        id<MTLBuffer> m_indicesBuffer;
        CVMetalTextureRef texture;
        id<MTLBuffer> m_framebuffer{0};
        id<MTLBuffer> m_postProcessingFramebuffer{0};
        MTLPixelFormat m_pixelFormat = MTLPixelFormatBGRA8Unorm;
        CVPixelBufferRef m_offscreenRenderPixelBuffer{nullptr};
        CVMetalTextureRef m_offscreenRenderTexture{nullptr};
        id<MTLTexture> m_offscreenRenderMetalTexture;
        MetalHelper* m_metalHelper{nullptr};
    };

    offscreen_render_target::impl::impl()
    {
    }

    MetalHelper* offscreen_render_target::impl::get_metal_helper()
    {
        if (!m_metalHelper) {
            m_metalHelper = [[MetalHelper alloc] init];
        }
        return m_metalHelper;
    }

    void offscreen_render_target::impl::cleanup_render_buffers()
    {
        if (m_offscreenRenderPixelBuffer) {
            CFRelease(m_offscreenRenderPixelBuffer);
            m_offscreenRenderPixelBuffer = nullptr;
        }
        if (m_offscreenRenderTexture) {
            CFRelease(m_offscreenRenderTexture);
            m_offscreenRenderTexture = nullptr;
        }
    }

    void offscreen_render_target::impl::setup_offscreen_pixel_buffer(bnb::oep::interfaces::rotation orientation)
    {
        auto [width, height] = getWidthHeight(orientation);
        NSDictionary* attrs = @{
            (__bridge NSString*) kCVPixelBufferMetalCompatibilityKey: @YES,
            (__bridge NSString*) kCVPixelBufferIOSurfacePropertiesKey: @{}
        };

        // We get data from oep in RGBA, macos defined kCVPixelFormatType_32RGBA but not supported
        // and we have to choose a different type. This does not in any way affect further
        // processing, inside bytes still remain in the order of the RGBA.
        CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef) attrs, &m_offscreenRenderPixelBuffer);

        if (err != noErr) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:@"Cannot create offscreen pixel buffer"
                                         userInfo:nil];
        }
    }

    std::tuple<int, int> offscreen_render_target::impl::getWidthHeight(bnb::oep::interfaces::rotation orientation)
    {
        auto width = orientation == bnb::oep::interfaces::rotation::deg90 || orientation == bnb::oep::interfaces::rotation::deg270 ? m_height : m_width;
        auto height = orientation == bnb::oep::interfaces::rotation::deg90 || orientation == bnb::oep::interfaces::rotation::deg270 ? m_width : m_height;
        return {m_width, m_height};
    }

    void offscreen_render_target::impl::setup_offscreen_render_target(bnb::oep::interfaces::rotation orientation)
    {
        auto [width, height] = getWidthHeight(orientation);
        CVReturn err = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            get_metal_helper().textureCache,
            m_offscreenRenderPixelBuffer,
            nil,
            m_pixelFormat,
            width,
            height,
            0,
            &m_offscreenRenderTexture);

        if (err != noErr) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:@"Cannot create Metal texture from pixel buffer for the class offscreen_render_target"
                                         userInfo:nil];
        }

        m_offscreenRenderMetalTexture = CVMetalTextureGetTexture(m_offscreenRenderTexture);

        // Create once
        [get_metal_helper() setupRenderPassDescriptorWithTexture:m_offscreenRenderMetalTexture];
        [get_metal_helper() makeRenderPipelineWithVertexFunctionName:@"BNBOEPShaders::vertex_main" fragmentFunctionName:@"BNBOEPShaders::fragment_main"];
    }

    void offscreen_render_target::impl::activate_metal()
    {
        m_command_queue = get_metal_helper().commandQueue;
        effectPlayerLayer = [[BNBCopyableMetalLayer alloc] init];
        [effectPlayerLayer setFramebufferOnly:NO];
    }

    void offscreen_render_target::impl::flush_metal()
    {
        [get_metal_helper() flush];
    }

    bnb::camera_orientation offscreen_render_target::impl::get_camera_orientation(bnb::oep::interfaces::rotation orientation)
    {
        switch (orientation) {
            case bnb::oep::interfaces::rotation::deg180:
                return bnb::camera_orientation::deg_180;
            case bnb::oep::interfaces::rotation::deg90:
                return bnb::camera_orientation::deg_90;
            case bnb::oep::interfaces::rotation::deg270:
                return bnb::camera_orientation::deg_270;
            default:
                return bnb::camera_orientation::deg_0;
        }
    }

    void offscreen_render_target::impl::draw(bnb::oep::interfaces::rotation orientation)
    {
        @autoreleasepool {
            id<MTLTexture> layerTexture = effectPlayerLayer.currentDrawable.texture;

            if (layerTexture) {
                id<MTLCommandBuffer> commandBuffer = [m_command_queue commandBuffer];

                if (commandBuffer) {
                    MetalHelper* helper = get_metal_helper();
                    auto renderDescriptor = helper.renderPassDescriptor;
                    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderDescriptor];

                    if (renderEncoder) {
                        uint32_t orientation_data = static_cast<uint32_t>(orientation);
                        [renderEncoder setVertexBytes:&orientation_data length:sizeof(orientation_data) atIndex:0];


                        [renderEncoder setRenderPipelineState:helper.pipelineState];
                        [renderEncoder setFragmentTexture:layerTexture atIndex:0];
                        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt32 indexBuffer:helper.indexBuffer indexBufferOffset:0];

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
    }


    CVPixelBufferRef offscreen_render_target::impl::get_current_buffer_texture()
    {
        CVPixelBufferRetain(m_offscreenRenderPixelBuffer);
        return m_offscreenRenderPixelBuffer;
    }

    void offscreen_render_target::impl::orient_image(bnb::oep::interfaces::rotation orientation)
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
    }

    void offscreen_render_target::impl::init(int32_t width, int32_t height)
    {
        m_width = width;
        m_height = height;
        activate_metal();
    }

    void offscreen_render_target::impl::deinit()
    {
        cleanup_render_buffers();
        m_metalHelper = nullptr;
        effectPlayerLayer = nullptr;
    }

    void offscreen_render_target::impl::surface_changed(int32_t width, int32_t height)
    {
        cleanup_render_buffers();
        m_width = width;
        m_height = height;
    }

    interfaces::surface_data offscreen_render_target::impl::get_layer()
    {
        auto helper = get_metal_helper();
        interfaces::surface_data data(
            reinterpret_cast<int64_t>(helper.device),
            reinterpret_cast<int64_t>(helper.commandQueue),
            reinterpret_cast<int64_t>(effectPlayerLayer)
        );
        return data;
    }
    //MARK: impl -- Finish

    //MARK: offscreen_render_target -- Start
    offscreen_render_target::offscreen_render_target()
    {
    }

    offscreen_render_target::~offscreen_render_target() = default;

    void offscreen_render_target::cleanup_render_buffers()
    {
        m_impl->cleanup_render_buffers();
    }

    void offscreen_render_target::setup_offscreen_pixel_buffer(bnb::oep::interfaces::rotation orientation)
    {
        m_impl->setup_offscreen_pixel_buffer(orientation);
    }

    std::tuple<int, int> offscreen_render_target::getWidthHeight(bnb::oep::interfaces::rotation orientation)
    {
        return m_impl->getWidthHeight(orientation);
    }

    void offscreen_render_target::setup_offscreen_render_target(bnb::oep::interfaces::rotation orientation)
    {
        m_impl->setup_offscreen_render_target(orientation);
    }

    void offscreen_render_target::activate_metal()
    {
        m_impl->activate_metal();
    }

    void offscreen_render_target::flush_metal()
    {
        m_impl->flush_metal();
    }

    bnb::camera_orientation offscreen_render_target::get_camera_orientation(bnb::oep::interfaces::rotation orientation)
    {
        return m_impl->get_camera_orientation(orientation);
    }

    void offscreen_render_target::draw(bnb::oep::interfaces::rotation orientation)
    {
        m_impl->draw(orientation);
    }

    void offscreen_render_target::init(int32_t width, int32_t height)
    {
        m_impl = std::make_unique<impl>();
        m_impl->init(width, height);
    }

    void offscreen_render_target::deinit()
    {
        m_impl->deinit();
    }

    void offscreen_render_target::surface_changed(int32_t width, int32_t height)
    {
        m_impl->surface_changed(width, height);
    }

    void offscreen_render_target::activate_context()
    { /* Not implemented, unnecessary */
    }
    void offscreen_render_target::deactivate_context()
    { /* Not implemented, unnecessary */
    }
    void offscreen_render_target::prepare_rendering()
    { /* Not implemented, unnecessary */
    }

    void offscreen_render_target::orient_image(bnb::oep::interfaces::rotation orient)
    {
        m_impl->orient_image(orient);
    }

    pixel_buffer_sptr offscreen_render_target::read_current_buffer(bnb::oep::interfaces::image_format format)
    {
        // NOT implemented. See conversion in BNBOffscreenEffectPlayer.
        return nil;
    }

    rendered_texture_t offscreen_render_target::get_current_buffer_texture()
    {
        return m_impl->get_current_buffer_texture();
    }

    interfaces::surface_data offscreen_render_target::get_layer()
    {
        return m_impl->get_layer();
    }

}; // bnb
    //MARK: offscreen_render_target -- Finish
