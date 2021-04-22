Quick start examples for integrating [Banuba SDK on macos](https://docs.banuba.com/docs/core/effect_player).

# Getting Started

1. Get the latest Banuba SDK archive for MacOS/Windows and the client token. Please fill out our form at [form at banuba.com](https://www.banuba.com/face-filters-sdk) website, or contact us via [info@banuba.com](mailto:info@banuba.com).
2. Copy `bnb_viewer_standalone/bnb_sdk/` into the `OEP_macos/bnb_sdk` dir:
    `bnb_viewer_standalone/bnb_sdk/` => `OEP_macos/bnb_sdk`
3. Copy `bnb_viewer_standalone/third` files into the `OEP_macos/third` dir:
    `bnb_viewer_standalone/third/` => `OEP_macos/third`
4. Copy and Paste your client token into the appropriate section of `OEP_macos/ViewController.swift`
5. Generate project files by executing the following commands:
    ##### MacOS build:
    ```
        cd %path_to_repository%
        mkdir build
        cd build
        cmake -G Xcode ..
    ```
6. The previous step will generate a Xcode project for MacOS. Open the offscreen_effect_player_macos project in an appropriate IDE on your platform.
7. Select target `example_mac`.
8. Run build.

# Integration of the banuba_oep framework into the Xcode project

1. Follow the first 6 steps from "Getting Started".
2. Select target `banuba_oep` and build(Release and Debug).
3. Copy the assembly framework `banuba_oep.framework` to your application directory. Path of its loation <build_folder>/oep_framework/$(Configuration).
4. Copy the `bnb_sdk` to your application direcory.
5. Copy the `effects` from `resources` to your application direcory.
6. Add references to frameworks in your project settings in the `General` tab in `Frameworks, Libraries, and Embedded Content`:
    - Accelerate
    - OpenGL
    - BanubaEffectPlayer
    - BanubaPostprocess
    - banuba_oep
![Alt text](/resources/images/2DB863E6-8769-43CF-BAD9-21872C4147DA_4_5005_c.jpeg?raw=true "Title")
7. Add paths to the headers `banuba_oep.framework/Headers` in the `Build Settings` tab `Header Search Paths` option
![Alt text](/resources/images/EE331F32-85E8-4FDC-8818-3640F0315FEB_4_5005_c.jpeg?raw=true "Title")
8. Add linker flag `-lc++` to in the `Build Settings` tab `Other Linker Flags` option
![Alt text](/resources/images/613B7E40-66DA-4C65-9F44-5FAAF93760CB_4_5005_c.jpeg?raw=true "Title")
9. Add in the `Build Phases` tab in `Copy Bundle Resources` path to effects(from `resources` directory)
![Alt text](/resources/images/3BAA3154-EF4F-4873-A694-AA25353AB950_4_5005_c.jpeg?raw=true "Title")
10. Add or update bridging header, adding to it `#import "BNBOffscreenEffectPlayer.h"`

These steps are enough for you to use in your project BNBOffscreenEffectPlayer.

# Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

# Sample structure

- **interfaces** - offscreen effect player interfaces
- **offscreen_effect_player** - is a wrapper for effect_player. It allows you to use your own implementation for offscreen_render_target
- **offscreen_render_target** - is an implementation option for the offscreen_render_target interface. Allows to prepare gl framebuffers and textures for receiving a frame from gpu, receive bytes of the processed frame from the gpu and pass them to the cpu, as well as, if necessary, set the orientation for the received frame. This implementation uses GLFW to work with gl context
- **libraries**
    - **utils**
        - **ogl_utils** - contains helper classes to work with Open GL
        - **utils** - сontains common helper classes such as thread_pool
- **oep_framework** - contains build rules banuba_oep framework and BNBOffscreenEffectPlayer, which is a class for working with the effect player 
- **ViewController.swift** - contains a pipeline of frames received from the camera and sent for processing the effect and the subsequent receipt of processed frames