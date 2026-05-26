#pragma once

#ifdef PLUGIN_EXPORTS
#define PLUGIN_API __declspec(dllexport)
#else
#define PLUGIN_API __declspec(dllimport)
#endif

extern "C" {
    PLUGIN_API const char* GetPluginName();
    PLUGIN_API int GetPluginVersion();
    PLUGIN_API int Execute(int a, int b);
}
