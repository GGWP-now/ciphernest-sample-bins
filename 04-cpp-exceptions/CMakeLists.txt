cmake_minimum_required(VERSION 3.16)
project(cpp_exceptions LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

# /EHsc and /GR are structural (C++ exception model + RTTI are target identity)
# Matrix provides CRT/opt on top
add_executable(cpp_exceptions main.cpp)
target_compile_options(cpp_exceptions PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/EHsc /GR ${MATRIX_CXX_FLAGS}>
)
target_link_options(cpp_exceptions PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS}>
)
