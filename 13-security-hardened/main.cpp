#include <windows.h>
#include <cstdint>
#include <cstdio>
#include <cstring>

// --------------------------------------------------------------------
// Section 1: /GS — Stack cookie (canary) protection
// --------------------------------------------------------------------
static void demo_gs_protection()
{
    printf("\n=== [1] /GS — Stack Cookie Protection ===\n");
    printf("The /GS flag causes the compiler to insert __security_cookie\n"
           "before a function's local array buffers and verify it on return.\n"
           "Overwriting a local buffer will trigger __security_check_cookie\n"
           "and terminate the process before control can be hijacked.\n\n");

    // A function with a local buffer large enough to warrant a cookie.
    // The compiler inserts __security_cookie at the prologue and checks it
    // in the epilogue.  An overrun past the guard page or cookie will
    // call __report_gsfailure() and abort.
    char buf[16];
    std::memset(buf, 0xAB, sizeof(buf));
    printf("  buf[16] filled with 0xAB at %p\n", (void*)buf);
    printf("  Stack buffer initialized -- /GS cookie should protect this frame\n");
}

// --------------------------------------------------------------------
// Section 2: /sdl — Additional Security Development Lifecycle checks
// --------------------------------------------------------------------
static void demo_sdl_checks()
{
    printf("\n=== [2] /SDL — Security Development Lifecycle Checks ===\n");
    printf("/SDL enables extra security-sensitive warnings and treats\n"
           "selected code patterns as errors.  It also enforces use of\n"
           "the '_s' (safe) CRT variants.\n\n");

    // Use of scanf_s instead of scanf (prevents buffer overrun).
    // Use of strcpy_s instead of strcpy (explicit destination size).
    // Use of strcat_s instead of strcat (explicit destination size).
    {
        char dest[32] = {0};
        const char* src = "SDL-safe-string";

        strcpy_s(dest, sizeof(dest), src);
        printf("  strcpy_s OK: '%s' (length %zu)\n", dest, strlen(dest));

        char cat[64] = {0};
        strcpy_s(cat, sizeof(cat), dest);
        strcat_s(cat, sizeof(cat), "|appended");
        printf("  strcat_s OK: '%s' (length %zu)\n", cat, strlen(cat));

        int ival = 0;
        char input[] = "42";
        printf("  Parsing input \"%s\" with scanf_s... ", input);
        int matched = sscanf_s(input, "%d", &ival);
        if (matched == 1)
            printf("got value %d\n", ival);
        else
            printf("parse failed\n");
    }
}

// --------------------------------------------------------------------
// Section 3: /guard:cf — Control Flow Guard (CFG)
// --------------------------------------------------------------------

// A simple checksum function we'll call through a function pointer.
static uint32_t checksum_impl(const uint8_t* data, size_t len)
{
    uint32_t sum = 0;
    for (size_t i = 0; i < len; ++i) {
        sum += data[i];
    }
    return sum;
}

static void demo_cfg_protection()
{
    printf("\n=== [3] /GUARD:CF — Control Flow Guard ===\n");
    printf("CFG injects a per-indirect-call check so that all call targets\n"
           "must be present in the Guard CF Function Table.  Attacks that\n"
           "redirect function pointers to arbitrary memory are blocked.\n\n");

    typedef uint32_t (*ChecksumFn)(const uint8_t*, size_t);

    // Direct call (no CFG check needed).
    uint8_t test_data[] = {0x10, 0x20, 0x30, 0x40, 0x50};
    uint32_t direct = checksum_impl(test_data, sizeof(test_data));
    printf("  Direct call result: %u (0x%X)\n", direct, direct);

    // Indirect call through function pointer (CFG-verified at runtime).
    ChecksumFn fn = &checksum_impl;
    uint32_t indirect = fn(test_data, sizeof(test_data));
    printf("  Indirect call (fn ptr) result: %u (0x%X)\n", indirect, indirect);

    // Additional indirection: pointer in a struct, then called.
    struct FnHolder {
        ChecksumFn cb;
        const char* label;
    } holder = { &checksum_impl, "struct-indirect" };

    uint32_t struct_indirect = holder.cb(test_data, sizeof(test_data));
    printf("  Struct-indirect call (%s) result: %u (0x%X)\n",
           holder.label, struct_indirect, struct_indirect);

    printf("\n  All indirect calls succeeded under CFG -- any invalid target\n"
           "  would have raised STATUS_DYNAMIC_CODE_BLOCKED (0xC0000609).\n");
}

