cmake_minimum_required(VERSION 3.16)
project(delay_load LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

# /DELAYLOAD:user32.dll and delayimp are structural — this target tests delay-load
# Matrix provides CRT/opt on top
add_executable(delay_load main.cpp)
target_compile_options(delay_load PRIVATE $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(delay_load PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS} /DELAYLOAD:user32.dll>
)
target_link_libraries(delay_load PRIVATE delayimp)
