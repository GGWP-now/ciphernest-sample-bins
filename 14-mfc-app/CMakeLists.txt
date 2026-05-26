cmake_minimum_required(VERSION 3.16)

# Shared MFC DLL — CMake auto-links correct import lib (mfc140u/mfc140ud).
set(CMAKE_MFC_FLAG 2)

project(mfc_app LANGUAGES CXX RC)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MatrixDefaults.cmake)

# Strip CRT flags from MATRIX_CXX_FLAGS — MFC shared DLL always uses dynamic CRT.
string(REGEX REPLACE "/M[TD]d?" "" _MFC_CXX_FLAGS "${MATRIX_CXX_FLAGS}")

add_executable(mfc_app WIN32
    main.cpp
    mfc_app.h
    mfc_app.rc
    resource.h
)

target_compile_definitions(mfc_app PRIVATE _AFXDLL)
target_compile_options(mfc_app PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/MD>    # _AFXDLL requires dynamic CRT
    $<$<CXX_COMPILER_ID:MSVC>:${_MFC_CXX_FLAGS}>
)
target_link_options(mfc_app PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:${MATRIX_LD_FLAGS} /SUBSYSTEM:WINDOWS>
)
target_link_libraries(mfc_app PRIVATE mfc140u)
