# MatrixDefaults.cmake
# Provides default MATRIX_CXX_FLAGS / MATRIX_LD_FLAGS when not set by the
# build script. Targets include this file and then use the variables in
# target_compile_options / target_link_options.
#
# Usage from a target CMakeLists.txt:
#   include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)
#   target_compile_options(my_target PRIVATE
#       $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_CXX_FLAGS}>)

if(NOT DEFINED MATRIX_CXX_FLAGS)
    # Sensible release-mode default: static CRT, optimized, stack cookies.
    set(MATRIX_CXX_FLAGS "/MT /O2 /GS" CACHE STRING "Compiler flags injected by matrix build")
endif()

if(NOT DEFINED MATRIX_LD_FLAGS)
    set(MATRIX_LD_FLAGS "/MT" CACHE STRING "Linker flags injected by matrix build")
endif()

if(NOT DEFINED MATRIX_SUFFIX)
    set(MATRIX_SUFFIX "" CACHE STRING "Suffix appended to output names, e.g. _x64_Debug")
endif()

if(DEFINED MATRIX_OUTPUT_DIR)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${MATRIX_OUTPUT_DIR}")
endif()
