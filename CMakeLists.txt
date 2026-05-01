cmake_minimum_required(VERSION 3.20)
project(ugly_c2_ffi
    VERSION 1.0.0
    DESCRIPTION "High-performance 2D collision detection using LuaJIT FFI"
    LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Options
option(BUILD_SHARED_LIBS "Build shared library" ON)
option(BUILD_TESTING "Build tests" OFF)

# Platform-specific settings
if(WIN32)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
    if(MSVC)
        add_compile_options(/W4 /WX)
    endif()
else()
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Find Lua
find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
    pkg_check_modules(LUA QUIET luajit)
endif()

if(NOT LUA_FOUND)
    find_path(LUA_INCLUDE_DIR luajit/lua.h
        PATH_SUFFIXES include luajit-2.1)
    find_library(LUA_LIBRARY NAMES luajit-5.1 luajit)
    if(LUA_INCLUDE_DIR AND LUA_LIBRARY)
        set(LUA_FOUND TRUE)
        set(LUA_INCLUDE_DIRS ${LUA_INCLUDE_DIR})
        set(LUA_LIBRARIES ${LUA_LIBRARY})
    endif()
endif()

if(NOT LUA_FOUND)
    message(FATAL_ERROR "LuaJIT not found. Please install LuaJIT development files.")
endif()

include_directories(${LUA_INCLUDE_DIRS})

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Source files
set(SOURCES
    src/collision_ffi.cpp
    src/collision_layer.hpp
    src/broadphase_grid.hpp
    src/c2wrapper.hpp
    src/c2aabbgetter.hpp
)

# Create library
if(BUILD_SHARED_LIBS)
    add_library(ugly_c2_ffi SHARED ${SOURCES})
    set_target_properties(ugly_c2_ffi PROPERTIES
        VERSION ${PROJECT_VERSION}
        SOVERSION 1
        OUTPUT_NAME "ugly_c2_ffi"
    )
else()
    add_library(ugly_c2_ffi STATIC ${SOURCES})
endif()

target_link_libraries(ugly_c2_ffi PRIVATE ${LUA_LIBRARIES})

# Platform-specific linking
if(APPLE)
    target_link_libraries(ugly_c2_ffi PRIVATE "-framework CoreFoundation")
elseif(UNIX AND NOT APPLE)
    target_link_libraries(ugly_c2_ffi PRIVATE pthread m dl)
elseif(WIN32)
    target_link_libraries(ugly_c2_ffi PRIVATE ws2_32)
endif()

# Install targets
install(TARGETS ugly_c2_ffi
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

install(FILES
    src/collision_layer.hpp
    src/broadphase_grid.hpp
    src/c2wrapper.hpp
    src/c2aabbgetter.hpp
    DESTINATION include/ugly_c2_ffi
)

# Lua module installation
install(FILES
    lua/collision_ffi.lua
    lua/collision/init.lua
    lua/collision/layer.lua
    lua/collision/ffi_defs.lua
    DESTINATION share/lua/5.1/ugly_c2_ffi
)

# Examples installation
install(FILES
    examples/basic.lua
    examples/game-loop.lua
    examples/spatial-queries.lua
    examples/physics.lua
    DESTINATION share/ugly_c2_ffi/examples
)

# Love2D example
install(FILES
    love2d-example/main.lua
    love2d-example/conf.lua
    DESTINATION share/ugly_c2_ffi/love2d-example
)

# Documentation
install(FILES
    docs/api.md
    docs/guide.md
    DESTINATION share/doc/ugly_c2_ffi
)

# Package configuration
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/ugly_c2_ffi-config-version.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/ugly_c2_ffi-config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/ugly_c2_ffi-config.cmake"
    INSTALL_DESTINATION lib/cmake/ugly_c2_ffi
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/ugly_c2_ffi-config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/ugly_c2_ffi-config-version.cmake"
    DESTINATION lib/cmake/ugly_c2_ffi
)

# Testing
if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(test)
endif()

# Export targets
install(EXPORT ugly_c2_ffi-targets
    FILE ugly_c2_ffi-targets.cmake
    NAMESPACE ugly_c2_ffi::
    DESTINATION lib/cmake/ugly_c2_ffi
)

# Print configuration
message(STATUS "Building ugly_c2_ffi v${PROJECT_VERSION}")
message(STATUS "  Shared library: ${BUILD_SHARED_LIBS}")
message(STATUS "  LuaJIT include: ${LUA_INCLUDE_DIRS}")
message(STATUS "  LuaJIT library: ${LUA_LIBRARIES}")