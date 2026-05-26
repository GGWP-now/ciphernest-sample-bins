#include <windows.h>
#include <stdio.h>
#include <stdint.h>

// Force import table entry for user32.dll via direct call declaration.
// This ensures user32.dll appears in the PE import directory for analysis tools.
#pragma comment(lib, "user32.lib")

// ---------------------------------------------------------------------------
// Helper: typed function pointer wrapper for GetProcAddress
// ---------------------------------------------------------------------------
template <typename T>
T ResolveProc(HMODULE mod, const char *name)
{
    return reinterpret_cast<T>(GetProcAddress(mod, name));
}

template <typename T>
T ResolveProc(HMODULE mod, const char *name, T fallback)
{
    T ptr = reinterpret_cast<T>(GetProcAddress(mod, name));
    return ptr ? ptr : fallback;
}

// ---------------------------------------------------------------------------
// Section 1: Load system DLL
// ---------------------------------------------------------------------------
static void Section_LoadSystemDLL()
{
    printf("=== [1] Load System DLL (kernel32.dll) ===\n");

    HMODULE hKernel = LoadLibraryA("kernel32.dll");
    if (hKernel)
    {
        printf("  [+] LoadLibrary(\"kernel32.dll\") returned %p\n",
               (void *)hKernel);
        printf("  [*] Expected: kernel32 is always resident; this bumps\n"
               "      the per-process ref-count without creating a new\n"
               "      mapping.\n");
    }
    else
    {
        printf("  [!] LoadLibrary on kernel32 failed unexpectedly.\n");
    }

    // Free our extra reference so we don't artificially pin it.
    if (hKernel)
        FreeLibrary(hKernel);

    putchar('\n');
}

// ---------------------------------------------------------------------------
// Section 2: GetProcAddress on system functions
// ---------------------------------------------------------------------------
static void Section_GetProcAddressSystem()
{
    printf("=== [2] GetProcAddress on System Functions ===\n");

    HMODULE hKernel = GetModuleHandleA("kernel32.dll");
    if (!hKernel)
    {
        printf("  [!] GetModuleHandle(kernel32) failed.\n");
        return;
    }

    // Resolve GetCurrentProcessId by name and call through the pointer.
    typedef DWORD(WINAPI *TGetCurrentProcessId)(void);
    TGetCurrentProcessId pfnGetCurrentProcessId =
        ResolveProc<TGetCurrentProcessId>(hKernel, "GetCurrentProcessId");

    if (pfnGetCurrentProcessId)
    {
        DWORD viaPtr   = pfnGetCurrentProcessId();
        DWORD viaDirect = GetCurrentProcessId();
        printf("  [+] GetProcAddress(\"GetCurrentProcessId\") -> %p\n",
               (void *)pfnGetCurrentProcessId);
        printf("  [*] Via pointer:   %lu\n", viaPtr);
        printf("  [*] Via direct:    %lu\n", viaDirect);
        printf("  [%s] Results %s\n",
               viaPtr == viaDirect ? "PASS" : "FAIL",
               viaPtr == viaDirect ? "match." : "MISMATCH!");
    }
    else
    {
        printf("  [!] GetProcAddress for GetCurrentProcessId returned NULL\n");
    }

    putchar('\n');
}

// ---------------------------------------------------------------------------
// Section 3: Import table demonstration (direct + GetProcAddress)
// ---------------------------------------------------------------------------
static void Section_ImportTable()
{
    printf("=== [3] Import Table Demonstration ===\n");

    // Direct call — forces user32.dll into the import address table.
    int mbResult = MessageBoxA(NULL,
                               "Direct call to MessageBoxA",
                               "Import Table Demo",
                               MB_OK | MB_ICONINFORMATION);
    printf("  [+] Direct MessageBoxA returned %d\n", mbResult);

    // Now resolve the same function via GetProcAddress on the already-loaded
    // module.  user32 was pulled in by the linker; get its handle.
    HMODULE hUser32 = GetModuleHandleA("user32.dll");
    if (hUser32)
    {
        typedef int(WINAPI *TMessageBoxA)(HWND, LPCSTR, LPCSTR, UINT);
        TMessageBoxA pfnMsgBox =
            ResolveProc<TMessageBoxA>(hUser32, "MessageBoxA");

        if (pfnMsgBox)
        {
            int mbViaGetProc = pfnMsgBox(NULL,
                                         "Called via GetProcAddress",
                                         "Import Table Demo",
                                         MB_OK | MB_ICONINFORMATION);
            printf("  [+] GetProcAddress(\"MessageBoxA\") -> %p\n",
                   (void *)pfnMsgBox);
            printf("  [+] Via pointer returned %d\n", mbViaGetProc);
        }
        else
        {
            printf("  [!] GetProcAddress for MessageBoxA returned NULL\n");
        }
    }
    else
    {
        printf("  [!] user32.dll not found via GetModuleHandle\n");
    }

    putchar('\n');
}

