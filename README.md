## The sample is deprecated. Please, rely on [this repo](https://github.com/Banuba/quickstart-desktop-cpp) instead.

---

Quick start examples for integrating [Banuba SDK on macos](https://docs.banuba.com/face-ar-sdk-v1/core/effect_player).

# Getting Started

1. Get the latest Banuba SDK archive for MacOS and the client token. Please fill out our form at [form at banuba.com](https://www.banuba.com/face-filters-sdk) website, or contact us via [info@banuba.com](mailto:info@banuba.com).
2. Copy `bnb_sdk.zip/mac` into the `OEP_macos/bnb_sdk` dir.
3. Copy `bnb_sdk.zip/effects` files into the `OEP_macos/resources` dir.
4. Copy and Paste your client token into the appropriate section of [`OEP_macos/ViewController.swift`](ViewController.swift#L21)
5. Configure effect in the appropriate section of [`OEP_macos/ViewController.swift`](ViewController.swift#L26), e.g. `test_BG`
    More effects can be found [here](https://docs.banuba.com/face-ar-sdk-v1/overview/demo_face_filters)
6. Load the OEP-module by executing the following commands:
    ##### MacOS build:
    ```
        cd %path_to_repository%
        git submodule update --init --recursive
    ```
    Then go to the `OEP-module` folder, open the `CMakeLists.txt` and set the "Use bnb offscreen_render_target implementation" option to `OFF`. We don`t need this part of the OEP-module in this sample.
7. Generate project files by executing the following commands:
    ##### MacOS build:
    ```
        cd %path_to_repository%
        mkdir build
        cd build
        cmake -G Xcode ..
    ```
8. The previous step will generate a Xcode project for MacOS. Open the offscreen_effect_player_macos project in an appropriate IDE on your platform.
9. Select target `example_mac`.
10. Run build.

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
