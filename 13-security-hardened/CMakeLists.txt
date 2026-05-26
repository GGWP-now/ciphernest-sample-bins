cmake_minimum_required(VERSION 3.16)
project(security_hardened LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

# All security flags are structural — this target IS the security test.
# Matrix provides CRT/opt on top (security flags are always-on here).
add_executable(security_hardened main.cpp)
target_compile_options(security_hardened PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/GS /sdl /guard:cf $<$<EQUAL:${CMAKE_SIZEOF_VOID_P},8>:/guard:ehcont> ${MATRIX_CXX_FLAGS}>
)
target_link_options(security_hardened PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS} /DYNAMICBASE /NXCOMPAT $<$<EQUAL:${CMAKE_SIZEOF_VOID_P},8>:/HIGHENTROPYVA> /GUARD:CF $<$<EQUAL:${CMAKE_SIZEOF_VOID_P},8>:/guard:ehcont> $<$<EQUAL:${CMAKE_SIZEOF_VOID_P},8>:/CETCOMPAT>>
)
