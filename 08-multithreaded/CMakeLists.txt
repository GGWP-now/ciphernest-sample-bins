cmake_minimum_required(VERSION 3.16)
project(multithreaded LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

# /GUARD:CF (link) is structural — tests CFG under load
# Matrix provides CRT/opt/GS/guard:cf (compile) on top
add_executable(multithreaded main.cpp)
target_compile_options(multithreaded PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(multithreaded PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS} /GUARD:CF>
)
