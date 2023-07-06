set(CMAKE_XCODE_GENERATE_SCHEME YES)

file(GLOB_RECURSE srcs
    ${CMAKE_CURRENT_LIST_DIR}/oep/*.cpp
    ${CMAKE_CURRENT_LIST_DIR}/oep/*.m
    ${CMAKE_CURRENT_LIST_DIR}/oep/*.mm
    ${CMAKE_CURRENT_LIST_DIR}/oep/*.hpp
    ${CMAKE_CURRENT_LIST_DIR}/oep/*.h
)

add_library(banuba_oep OBJECT
    ${srcs}
)

target_link_libraries(banuba_oep
    bnb_oep_pixel_buffer_target
    bnb_oep_image_processing_result_target
    bnb_oep_offscreen_effect_player_target
    offscreen_rt
)

create_linking_flags(linking_flags banuba_oep)
set_target_properties(banuba_oep PROPERTIES XCODE_ATTRIBUTE_OTHER_LIBTOOLFLAGS "${linking_flags}")

target_link_libraries(banuba_oep
    bnb_effect_player
)
set_target_properties(banuba_oep PROPERTIES XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES")

get_target_property(SDK_COMMON_FOLDER bnb_effect_player INTERFACE_BIN_DIR)

target_include_directories(banuba_oep PUBLIC ${CMAKE_CURRENT_LIST_DIR}/oep/)
