set(FRAMEWORK_NAME "banuba_oep") 

set(CMAKE_XCODE_GENERATE_SCHEME YES)

file(GLOB_RECURSE srcs
    ${CMAKE_CURRENT_LIST_DIR}/oep/*.cpp
    ${CMAKE_CURRENT_LIST_DIR}/oep/*.m
    ${CMAKE_CURRENT_LIST_DIR}/oep/*.mm
    ${CMAKE_CURRENT_LIST_DIR}/oep/*.hpp
    ${CMAKE_CURRENT_LIST_DIR}/oep/*.h
)

add_library(${FRAMEWORK_NAME} STATIC
    ${srcs}
)

target_link_libraries(${FRAMEWORK_NAME}
    bnb_oep_pixel_buffer_target
    bnb_oep_image_processing_result_target
    bnb_oep_offscreen_effect_player_target
    offscreen_rt
)

create_linking_flags(linking_flags ${FRAMEWORK_NAME})
set_target_properties(${FRAMEWORK_NAME} PROPERTIES XCODE_ATTRIBUTE_OTHER_LIBTOOLFLAGS "${linking_flags}")

target_link_libraries(${FRAMEWORK_NAME}
    bnb_effect_player
)
set_target_properties(${FRAMEWORK_NAME} PROPERTIES XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES")

set(public_headers ${CMAKE_CURRENT_LIST_DIR}/oep/BNBOffscreenEffectPlayer.h)

add_custom_command(TARGET ${FRAMEWORK_NAME} POST_BUILD
  COMMAND sh ${PROJECT_SOURCE_DIR}/toolchain/pack_framework.sh ${FRAMEWORK_NAME} ${CMAKE_CURRENT_BINARY_DIR} $<IF:$<CONFIG:Debug>,Debug,Release> ${public_headers}
)

get_target_property(SDK_COMMON_FOLDER bnb_effect_player INTERFACE_BIN_DIR)
target_include_directories(${FRAMEWORK_NAME} PRIVATE debug "${SDK_COMMON_FOLDER}/debug/BanubaEffectPlayer.framework/Headers")
target_include_directories(${FRAMEWORK_NAME} PRIVATE optimized "${SDK_COMMON_FOLDER}/release/BanubaEffectPlayer.framework/Headers")
