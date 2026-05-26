cmake_minimum_required(VERSION 3.16)
project(calc_console LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

# Single target — CRT/opt/security come from MATRIX_* variables
add_executable(calc_console main.cpp)
target_compile_options(calc_console PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(calc_console PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS}>)
