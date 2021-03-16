#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>

#include <mutex>

NSOpenGLContext *OGL_context = nullptr;

void create_context_NS()
{
    static std::once_flag ns_once_flag;
    std::call_once(ns_once_flag, []() {
        if (OGL_context != nil) {
            return;
        }

        NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
            NSOpenGLPFAOpenGLProfile,
            (NSOpenGLPixelFormatAttribute)NSOpenGLProfileVersion4_1Core,
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFAAccelerated, 0,
            0
        };

        NSOpenGLPixelFormat *_pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
        if (_pixelFormat == nil) {
            NSLog(@"Error: No appropriate pixel format found");
        }
        OGL_context = [[NSOpenGLContext alloc] initWithFormat:_pixelFormat shareContext:nil];
        [OGL_context makeCurrentContext];

        if (OGL_context == nil) {
            NSLog(@"Unable to create an OpenGL context. The GPUImage framework requires OpenGL support to work.");
        }
    });
}

void activate_context_NS()
{
    if ([NSOpenGLContext currentContext] != OGL_context) {
        if (OGL_context != nil) {
            [OGL_context makeCurrentContext];
        } else {
            NSLog(@"Error: The OGL context has not been created yet");
        }
    }
}

void destroy_context_NS()
{
    if ([NSOpenGLContext currentContext] == OGL_context) {
        [OGL_context clearCurrentContext];
        OGL_context = nil;
    }
}
