cmake_minimum_required(VERSION 3.16)
project(cfg_testbed LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

# /guard:cf (compile) is structural — this target tests CFG
# /GUARD:CF /DYNAMICBASE (link) are structural
# Matrix provides CRT/opt on top
add_executable(cfg_testbed main.cpp)
target_compile_options(cfg_testbed PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/guard:cf ${MATRIX_CXX_FLAGS}>
)
target_link_options(cfg_testbed PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS} /GUARD:CF /DYNAMICBASE>
)
