# victims/CMakeLists.txt
# Super-build: builds C/C++ victim targets under a single matrix config.
#
# Usage:
#   cmake -B build -DMATRIX_CXX_FLAGS="/MT /O2 /GS" -DMATRIX_LD_FLAGS="/MT"
#   cmake --build build
#
# The per-target CMakeLists still work standalone — this just provides a
# convenient single-entry-point when you want to build everything at once.

cmake_minimum_required(VERSION 3.16)
project(victims_superbuild LANGUAGES C CXX RC)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Forward matrix variables (with defaults) so all subdirectories see them
if(NOT DEFINED MATRIX_CXX_FLAGS)
    set(MATRIX_CXX_FLAGS "/MT /O2 /GS" CACHE STRING "Compiler flags for matrix build")
endif()
if(NOT DEFINED MATRIX_LD_FLAGS)
    set(MATRIX_LD_FLAGS "/MT" CACHE STRING "Linker flags for matrix build")
endif()
if(NOT DEFINED MATRIX_SUFFIX)
    set(MATRIX_SUFFIX "" CACHE STRING "Output name suffix")
endif()

# Optional: override individual target's default with superbuild values
# by setting them as CACHE variables BEFORE add_subdirectory.
# MatrixDefaults.cmake does "if(NOT DEFINED …)" so cache values take priority.
set(MATRIX_CXX_FLAGS "${MATRIX_CXX_FLAGS}" CACHE STRING "" FORCE)
set(MATRIX_LD_FLAGS  "${MATRIX_LD_FLAGS}"  CACHE STRING "" FORCE)

add_subdirectory(01-calc-console)
add_subdirectory(02-gui-license)
add_subdirectory(03-seh-crash)
add_subdirectory(04-cpp-exceptions)
add_subdirectory(05-cfg-testbed)
add_subdirectory(06-tls-callbacks)
add_subdirectory(07-dll-plugin-host)
add_subdirectory(08-multithreaded)
add_subdirectory(09-file-compressor)
add_subdirectory(10-large-resource)
add_subdirectory(11-dll-loader)
add_subdirectory(12-delay-load)
add_subdirectory(13-security-hardened)
add_subdirectory(14-mfc-app)
add_subdirectory(15-atl-app)
add_subdirectory(16-winui-app)
add_subdirectory(36-windows-shared-library)
