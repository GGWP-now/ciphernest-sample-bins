// TLS Callbacks / Static Init / Custom Section / __declspec(thread) Demo
// Compile: MSVC /MT /O2 /GS

#include <windows.h>
#include <cstdio>

// ============================================================
// 1. TLS (Thread-Local Storage) variable
//    Each thread gets its own copy.
// ============================================================
__declspec(thread) int tls_counter = 0;

// ============================================================
// 2. TLS callback — runs before main() on the primary thread,
//    and on every new thread before its entry point.
//    We use the standard CRT TLS callback section .CRT$XLB.
// ============================================================
#pragma section(".CRT$XLB", read)

void NTAPI TlsCallback(PVOID /*DllHandle*/, DWORD Reason, PVOID /*Reserved*/)
{
    // Only log ATTACH reasons so the output is clean
    if (Reason == DLL_PROCESS_ATTACH) {
        printf("[TLS callback] DLL_PROCESS_ATTACH on thread %lu\n",
               GetCurrentThreadId());
    } else if (Reason == DLL_THREAD_ATTACH) {
        printf("[TLS callback] DLL_THREAD_ATTACH on thread %lu\n",
               GetCurrentThreadId());
    }
}

// Place the function pointer into the TLS callback array
__declspec(allocate(".CRT$XLB")) PIMAGE_TLS_CALLBACK _xlb_callback = TlsCallback;

// ============================================================
// 3. Static global with constructor that runs before main()
// ============================================================
struct GlobalInit {
    GlobalInit()
    {
        printf("[GlobalInit] constructor called before main()\n");
    }
    ~GlobalInit()
    {
        printf("[GlobalInit] destructor called\n");
    }
};

static GlobalInit g_init;

// ============================================================
// 4. Custom PE section — variable placed in ".mysec"
//    The section must be declared before allocating into it.
// ============================================================
#pragma section(".mysec", read, write)
__declspec(allocate(".mysec")) int custom_section_var = 0xDEADBEEF;

// ============================================================
// 5. Helper thread — demonstrates per-thread TLS copies
// ============================================================
DWORD WINAPI ThreadProc(LPVOID /*param*/)
{
    // Each thread has its own tls_counter
    tls_counter = 99;
    printf("  [Thread %lu] tls_counter = %d (per-thread copy)\n",
           GetCurrentThreadId(), tls_counter);
    return 0;
}

// ============================================================
// 6. main — runs after TLS callback and static init
// ============================================================
int main()
{
    printf("\n===== TLS Callbacks Demo =====\n\n");

    // --- TLS variable access from main thread ---
    printf("[Main Thread %lu]\n", GetCurrentThreadId());
    tls_counter = 42;
    printf("  tls_counter = %d\n\n", tls_counter);

    // --- Custom section variable ---
    printf("[Custom Section \".mysec\"]\n");
    printf("  custom_section_var at %p = 0x%08X\n\n",
           static_cast<void*>(&custom_section_var), custom_section_var);

    // --- Spawn a helper thread to show per-thread TLS isolation ---
    printf("[Spawning helper thread via CreateThread...]\n");
    HANDLE hThread = CreateThread(nullptr, 0, ThreadProc, nullptr, 0, nullptr);
    if (hThread) {
        WaitForSingleObject(hThread, INFINITE);
        CloseHandle(hThread);
    }

    // Show that main's copy was not affected
    printf("\n[Back in main thread]\n");
    printf("  tls_counter = %d (unchanged — per-thread copies are isolated)\n\n",
           tls_counter);

    printf("===== Demo Complete =====\n");
    return 0;
}
