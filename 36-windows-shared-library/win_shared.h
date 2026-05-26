#pragma once

#ifdef _WIN32
#  ifdef WIN_SHARED_EXPORTS
#    define WIN_SHARED_API __declspec(dllexport)
#  else
#    define WIN_SHARED_API __declspec(dllimport)
#  endif
#else
#  define WIN_SHARED_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

WIN_SHARED_API int win_shared_add(int left, int right);
WIN_SHARED_API unsigned int win_shared_checksum(const char *text);
WIN_SHARED_API const char *win_shared_version(void);

#ifdef __cplusplus
}
#endif