// ---------------------------------------------------------------------------
// Section 4: Loading by ordinal
// ---------------------------------------------------------------------------
static void Section_LoadByOrdinal()
{
    printf("=== [4] Loading by Ordinal ===\n");

    HMODULE hKernel = GetModuleHandleA("kernel32.dll");
    if (!hKernel)
    {
        printf("  [!] Cannot get kernel32 handle.\n");
        return;
    }

    // Resolve GetCurrentProcessId (ordinal 1035 on many Windows builds;
    // ordinals are NOT stable across versions — this is illustrative).
    // MAKEINTRESOURCEA builds an ordinal-encoded string pointer.
#if 1
    // Use a shell-known ordinal for demonstration.  The exact number varies
    // by Windows version; we attempt it and report success/failure rather
    // than hard-coding an assumption.
    //
    // On recent Win10/11 builds the ordinal for GetCurrentProcessId tends
    // to be 1035; this may fail on other builds, which is intentional for
    // showing the fallthrough.
    const uintptr_t kTestOrdinal = 1035;
#else
    // Alternate: use ordinal 1 (first exported function, usually heap-related)
    // which is more likely to exist across versions.
    const uintptr_t kTestOrdinal = 1;
#endif

    FARPROC pfnByOrdinal = GetProcAddress(hKernel,
                                          MAKEINTRESOURCEA(kTestOrdinal));
    if (pfnByOrdinal)
    {
        printf("  [+] GetProcAddress(ordinal=%llu) -> %p\n",
               (unsigned long long)kTestOrdinal,
               (void *)pfnByOrdinal);

        // Call it if it matches what we expect.
        typedef DWORD(WINAPI *TGetPid)(void);
        TGetPid pfnPid = reinterpret_cast<TGetPid>(pfnByOrdinal);
        DWORD pidByOrdinal = pfnPid();
        DWORD pidDirect    = GetCurrentProcessId();
        printf("  [*] Via ordinal:  %lu\n", pidByOrdinal);
        printf("  [*] Via direct:   %lu\n", pidDirect);
        printf("  [%s]\n",
               pidByOrdinal == pidDirect ? "PASS" : "FAIL");
    }
    else
    {
        printf("  [-] GetProcAddress(ordinal=%llu) returned NULL "
               "(expected — ordinals are version-specific).\n",
               (unsigned long long)kTestOrdinal);
    }

    putchar('\n');
}

// ---------------------------------------------------------------------------
// Section 5: Error handling
// ---------------------------------------------------------------------------
static void Section_ErrorHandling()
{
    printf("=== [5] Error Handling ===\n");

    // 5a — LoadLibrary on a non-existent DLL
    HMODULE hMissing = LoadLibraryA("nonexistent_plugin.dll");
    if (hMissing == NULL)
    {
        DWORD err = GetLastError();
        printf("  [+] LoadLibrary(\"nonexistent_plugin.dll\") returned NULL\n");
        printf("  [+] GetLastError() = %lu (0x%08lX)\n", err, err);
        printf("  [*] Common codes:\n"
               "        126 = ERROR_MOD_NOT_FOUND\n"
               "        2   = ERROR_FILE_NOT_FOUND\n");
    }
    else
    {
        // Should never succeed, but handle gracefully.
        printf("  [?] Unexpectedly loaded nonexistent DLL at %p\n",
               (void *)hMissing);
        FreeLibrary(hMissing);
    }

    // 5b — GetProcAddress on a non-existent export
    HMODULE hKernel = GetModuleHandleA("kernel32.dll");
    if (hKernel)
    {
        FARPROC pfnFake = GetProcAddress(hKernel,
                                         "ThisFunctionDoesNotExist_XYZ");
        if (pfnFake == NULL)
        {
            DWORD err = GetLastError();
            printf("  [+] GetProcAddress for non-existent export -> NULL\n");
            printf("  [+] GetLastError() = %lu (0x%08lX)\n", err, err);
            // 127 = ERROR_PROC_NOT_FOUND
        }
        else
        {
            printf("  [?] GetProcAddress unexpectedly succeeded: %p\n",
                   (void *)pfnFake);
        }
    }

    // 5c — GetProcAddress on a NULL module (should return NULL)
    FARPROC pfnNullMod = GetProcAddress(NULL, "SomeFunction");
    if (pfnNullMod == NULL)
    {
        DWORD err = GetLastError();
        printf("  [+] GetProcAddress(NULL, \"SomeFunction\") -> NULL\n");
        printf("  [+] GetLastError() = %lu\n", err);
    }

    putchar('\n');
}

