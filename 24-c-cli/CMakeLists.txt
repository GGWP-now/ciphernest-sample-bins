cmake_minimum_required(VERSION 3.16)
project(c_cli LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

add_executable(c_cli main.c)

target_compile_options(c_cli PRIVATE
    $<$<C_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(c_cli PRIVATE
    $<$<C_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS}>)
