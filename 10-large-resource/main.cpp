#include <windows.h>
#include <winver.h>
#include <stdio.h>
#include <cstdint>

#include "resource.h"
#pragma comment(lib, "version.lib")

// ---------------------------------------------------------------------------
// Helper: load a single RCDATA resource and return its size and first bytes
// ---------------------------------------------------------------------------
static bool enumerate_rcdata(HINSTANCE hInst, const char *label, WORD id,
                             DWORD *outSize, size_t firstBytesToShow) {
    HRSRC hRes = FindResourceA(hInst, MAKEINTRESOURCEA(id), RT_RCDATA);
    if (!hRes) {
        printf("  [%s] FindResource FAILED (GLE=%lu)\n", label, GetLastError());
        *outSize = 0;
        return false;
    }

    DWORD sz = SizeofResource(hInst, hRes);
    HGLOBAL hGlob = LoadResource(hInst, hRes);
    if (!hGlob) {
        printf("  [%s] LoadResource FAILED (GLE=%lu)\n", label, GetLastError());
        *outSize = 0;
        return false;
    }

    const uint8_t *data = (const uint8_t *)LockResource(hGlob);
    printf("  [%s] offset=0x%p  size=%lu bytes\n", label, (const void *)data, sz);

    if (firstBytesToShow > 0 && data) {
        size_t show = (sz < firstBytesToShow) ? (size_t)sz : firstBytesToShow;
        printf("         first %zu bytes: ", show);
        for (size_t i = 0; i < show; ++i)
            printf("%02X ", data[i]);
        printf("\n");
    }

    *outSize = sz;
    return true;
}

// ---------------------------------------------------------------------------
// Version info helpers (query the PE's embedded VERSIONINFO)
// ---------------------------------------------------------------------------
static void print_ver_string(const char *path, const char *subBlock) {
    char full[128];
    snprintf(full, sizeof(full), "\\StringFileInfo\\040904B0\\%s", subBlock);

    char *buf = NULL;
    DWORD dummy;
    DWORD sz = GetFileVersionInfoSizeA(path, &dummy);
    if (sz == 0) return;

    buf = (char *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sz);
    if (!buf) return;

    if (GetFileVersionInfoA(path, 0, sz, buf)) {
        char *val = NULL;
        UINT valLen = 0;
        if (VerQueryValueA(buf, full, (LPVOID *)&val, &valLen) && val && valLen > 0) {
            printf("      %s = %s\n", subBlock, val);
        }
    }
    HeapFree(GetProcessHeap(), 0, buf);
}

static void print_version_info(HINSTANCE hInst) {
    char path[MAX_PATH];
    DWORD len = GetModuleFileNameA(hInst, path, MAX_PATH);
    if (len == 0) {
        printf("  (GetModuleFileName failed)\n");
        return;
    }
    printf("  Module: %s\n", path);

    DWORD handle;
    DWORD sz = GetFileVersionInfoSizeA(path, &handle);
    if (sz == 0) {
        printf("  (no VERSIONINFO resource, GLE=%lu)\n", GetLastError());
        return;
    }

    char *buf = (char *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sz);
    if (!buf) {
        printf("  (HeapAlloc failed)\n");
        return;
    }

    if (!GetFileVersionInfoA(path, 0, sz, buf)) {
        printf("  (GetFileVersionInfo failed, GLE=%lu)\n", GetLastError());
        HeapFree(GetProcessHeap(), 0, buf);
        return;
    }

    // ---- Fixed version fields ----
    VS_FIXEDFILEINFO *ffi = NULL;
    UINT ffiLen = 0;
    if (VerQueryValueA(buf, "\\", (LPVOID *)&ffi, &ffiLen) && ffi) {
        printf("  Fixed version: %u.%u.%u.%u\n",
               HIWORD(ffi->dwFileVersionMS),
               LOWORD(ffi->dwFileVersionMS),
               HIWORD(ffi->dwFileVersionLS),
               LOWORD(ffi->dwFileVersionLS));
        printf("  Product version: %u.%u.%u.%u\n",
               HIWORD(ffi->dwProductVersionMS),
               LOWORD(ffi->dwProductVersionMS),
               HIWORD(ffi->dwProductVersionLS),
               LOWORD(ffi->dwProductVersionLS));
        printf("  FileFlagsMask=0x%08lX  FileFlags=0x%08lX  FileOS=0x%08lX  FileType=0x%08lX\n",
               ffi->dwFileFlagsMask, ffi->dwFileFlags,
               ffi->dwFileOS, ffi->dwFileType);
    }

    // ---- String table entries ----
    print_ver_string(path, "CompanyName");
    print_ver_string(path, "FileDescription");
    print_ver_string(path, "FileVersion");
    print_ver_string(path, "InternalName");
    print_ver_string(path, "LegalCopyright");
    print_ver_string(path, "OriginalFilename");
    print_ver_string(path, "ProductName");
    print_ver_string(path, "ProductVersion");

    HeapFree(GetProcessHeap(), 0, buf);
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
int main() {
    HINSTANCE hInst = GetModuleHandleA(NULL);

    printf("========================================\n");
    printf("  LargeResourceApp - Resource Inspector\n");
    printf("========================================\n\n");

    // ---- 1. Enumerate embedded RCDATA resources ----
    printf("--- RCDATA Resources ---\n");
    DWORD sizes[3];
    enumerate_rcdata(hInst, "IDR_BINARY_DATA1  (1001)", IDR_BINARY_DATA1, &sizes[0], 0);
    enumerate_rcdata(hInst, "IDR_BINARY_DATA2  (1002)", IDR_BINARY_DATA2, &sizes[1], 0);
    enumerate_rcdata(hInst, "IDR_CONFIG_JSON   (1003)", IDR_CONFIG_JSON,  &sizes[2], 0);

    // ---- 2. Version info ----
    printf("\n--- VERSIONINFO Resource ---\n");
    print_version_info(hInst);

    // ---- 3. Icon reference ----
    printf("\n--- Icon Resource ---\n");
    printf("  IDI_APP_ICON = %d (referenced in resources.rc)\n", IDI_APP_ICON);

    // ---- 4. Summary ----
    printf("\n========================================\n");
    printf("  Resource Summary\n");
    printf("========================================\n");
    const char *names[] = { "IDR_BINARY_DATA1", "IDR_BINARY_DATA2", "IDR_CONFIG_JSON" };
    DWORD totalBytes = 0;
    for (int i = 0; i < 3; ++i) {
        printf("  %-20s  %6lu bytes\n", names[i], sizes[i]);
        totalBytes += sizes[i];
    }
    printf("  %-20s  %6lu bytes\n", "IDI_APP_ICON (ext)", 0UL);   // external file, not counted
    printf("  %-20s  %6lu bytes\n", "VERSIONINFO (inline)", 0UL); // measured by GetFileVersionInfo
    printf("  ---------------------------------------\n");
    printf("  Total RCDATA          %6lu bytes\n", totalBytes);
    printf("========================================\n");

    return 0;
}
