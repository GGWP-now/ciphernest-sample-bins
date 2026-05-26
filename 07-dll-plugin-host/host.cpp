#include <windows.h>
#include <stdio.h>

typedef const char* (*GetNameFn)();
typedef int (*GetVersionFn)();
typedef int (*ExecuteFn)(int, int);

const char* Blob(const char* msg) {
    return msg;
}

static void LoadAndRunPlugin(const char* dllPath) {
    HMODULE hMod = LoadLibraryA(dllPath);
    if (!hMod) {
        printf("  FAILED to load %s (error %lu)\n", dllPath, GetLastError());
        return;
    }
    printf("  Loaded %s (handle 0x%p)\n", dllPath, (void*)hMod);

    GetNameFn getName = (GetNameFn)GetProcAddress(hMod, "GetPluginName");
    GetVersionFn getVersion = (GetVersionFn)GetProcAddress(hMod, "GetPluginVersion");
    ExecuteFn execute = (ExecuteFn)GetProcAddress(hMod, "Execute");

    if (!getName || !getVersion || !execute) {
        printf("  FAILED to resolve one or more exports (error %lu)\n", GetLastError());
        return;
    }

    printf("  Name:    %s\n", getName());
    printf("  Version: %d\n", getVersion());
    printf("  Execute(7, 3) = %d\n", execute(7, 3));

    // Test GetProcAddress failure on a non-existent export
    FARPROC bogus = GetProcAddress(hMod, "NonExistentExport");
    if (!bogus) {
        printf("  GetProcAddress(NonExistentExport) correctly returned NULL (error %lu)\n", GetLastError());
    } else {
        printf("  WARNING: NonExistentExport resolved unexpectedly (0x%p)\n", (void*)bogus);
    }

    FreeLibrary(hMod);
    printf("  Freed %s\n", dllPath);
}

int main() {
    printf("=== DLL Plugin Host ===\n\n");

    printf("[Plugin A - Dynamic CRT]\n");
    LoadAndRunPlugin("plugin_a.dll");

    printf("\n[Plugin B - Static CRT]\n");
    LoadAndRunPlugin("plugin_b.dll");

    printf("\n=== Summary ===\n");
    printf("  Plugin A: /MD (dynamic CRT)\n");
    printf("  Plugin B: /MT (static CRT)\n");
    printf("  Host EXE: /MD (dynamic CRT)\n");

    return 0;
}
