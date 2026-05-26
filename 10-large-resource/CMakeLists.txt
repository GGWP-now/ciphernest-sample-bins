cmake_minimum_required(VERSION 3.16)
project(large_resource LANGUAGES CXX RC)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

# Single target — matrix provides CRT/opt/debug-info flags
# Resources and version info are structural (via .rc)
add_executable(large_resource main.cpp resources.rc)
target_compile_options(large_resource PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(large_resource PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS}>)
