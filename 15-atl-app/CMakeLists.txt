cmake_minimum_required(VERSION 3.16)
project(atl_app LANGUAGES CXX RC)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

add_executable(atl_app WIN32 main.cpp resource.rc)
target_compile_options(atl_app PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(atl_app PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS} /SUBSYSTEM:WINDOWS>
)
