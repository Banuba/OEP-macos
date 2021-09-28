cmake_minimum_required(VERSION 3.9)

project(offscreen_effect_player_macos LANGUAGES C CXX OBJC OBJCXX Swift)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_MACOSX_BUNDLE YES)

set(BNB_RESOURCES_FOLDER ${CMAKE_CURRENT_LIST_DIR}/resources)
set(BNB_THIRD_FOLDER ${CMAKE_CURRENT_LIST_DIR}/third)

# Set to OFF to disable ffmpeg dependency (SDK should be built with disabled video_player also)
set(BNB_VIDEO_PLAYER ON)

include(${CMAKE_CURRENT_LIST_DIR}/cmake/utils.cmake)

add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/bnb_sdk)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/third/glad)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/libraries)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/offscreen_effect_player)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/offscreen_render_target)

option(DEPLOY_BUILD "Build for deployment" OFF)

add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/oep_framework)

# some magic to add these files to copy phase
set(SDK_FRAMEWORK_PATH "${CMAKE_CURRENT_LIST_DIR}/bnb_sdk/mac")
set(FullEPFrameworkPath "${SDK_FRAMEWORK_PATH}/$(CONFIGURATION)/BanubaEffectPlayer.framework")
add_custom_command(OUTPUT "${FullEPFrameworkPath}" COMMAND "")

set(BANUBA_OEP_FRAMEWORK banuba_oep)


set(APP_NAME "example_mac") 

set(CMAKE_XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${PROJECT_SOURCE_DIR}/BNBObjCHeaders.h")
set(CMAKE_XCODE_ATTRIBUTE_SWIFT_OBJC_INTERFACE_HEADER_NAME "MySwiftInterfaceHeader.h")

set(APP_HEADER_FILES
    ./BNBObjCHeaders.h
)

set(APP_SOURCE_FILES
    AppDelegate.swift
    ViewController.swift
)

set(RESOURCES
    ${BNB_RESOURCES_FOLDER}/Main.storyboard
    ${BNB_RESOURCES_FOLDER}/bnb_viewer.icns
    ${BNB_RESOURCES_FOLDER}/effects
    ${BNB_RESOURCES_FOLDER}/OEPShaders.metallib
)

set(CMAKE_XCODE_GENERATE_SCHEME YES)

add_executable(${APP_NAME}
    MACOSX_BUNDLE
    ${APP_HEADER_FILES}
    ${APP_SOURCE_FILES}
    ${RESOURCES}
    ${FullEPFrameworkPath}
)

foreach(assetItem ${RESOURCES})
  set_source_files_properties(${assetItem} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)   
endforeach()
set_source_files_properties(${FullEPFrameworkPath} PROPERTIES MACOSX_PACKAGE_LOCATION Frameworks)

add_dependencies(${APP_NAME} ${BANUBA_OEP_FRAMEWORK})

set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15")
set(CMAKE_XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES")


set(EXAMPLE_BUNDLE_NAME "Banuba Offscreen Rendering Example") # This name can contain up to 15 characters according to Apple's documentation
set(EXAMPLE_COPYRIGHT "© 2021 Banuba. All rights reserved.")
set(EXAMPLE_INFO "Banuba Offscreen Rendering Example.")

set_target_properties(${APP_NAME} PROPERTIES
    OUTPUT_NAME ${EXAMPLE_BUNDLE_NAME}
    RESOURCE "${RESOURCES}"
    MACOSX_BUNDLE TRUE

    # The same as stadrard MacOSXBundleInfo.plist.in from CMake but with camera permissions added
    MACOSX_BUNDLE_INFO_PLIST ${BNB_RESOURCES_FOLDER}/Info.plist

    MACOSX_BUNDLE_BUNDLE_NAME           ${EXAMPLE_BUNDLE_NAME}                # Sets CFBundleName
    MACOSX_BUNDLE_COPYRIGHT             ${EXAMPLE_COPYRIGHT}                  # Sets NSHumanReadableCopyright
    MACOSX_BUNDLE_GUI_IDENTIFIER        "com.banuba.sdk.offsceen.mac.sample"  # Sets CFBundleIdentifier
    MACOSX_BUNDLE_ICON_FILE             bnb_viewer.icns                       # Sets CFBundleIconFile
    MACOSX_BUNDLE_INFO_STRING           ${EXAMPLE_INFO}                       # Sets CFBundleGetInfoString

    # Explicitly skip code signing (CMake tries to turn it on for application bundles)
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
)

target_link_libraries(${APP_NAME}
    "-framework Accelerate"
    "-framework Cocoa"
    "-framework Foundation"
    "-framework OpenGL"
    "-framework BanubaEffectPlayer"
    "-framework ${BANUBA_OEP_FRAMEWORK}"
)

set_target_properties(${APP_NAME} PROPERTIES XCODE_ATTRIBUTE_FRAMEWORK_SEARCH_PATHS "${SDK_FRAMEWORK_PATH}/$<IF:$<CONFIG:Debug>,debug,release>")
set_target_properties(${APP_NAME} PROPERTIES XCODE_ATTRIBUTE_HEADER_SEARCH_PATHS "$<TARGET_FILE_DIR:${BANUBA_OEP_FRAMEWORK}>/${BANUBA_OEP_FRAMEWORK}.framework/Headers")
set_target_properties(${APP_NAME} PROPERTIES XCODE_ATTRIBUTE_OTHER_LDFLAGS "-F$<TARGET_FILE_DIR:${BANUBA_OEP_FRAMEWORK}> -lc++")
set_target_properties(${APP_NAME} PROPERTIES XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES")

target_link_libraries(${APP_NAME} ${OTHER_LDFLAGS})