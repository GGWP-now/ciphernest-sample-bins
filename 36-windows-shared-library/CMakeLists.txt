cmake_minimum_required(VERSION 3.16)
project(windows_shared_library LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

add_library(win_shared SHARED win_shared.c)
target_include_directories(win_shared PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_definitions(win_shared PRIVATE WIN_SHARED_EXPORTS)
target_compile_options(win_shared PRIVATE
    $<$<C_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(win_shared PRIVATE
    $<$<C_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS}>)

add_executable(win_shared_smoke smoke.c)
target_link_libraries(win_shared_smoke PRIVATE win_shared)
target_compile_options(win_shared_smoke PRIVATE
    $<$<C_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)
target_link_options(win_shared_smoke PRIVATE
    $<$<C_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS}>)

set_target_properties(win_shared win_shared_smoke PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${MATRIX_OUTPUT_DIR}"
    LIBRARY_OUTPUT_DIRECTORY "${MATRIX_OUTPUT_DIR}"
    ARCHIVE_OUTPUT_DIRECTORY "${MATRIX_OUTPUT_DIR}")