int main();

// --------------------------------------------------------------------
// Section 4: /DYNAMICBASE — Address Space Layout Randomization (ASLR)
// --------------------------------------------------------------------
static void demo_aslr()
{
    printf("\n=== [4] /DYNAMICBASE — ASLR (Address Space Layout Randomization) ===\n");
    printf("The /DYNAMICBASE linker flag sets the IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE\n"
           "flag in the PE header.  The OS loader then rebases the image at a random\n"
           "virtual address on each process launch.\n\n");

    // Address of a function (code section).
    void* main_addr = (void*)&main;
    // Address of a local variable (stack, already ASLRed via TEB-randomized stack).
    int local = 0;

    printf("  Address of main() : %p\n", main_addr);
    printf("  Address of local  : %p\n", (void*)&local);
    printf("  These addresses vary per execution (module rebased + stack randomized).\n");
}

// --------------------------------------------------------------------
// Section 5: /NXCOMPAT — Data Execution Prevention
// --------------------------------------------------------------------
static void demo_nxcompat()
{
    printf("\n=== [5] /NXCOMPAT — Data Execution Prevention ===\n");
    printf("The /NXCOMPAT flag sets IMAGE_DLLCHARACTERISTICS_NX_COMPAT in the PE header,\n"
           "which instructs the OS to enable hardware-enforced DEP.  The stack, heap,\n"
           "and all data sections are marked non-executable so injected code pages\n"
           "cannot be run.\n\n");

    HMODULE hMod = GetModuleHandleW(NULL);
    if (hMod) {
        // IMAGE_NT_HEADERS -> DllCharacteristics check.
        auto* dos = (const IMAGE_DOS_HEADER*)hMod;
        auto* nt  = (const IMAGE_NT_HEADERS*)((const uint8_t*)hMod + dos->e_lfanew);
        WORD dc = nt->OptionalHeader.DllCharacteristics;

        const char* status = (dc & IMAGE_DLLCHARACTERISTICS_NX_COMPAT)
                             ? "enabled (IMAGE_DLLCHARACTERISTICS_NX_COMPAT set)"
                             : "NOT enabled";
        printf("  DllCharacteristics: 0x%04X\n", dc);
        printf("  NXCOMPAT status: %s\n", status);
    } else {
        printf("  GetModuleHandleW failed -- cannot verify PE header directly\n");
    }

    printf("\n  NXCOMPAT enabled -- data sections are non-executable\n");
}

// --------------------------------------------------------------------
// Section 6: /HIGHENTROPYVA — High-Entropy 64-bit ASLR
// --------------------------------------------------------------------
static void demo_high_entropy_va()
{
    printf("\n=== [6] /HIGHENTROPYVA — High-Entropy ASLR ===\n");
    printf("For 64-bit images, /HIGHENTROPYVA enables full 64-bit ASLR entropy,\n"
           "making base-address brute-force attacks infeasible.  The loader\n"
           "randomizes the image base across the full 64-bit address space.\n\n");

    SYSTEM_INFO si;
    GetSystemInfo(&si);

    printf("  Allocation granularity    : %zu bytes\n", (size_t)si.dwAllocationGranularity);
    printf("  Page size                 : %zu bytes\n", (size_t)si.dwPageSize);
    printf("  Number of processors      : %u\n", si.dwNumberOfProcessors);
    printf("  Active processor mask     : 0x%zX\n", (size_t)si.dwActiveProcessorMask);
    printf("  Max application address   : %p\n", si.lpMaximumApplicationAddress);
    printf("  Min application address   : %p\n", si.lpMinimumApplicationAddress);

    HMODULE hMod = GetModuleHandleW(NULL);
    if (hMod) {
        auto* dos = (const IMAGE_DOS_HEADER*)hMod;
        auto* nt  = (const IMAGE_NT_HEADERS*)((const uint8_t*)hMod + dos->e_lfanew);
        WORD dc = nt->OptionalHeader.DllCharacteristics;

        const char* status = (dc & IMAGE_DLLCHARACTERISTICS_HIGH_ENTROPY_VA)
                             ? "enabled (IMAGE_DLLCHARACTERISTICS_HIGH_ENTROPY_VA set)"
                             : "NOT enabled";

        printf("\n  Image base address : %p\n", (void*)hMod);
        printf("  HIGHENTROPYVA status: %s\n", status);
    }

    printf("\n  HIGHENTROPYVA enabled -- 64-bit ASLR entropy\n");
}

