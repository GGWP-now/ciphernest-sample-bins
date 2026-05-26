cmake_minimum_required(VERSION 3.16)
project(gui_license LANGUAGES CXX RC)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

add_executable(gui_license WIN32 main.cpp resource.rc)
target_compile_options(gui_license PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(gui_license PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS} /SUBSYSTEM:WINDOWS>
)
target_link_libraries(gui_license PRIVATE comctl32)
