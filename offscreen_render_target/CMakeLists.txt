set(include_dirs
    ${CMAKE_CURRENT_SOURCE_DIR}/include/
)

file(GLOB_RECURSE srcs
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.mm
)

add_library(offscreen_rt STATIC ${srcs})

target_include_directories(offscreen_rt PUBLIC
    ${include_dirs}
)

target_include_directories(offscreen_rt PUBLIC ${PROJECT_SOURCE_DIR}
                                               ${CMAKE_CURRENT_SOURCE_DIR}/../bnb_sdk/include
)