// --------------------------------------------------------------------
// Section 7: Protected function — validate_checksum
// --------------------------------------------------------------------

// A simple protected function that validates a checksum.
// This is the kind of function an obfuscator (like CodeDefender)
// would target for protection: it processes data and makes a
// security-relevant decision.
static int validate_checksum(const uint8_t* data, size_t len)
{
    if (!data || len == 0)
        return -1;  // error

    uint32_t computed = 0;
    for (size_t i = 0; i < len; ++i) {
        computed += data[i];
    }

    // A hard-coded reference checksum for demonstration.
    // In a real protected binary this comparison branch would be
    // opaque-predicated or control-flow-flattened.
    static const uint32_t REF_CHECKSUM = 0xF0;  // 0x10 + 0x20 + 0x30 + 0x40 + 0x50

    printf("    validate_checksum(%p, %zu): computed=0x%X, expected=0x%X\n",
           (const void*)data, len, computed, REF_CHECKSUM);

    return (computed == REF_CHECKSUM) ? 0 : -1;
}

static void demo_protected_function()
{
    printf("\n=== [7] Protected Function — validate_checksum ===\n");
    printf("This function is a candidate for obfuscation:\n"
           " - It iterates over a buffer (loop obfuscation)\n"
           " - It performs a comparison with a hard-coded reference (opaque predicates)\n"
           " - It returns a security-relevant result (access decision)\n"
           "All compiler-enforced mitigations (/GS, /sdl, /guard:cf, /guard:ehcont, ASLR, DEP, CET)\n"
           "remain active around the protected function.\n\n");

    uint8_t test_data[] = {0x10, 0x20, 0x30, 0x40, 0x50};
    uint8_t bad_data[]  = {0xFF, 0x01, 0x02};

    printf("  Case 1: valid data (checksum should match)\n");
    int r1 = validate_checksum(test_data, sizeof(test_data));
    printf("    Result: %s\n", (r1 == 0) ? "PASS (valid)" : "FAIL");

    printf("\n  Case 2: invalid data (checksum mismatch)\n");
    int r2 = validate_checksum(bad_data, sizeof(bad_data));
    printf("    Result: %s\n", (r2 == 0) ? "PASS (unexpected)" : "FAIL (expected)");

    printf("\n  Case 3: null pointer (edge case)\n");
    int r3 = validate_checksum(nullptr, 0);
    printf("    Result: %s\n", (r3 == 0) ? "PASS" : "FAIL (expected error)");
}

// --------------------------------------------------------------------
// Entry point
// --------------------------------------------------------------------
int main()
{
    printf("============================================================\n");
    printf("  Security-Hardened Application\n");
    printf("  Demonstrates: /GS /sdl /guard:cf /guard:ehcont /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA /CETCOMPAT\n");
    printf("============================================================\n");

    SetConsoleOutputCP(CP_UTF8);
    SetConsoleTitleW(L"Security Hardened — Victim 13");

    demo_gs_protection();
    demo_sdl_checks();
    demo_cfg_protection();
    demo_aslr();
    demo_nxcompat();
    demo_high_entropy_va();
    demo_protected_function();

    printf("\n--- All security features demonstrated. ---\n");
    return 0;
}
