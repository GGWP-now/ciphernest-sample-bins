#define PLUGIN_EXPORTS
#include "plugin_api.h"

const char* GetPluginName() {
    return "Plugin A (Dynamic CRT)";
}

int GetPluginVersion() {
    return 1;
}

int Execute(int a, int b) {
    return a + b;
}
