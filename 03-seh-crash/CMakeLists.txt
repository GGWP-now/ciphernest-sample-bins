cmake_minimum_required(VERSION 3.16)
project(seh_crash LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

# Single target — /EHa is structural (required for __try/__except)
# Matrix provides CRT/opt/GS on top
add_executable(seh_crash main.cpp)
target_compile_options(seh_crash PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/EHa ${MATRIX_CXX_FLAGS}>
)
target_link_options(seh_crash PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS}>
)
