cmake_minimum_required(VERSION 3.16)
project(dll_plugin_host LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

# Both DLLs get matrix flags — CRT linkage is controlled by the matrix
# /DLL and /EXPORT:... are structural

add_library(plugin_a SHARED plugin_a.cpp plugin_api.h)
target_compile_options(plugin_a PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(plugin_a PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS} /DLL /EXPORT:GetPluginName /EXPORT:GetPluginVersion /EXPORT:Execute>
)

add_library(plugin_b SHARED plugin_b.cpp plugin_api.h)
target_compile_options(plugin_b PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(plugin_b PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS} /DLL /EXPORT:GetPluginName /EXPORT:GetPluginVersion /EXPORT:Execute>
)

add_executable(plugin_host host.cpp)
target_compile_options(plugin_host PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(plugin_host PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS}>)
add_dependencies(plugin_host plugin_a plugin_b)