// ---------------------------------------------------------------------------
// Section 6: Module enumeration
// ---------------------------------------------------------------------------
static void Section_ModuleEnumeration()
{
    printf("=== [6] Module Enumeration (GetModuleHandle) ===\n");

    // Before loading anything new.
    HMODULE hKernel = GetModuleHandleA("kernel32.dll");
    HMODULE hNtdll  = GetModuleHandleA("ntdll.dll");
    HMODULE hUser32 = GetModuleHandleA("user32.dll");

    printf("  [*] Before explicit LoadLibrary:\n");
    printf("      kernel32.dll -> %p\n", (void *)hKernel);
    printf("      ntdll.dll    -> %p\n", (void *)hNtdll);
    printf("      user32.dll   -> %p\n", (void *)hUser32);

    // Load a DLL we haven't explicitly loaded yet.
    HMODULE hGdi32 = LoadLibraryA("gdi32.dll");
    printf("\n  [+] After LoadLibrary(\"gdi32.dll\"):\n");

    HMODULE hGdi32Check = GetModuleHandleA("gdi32.dll");
    printf("      GetModuleHandle(\"gdi32.dll\") -> %p\n",
           (void *)hGdi32Check);

    if (hGdi32)
    {
        printf("      (original LoadLibrary handle %p)\n", (void *)hGdi32);
        FreeLibrary(hGdi32);
    }

    // Double-check after freeing our reference (module stays loaded if the
    // process still needs it, so GetModuleHandle still works).
    HMODULE hGdi32After = GetModuleHandleA("gdi32.dll");
    printf("      After FreeLibrary, GetModuleHandle -> %p\n",
           (void *)hGdi32After);
    printf("      (likely non-NULL since other system components\n"
           "       may keep a reference)\n");

    putchar('\n');
}

// ---------------------------------------------------------------------------
// Section 7: Delay-import simulation (resolve with fallback)
// ---------------------------------------------------------------------------
static void Section_DelayImportSimulation()
{
    printf("=== [7] Delay-Import Simulation ===\n");

    // Simulate delay-load behaviour: try to resolve a function, and if it's
    // unavailable, use a fallback implementation.

    HMODULE hNtdll = GetModuleHandleA("ntdll.dll");

    // Attempt to resolve NtQueryInformationProcess — present on all modern
    // NT-based Windows, but we show the fallback pattern regardless.
    typedef LONG(NTAPI *TNtQueryInformationProcess)(
        HANDLE, DWORD, PVOID, ULONG, PULONG);

    // The fallback: just use GetLastError as a trivial operation.
    auto FallbackImpl = []() -> DWORD {
        SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
        DWORD err = GetLastError();
        printf("  [*] Fallback invoked (ERROR_CALL_NOT_IMPLEMENTED, "
               "code=%lu)\n", err);
        return err;
    };

    if (hNtdll)
    {
        // TResolveProc<T> without a fallback — returns NULL if missing.
        TNtQueryInformationProcess pfnNtQIP =
            ResolveProc<TNtQueryInformationProcess>(
                hNtdll, "NtQueryInformationProcess");

        if (pfnNtQIP)
        {
            printf("  [+] NtQueryInformationProcess resolved at %p\n",
                   (void *)pfnNtQIP);
            // Show we can call it — query process exit status.
            DWORD exitStatus = 0;
            struct PROCESS_BASIC_INFORMATION {
                NTSTATUS  ExitStatus;
                PVOID     PebBaseAddress;
                ULONG_PTR AffinityMask;
                LONG      BasePriority;
                ULONG_PTR UniqueProcessId;
                ULONG_PTR InheritedFromUniqueProcessId;
            } pbi;
            ULONG retLen = 0;
            const DWORD ProcessBasicInformation = 0;

            LONG status = pfnNtQIP(GetCurrentProcess(),
                                   ProcessBasicInformation,
                                   &pbi, (ULONG)sizeof(pbi), &retLen);
            printf("      NtQueryInformationProcess returned 0x%08lX\n",
                   (LONG)status);
            printf("      ProcessId = %llu\n",
                   (unsigned long long)pbi.UniqueProcessId);
        }
        else
        {
            printf("  [-] NtQueryInformationProcess not available.\n");
            FallbackImpl();
        }
    }
    else
    {
        printf("  [-] ntdll.dll not found (unexpected on Windows).\n");
        FallbackImpl();
    }

    // Demonstrate the "resolve-or-fall-back" helper with a function that
    // definitely does NOT exist.
    HMODULE hKernel = GetModuleHandleA("kernel32.dll");
    if (hKernel)
    {
        // This is the fallback we'll use if the function doesn't exist.
        auto fallbackMsg = []() -> DWORD {
            printf("  [*] Fallback: fake function not available.\n");
            return ERROR_PROC_NOT_FOUND;
        };

        // We know this export doesn't exist — confirms the fallback path.
        typedef DWORD(WINAPI *TFakeFunc)(void);
        TFakeFunc pfnFake = ResolveProc<TFakeFunc>(
            hKernel, "FakeExport_DoesNotExist", fallbackMsg);

        printf("  [+] ResolveProc with fallback returned %p\n",
               (void *)pfnFake);
        if (pfnFake != nullptr)
        {
            pfnFake();
        }
    }

    putchar('\n');
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
int main()
{
    printf("============================================\n");
    printf("  DLL Plugin Loader  -  Pattern Demonstrator\n");
    printf("============================================\n\n");

    Section_LoadSystemDLL();
    Section_GetProcAddressSystem();
    Section_ImportTable();
    Section_LoadByOrdinal();
    Section_ErrorHandling();
    Section_ModuleEnumeration();
    Section_DelayImportSimulation();

    printf("============================================\n");
    printf("  All sections complete.\n");
    printf("============================================\n");

    // Keep the console window open when launched from a GUI runner.
    printf("\nPress Enter to exit...");
    (void)getchar();

    return 0;
}
