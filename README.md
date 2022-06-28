Quick start examples for integrating [Banuba SDK on macos](https://docs.banuba.com/docs/core/effect_player).

# Getting Started

1. Get the latest Banuba SDK archive for MacOS/Windows and the client token. Please fill out our form at [form at banuba.com](https://www.banuba.com/face-filters-sdk) website, or contact us via [info@banuba.com](mailto:info@banuba.com).
2. Copy `bnb_viewer_standalone/bnb_sdk/` into the `OEP_macos/bnb_sdk` dir:
    `bnb_viewer_standalone/bnb_sdk/` => `OEP_macos/bnb_sdk`
3. Copy `bnb_viewer_standalone/third` files into the `OEP_macos/third` dir:
    `bnb_viewer_standalone/third/` => `OEP_macos/third`
    NOTE: This sample only uses `glfw` library from the `third` folder, so please modify the CMakeLists.txt in that folder to remove unnecessary libraries:
    ##### third/CmakeLists.txt
    ```
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/glfw)
    ```
    After that, all other libraries in the `third` folder can be removed to decrease the space usage of the sample.
4. Copy `bnb_viewer_standalone/resources/effects` files into the `OEP_macos/resources` dir:
    `bnb_viewer_standalone/resources/effects/` => `OEP_macos/resources`
5. Copy and Paste your client token into the appropriate section of `OEP_macos/ViewController.swift`
6. Configure effect in the appropriate section of `OEP_macos/ViewController.swift`, e.g. `test_BG`
    More effects can be found [here](https://docs.banuba.com/face-ar-sdk-v1/overview/demo_face_filters)
7. Load the OEP-module by executing the following commands:
    ##### MacOS build:
    ```
        cd %path_to_repository%
        git submodule update --init --recursive
    ```
    Then go to the `OEP-module` folder, open the `CMakeLists.txt` and set the "Use bnb offscreen_render_target implementation" option to `OFF`. We don`t need this part of the OEP-module in this sample.
8. Generate project files by executing the following commands:
    ##### MacOS build:
    ```
        cd %path_to_repository%
        mkdir build
        cd build
        cmake -G Xcode ..
    ```
9. The previous step will generate a Xcode project for MacOS. Open the offscreen_effect_player_macos project in an appropriate IDE on your platform.
10. Select target `example_mac`.
11. Run build.

# Integration of the banuba_oep framework into the Xcode project

1. Follow the first 8 steps from "Getting Started".
2. Select target `banuba_oep` and build(Release and Debug).
3. Copy the assembly framework `banuba_oep.framework` to your application directory. Path of its loation <build_folder>/oep_framework/$(Configuration).
4. Copy the `bnb_sdk` to your application direcory.
5. Copy the `effects` and the `OEPShaders.metallib` from `resources` to your application direcory.
6. Add references to frameworks in your project settings in the `General` tab in `Frameworks, Libraries, and Embedded Content`:
    - Accelerate
    - BanubaEffectPlayer
    - banuba_oep
![Alt text](/resources/images/2DB863E6-8769-43CF-BAD9-21872C4147DA_4_5005_c.jpeg?raw=true "Title")
7. Add paths to the headers `banuba_oep.framework/Headers` in the `Build Settings` tab `Header Search Paths` option
![Alt text](/resources/images/EE331F32-85E8-4FDC-8818-3640F0315FEB_4_5005_c.jpeg?raw=true "Title")
8. Add linker flag `-lc++` to in the `Build Settings` tab `Other Linker Flags` option
![Alt text](/resources/images/613B7E40-66DA-4C65-9F44-5FAAF93760CB_4_5005_c.jpeg?raw=true "Title")
9. Add in the `Build Phases` tab in `Copy Bundle Resources` path to effects(from `resources` directory) and to the `OEPShaders.metallib`
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

- **interfaces** - add some METAL-specific interfaces in addition to OEP-module
- **OEP-module** - is a submodule of the offscreen effect player.
- **offscreen_render_target** - is an implementation option for the offscreen_render_target interface. Allows to prepare METAL framebuffers and textures for receiving a frame from gpu, receive bytes of the processed frame from the gpu and pass them to the cpu, as well as, if necessary, set the orientation for the received frame.
- **libraries**
    - **utils**
        - **utils** - сontains common helper classes such as thread_pool
- **oep_framework** - contains build rules banuba_oep framework and BNBOffscreenEffectPlayer, which is a class for working with the effect player 
- **ViewController.swift** - contains a pipeline of frames received from the camera and sent for processing the effect and the subsequent receipt of processed frames

# Miscellaneous

- if you need to build METAL shaders library you should use next commands:
xcrun -sdk macosx metal -c OEPShaders.metal -o OEPShaders.air
xcrun -sdk macosx metallib OEPShaders.air -o OEPShaders.metallib

- while running test app in Xcode, you could see memory leak. This is some effects of Xcode. You could run the app without Xcode and use system monitor to make certain, that there is no memory leak in release version of the app.
