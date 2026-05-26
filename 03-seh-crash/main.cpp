// SEH Test Harness
// Demonstrates Structured Exception Handling behavior with __try/__except.
// Test 1: Null pointer dereference (access violation)
// Test 2: Integer divide-by-zero
// Test 3: Recursive stack overflow
// Test 4: Normal execution path (no exception)

#include <windows.h>
#include <excpt.h>
#include <stdio.h>
#include <malloc.h>    // for _resetstkoflw after stack overflow

// ---------------------------------------------------------------------------
// Filter function called by __except filter expressions.
// Uses both GetExceptionCode and GetExceptionInformation as required.
// Returns EXCEPTION_EXECUTE_HANDLER for known hardware exceptions, or
// EXCEPTION_CONTINUE_SEARCH for unknown codes.
// ---------------------------------------------------------------------------
static int seh_filter(
    unsigned int code,
    struct _EXCEPTION_POINTERS *ep,
    const char **out_reason)
{
    // Use GetExceptionCode value AND the exception record from
    // GetExceptionInformation to classify the fault.
    PEXCEPTION_RECORD er = ep->ExceptionRecord;

    // Cross-validate that both sources agree (belt-and-suspenders).
    if (code != er->ExceptionCode) {
        *out_reason = "FILTER_MISMATCH";
        return EXCEPTION_CONTINUE_SEARCH;
    }

    switch (code) {
    case EXCEPTION_ACCESS_VIOLATION:
        // Access violation -- read or write to invalid address.
        // The exception record's NumberParameters[0] indicates type:
        //   0 = read, 1 = write
        // NumberParameters[1] holds the faulting address.
        *out_reason = "ACCESS_VIOLATION";
        return EXCEPTION_EXECUTE_HANDLER;

    case EXCEPTION_INT_DIVIDE_BY_ZERO:
        *out_reason = "INT_DIVIDE_BY_ZERO";
        return EXCEPTION_EXECUTE_HANDLER;

    case EXCEPTION_STACK_OVERFLOW:
        *out_reason = "STACK_OVERFLOW";
        return EXCEPTION_EXECUTE_HANDLER;

    case EXCEPTION_FLT_DIVIDE_BY_ZERO:
        *out_reason = "FLT_DIVIDE_BY_ZERO";
        return EXCEPTION_EXECUTE_HANDLER;

    default:
        // For any unexpected code, let the OS search for another handler.
        *out_reason = "UNKNOWN";
        return EXCEPTION_CONTINUE_SEARCH;
    }
}

// ---------------------------------------------------------------------------
// Recursive function that exhausts the stack.
// Touches a local buffer at each call to ensure real stack frames grow.
// ---------------------------------------------------------------------------
__declspec(noinline) static void stack_recurse(void)
{
    // Volatile prevents this from being optimized away.
    volatile char buf[4096];
    buf[0] = 0xCD;
    (void)buf[0];
    stack_recurse(); // tail recursion -- will overflow eventually
}

// ============================= Test cases =================================

static int test_access_violation(void)
{
    const char *reason = NULL;
    printf("Running test 1...\n");

    __try
    {
        // Intentional null-pointer dereference (write to address 0).
        volatile int *p = NULL;
        *p = 42;
    }
    __except (seh_filter(GetExceptionCode(),
                          GetExceptionInformation(),
                          &reason))
    {
        printf("Caught exception: %s\n", reason);
        return 1;
    }

    // If we get here, something went wrong -- SEH should have caught it.
    printf("Caught exception: unexpected no-exception\n");
    return 0;
}

static int test_divide_by_zero(void)
{
    const char *reason = NULL;
    printf("Running test 2...\n");

    __try
    {
        volatile int zero = 0;
        int result = 100 / zero;
        (void)result;
    }
    __except (seh_filter(GetExceptionCode(),
                          GetExceptionInformation(),
                          &reason))
    {
        printf("Caught exception: %s\n", reason);
        return 1;
    }

    printf("Caught exception: unexpected no-exception\n");
    return 0;
}

static int test_stack_overflow(void)
{
    const char *reason = NULL;
    printf("Running test 3...\n");

    __try
    {
        stack_recurse();
    }
    __except (seh_filter(GetExceptionCode(),
                          GetExceptionInformation(),
                          &reason))
    {
        printf("Caught exception: %s\n", reason);
        // The stack is corrupted after an overflow; reset it.
        _resetstkoflw();
        return 1;
    }

    printf("Caught exception: unexpected no-exception\n");
    return 0;
}

static int test_normal_execution(void)
{
    printf("Running test 4...\n");

    __try
    {
        // Normal work that should never raise an SEH.
        int x = 42;
        int y = x * x;
        (void)y;
    }
    __except (EXCEPTION_EXECUTE_HANDLER)
    {
        printf("Caught exception: unexpected\n");
        return 0;
    }

    printf("Caught exception: none\n");
    return 1;
}

// ==========================================================================

int main(void)
{
    int passed = 0;
    const int total = 4;

    passed += test_access_violation();
    passed += test_divide_by_zero();
    passed += test_stack_overflow();
    passed += test_normal_execution();

    printf("\n%d/%d tests passed\n", passed, total);
    return (passed == total) ? 0 : 1;
}
