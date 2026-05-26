#define PLUGIN_EXPORTS
#include "plugin_api.h"

const char* GetPluginName() {
    return "Plugin B (Static CRT)";
}

int GetPluginVersion() {
    return 2;
}

int Execute(int a, int b) {
    return a * b;
}
