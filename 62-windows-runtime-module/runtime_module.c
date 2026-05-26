#include <windows.h>

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
    UNREFERENCED_PARAMETER(instance);
    UNREFERENCED_PARAMETER(reason);
    UNREFERENCED_PARAMETER(reserved);
    return TRUE;
}

__declspec(dllexport) DWORD WindowsRuntimeProbe(DWORD seed) {
    return (seed * 33u) ^ 0x57524D31u;
}
