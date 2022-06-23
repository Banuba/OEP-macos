#
# Helper functions and utils for CMake
#

include(CMakeParseArguments)

#
# Define a grouping for source files for a given target based on real file system layout.
# Very usefull for IDE project generation (mainly in XCode and MSVC).
#

macro(group_sources_impl)
    # We can't use GREATER_EQUAL comparison operator because it appears only in CMake version 3.7 and above.
    # So, some crappy code needed.

    set(maj ${CMAKE_MAJOR_VERSION})
    set(min ${CMAKE_MINOR_VERSION})

    if(maj GREATER 3 OR maj EQUAL 3)
        set(maj_cond TRUE)
    else()
        set(maj_cond FALSE)
    endif()

    if(min GREATER 8 OR min EQUAL 8)
        set(min_cond TRUE)
    else()
        set(min_cond FALSE)
    endif()

    if(maj_cond AND min_cond)
        source_group(TREE ${root} FILES ${sources})
    else()
        if(MSVC OR XCODE)
            message(WARNING "Your CMake version doesn't support source grouping. Can't group sources for target ${target}. Consider to use CMake 3.8 or higher.")
        endif()
    endif()
endmacro()

function(group_sources target root)
    get_target_property(sources ${target} SOURCES)
    group_sources_impl()
endfunction()

#
# Organizes targets into a folders in an IDE.
#
function(set_target_folder target folder)
    set_target_properties(${target} PROPERTIES FOLDER ${folder})
endfunction()

function(create_linking_flags result target)
    set(linking_flags "")
    get_target_property(dependency ${target} LINK_LIBRARIES)
    foreach(item ${dependency})
        if(TARGET ${item})
            get_target_property(type ${item} TYPE)
            if(NOT ${type} STREQUAL "INTERFACE_LIBRARY")
                set(linking_flags "${linking_flags} -l${item} -L$<TARGET_FILE_DIR:${item}>")

                set(deeper_linking_flags "")
                create_linking_flags(deeper_linking_flags ${item})
                set(linking_flags "${linking_flags} ${deeper_linking_flags}")
            endif()
        endif()
    endforeach()

    # return values
    set(${result} ${linking_flags} PARENT_SCOPE)
endfunction()