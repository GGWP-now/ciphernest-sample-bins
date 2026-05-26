#ifndef WIN32_DLL_I386_H
#define WIN32_DLL_I386_H

#ifdef BUILDING_WIN32_DLL_I386
#define WIN32_DLL_I386_API __declspec(dllexport)
#else
#define WIN32_DLL_I386_API __declspec(dllimport)
#endif

WIN32_DLL_I386_API int win32_dll_i386_transform(int value);

#endif
