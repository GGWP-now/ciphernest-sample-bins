#include <windows.h>
#include <process.h>
#include <stdio.h>

#include <thread>
#include <mutex>
#include <vector>

// ============================================================================
// Section 1-4: Win32 Threads, CRITICAL_SECTION, TLS, Event Synchronization
// ============================================================================

// Shared counter protected by critical section
CRITICAL_SECTION g_cs;
volatile LONG g_win32_counter = 0;

// Thread-Local Storage — each thread gets its own copy
__declspec(thread) int tls_thread_id = -1;

// Manual-reset event for barrier synchronization
HANDLE g_barrier = NULL;

// --------------------------------------------------------------------------
// Helper that reads the TLS variable to demonstrate per-thread isolation
// --------------------------------------------------------------------------
void PrintTlsInfo()
{
    printf("  [TLS] tls_thread_id == %d  (should match this worker's id)\n",
           tls_thread_id);
}

// --------------------------------------------------------------------------
// Win32 worker thread procedure
// --------------------------------------------------------------------------
DWORD WINAPI Win32Worker(LPVOID param)
{
    int id = static_cast<int>(reinterpret_cast<INT_PTR>(param));

    // Set TLS variable to this thread's identity
    tls_thread_id = id;

    printf("[CRT 0x%04x] Thread %d entered — CRT initialized\n",
           GetCurrentThreadId(), id);

    // Wait at barrier until main signals
    printf("[EVNT 0x%04x] Thread %d waiting at barrier...\n",
           GetCurrentThreadId(), id);
    WaitForSingleObject(g_barrier, INFINITE);
    printf("[EVNT 0x%04x] Thread %d passed the barrier\n",
           GetCurrentThreadId(), id);

    // Demonstrate per-thread TLS isolation
    PrintTlsInfo();

    // Increment shared counter inside critical section
    for (int i = 0; i < 10000; ++i)
    {
        EnterCriticalSection(&g_cs);
        ++g_win32_counter;
        LeaveCriticalSection(&g_cs);
    }

    printf("[CRT 0x%04x] Thread %d exiting — CRT teardown\n",
           GetCurrentThreadId(), id);
    return 0;
}

// ============================================================================
// Section 5: C++11 std::thread + std::mutex
// ============================================================================

std::mutex g_cpp_mtx;
volatile LONG g_cpp_counter = 0;

void CppWorker(int id, int iterations)
{
    printf("[CPP] C++11 worker %d started\n", id);

    for (int i = 0; i < iterations; ++i)
    {
        std::lock_guard<std::mutex> lock(g_cpp_mtx);
        ++g_cpp_counter;
    }

    printf("[CPP] C++11 worker %d finished\n", id);
}

// ============================================================================
// Main
// ============================================================================

int main()
{
    printf("========================================\n");
    printf("   Multithreaded Worker Demonstration\n");
    printf("========================================\n\n");

    // ---- Part A: Win32 Threads -------------------------------------------
    printf("--- [Win32] CreateThread + CRITICAL_SECTION + TLS + Event ---\n\n");

    InitializeCriticalSection(&g_cs);

    // Manual-reset event, initially non-signaled
    g_barrier = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (!g_barrier)
    {
        fprintf(stderr, "CreateEvent failed\n");
        return 1;
    }

    const int NUM_WIN32 = 4;
    HANDLE hThreads[NUM_WIN32];

    for (int i = 0; i < NUM_WIN32; ++i)
    {
        hThreads[i] = CreateThread(
            NULL,                     // default security
            0,                        // default stack size
            Win32Worker,
            reinterpret_cast<LPVOID>(static_cast<INT_PTR>(i)),  // param = id
            0,                        // run immediately
            NULL                      // don't need thread id
        );
        if (!hThreads[i])
        {
            fprintf(stderr, "CreateThread(%d) failed\n", i);
            return 1;
        }
    }

    // Give workers a moment to all reach the barrier
    Sleep(100);

    printf("[MAIN] Signalling barrier event — releasing all workers\n");
    SetEvent(g_barrier);

    // Wait for all workers to finish
    WaitForMultipleObjects(NUM_WIN32, hThreads, TRUE, INFINITE);

    printf("\n[RESULT] g_win32_counter = %ld  (expected %d)\n\n",
           g_win32_counter, NUM_WIN32 * 10000);

    // Cleanup
    for (int i = 0; i < NUM_WIN32; ++i)
        CloseHandle(hThreads[i]);
    CloseHandle(g_barrier);
    DeleteCriticalSection(&g_cs);

    // ---- Part B: C++11 Threads -------------------------------------------
    printf("--- [C++11] std::thread + std::mutex + lock_guard ---\n\n");

    const int NUM_CPP = 4;
    const int ITER = 10000;
    std::vector<std::thread> cpp_threads;
    cpp_threads.reserve(NUM_CPP);

    for (int i = 0; i < NUM_CPP; ++i)
        cpp_threads.emplace_back(CppWorker, i, ITER);

    for (auto& t : cpp_threads)
        t.join();

    printf("\n[RESULT] g_cpp_counter = %ld  (expected %d)\n\n",
           g_cpp_counter, NUM_CPP * ITER);

    // ---- Done -------------------------------------------------------------
    printf("========================================\n");
    printf("   Demonstration Complete\n");
    printf("========================================\n");

    return 0;
}
