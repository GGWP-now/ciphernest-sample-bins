// CFG Testbed -- demonstrates indirect call patterns that
// Control Flow Guard (CFG) protects on MSVC with /guard:cf.
//
// Build:
//   cmake -B build && cmake --build build
//
// All five indirect call categories are exercised below with
// clear section headers.

#include <cstdio>
#include <cstdlib>
#include <functional>

// ============================================================
// 1. Function pointer table
// ============================================================

static int add(int a, int b) noexcept { return a + b; }
static int sub(int a, int b) noexcept { return a - b; }
static int mul(int a, int b) noexcept { return a * b; }
static int divide(int a, int b) noexcept {
    return b != 0 ? a / b : 0;
}

using OpFn = int(int, int);

void demo_function_pointers() {
    OpFn *const table[4] = {add, sub, mul, divide};
    const char *const names[4] = {"add", "sub", "mul", "div"};

    for (int i = 0; i < 4; ++i) {
        // Indirect call through function pointer -- CFG target.
        int r = table[i](10, 3);
        std::printf("  %s(10, 3) = %d\n", names[i], r);
    }
}

// ============================================================
// 2. Virtual calls
// ============================================================

struct IOp {
    virtual ~IOp() = default;
    virtual int eval(int a, int b) = 0;
};

struct AddOp final : IOp {
    int eval(int a, int b) override { return a + b; }
};

struct SubOp final : IOp {
    int eval(int a, int b) override { return a - b; }
};

struct MulOp final : IOp {
    int eval(int a, int b) override { return a * b; }
};

void demo_virtual_calls() {
    AddOp a_op;
    SubOp s_op;
    MulOp m_op;

    IOp *ptrs[3] = {&a_op, &s_op, &m_op};
    const char *names[3] = {"AddOp", "SubOp", "MulOp"};

    for (int i = 0; i < 3; ++i) {
        // Virtual dispatch through vtable -- CFG target.
        int r = ptrs[i]->eval(10, 3);
        std::printf("  %s::eval(10, 3) = %d\n", names[i], r);
    }
}

// ============================================================
// 3. Jump table simulation (compiler likely emits a jump table)
// ============================================================

static int jump_fn(int op, int a, int b) noexcept {
    // A large switch that MSVC typically lowers to a jump table.
    switch (op) {
    case 0:  return a + b;
    case 1:  return a - b;
    case 2:  return a * b;
    case 3:  return b ? a / b : 0;
    case 4:  return a & b;
    case 5:  return a | b;
    case 6:  return a ^ b;
    case 7:  return a << 1;
    case 8:  return b >> 1;
    case 9:  return a + a + b;
    case 10: return a - b - b;
    case 11: return a * b + a;
    case 12: return (a + b) * (a - b);
    case 13: return ~a & b;
    case 14: return a | ~b;
    default: return 0;
    }
}

void demo_jump_table() {
    for (int op = 0; op <= 15; ++op) {
        int r = jump_fn(op, 10, 3);
        std::printf("  jump_fn(%2d, 10, 3) = %d\n", op, r);
    }
}

// ============================================================
// 4. Callback pattern
// ============================================================

void for_each(int *arr, int n, void (*cb)(int &)) noexcept {
    for (int i = 0; i < n; ++i) {
        cb(arr[i]);         // Indirect call through callback pointer
    }
}

static void negate_fn(int &x) noexcept { x = -x; }

void demo_callbacks() {
    int data[5] = {1, 2, 3, 4, 5};

    // Named function pointer
    for_each(data, 5, negate_fn);
    std::printf("  after negate_fn:");
    for (int i = 0; i < 5; ++i) std::printf(" %d", data[i]);
    std::putchar('\n');

    // Lambda converted to function pointer
    for_each(data, 5, [](int &x) noexcept { x = x * 3; });
    std::printf("  after lambda    :");
    for (int i = 0; i < 5; ++i) std::printf(" %d", data[i]);
    std::putchar('\n');
}

// ============================================================
// 5. std::function indirect call
// ============================================================

void demo_std_function() {
    std::function<void(int)> fns[3];

    fns[0] = [](int v) { std::printf("  lambda A: %d\n", v * 2); };
    fns[1] = [](int v) { std::printf("  lambda B: %d\n", v * v); };
    fns[2] = [](int v) { std::printf("  lambda C: %d\n", v - 1); };

    for (auto &f : fns) {
        f(7);  // Indirect call through std::function
    }
}

// ============================================================
// Entry point
// ============================================================

int main() {
    std::puts("=== Function Pointer Table ===");
    demo_function_pointers();

    std::puts("=== Virtual Calls ===");
    demo_virtual_calls();

    std::puts("=== Jump Table ===");
    demo_jump_table();

    std::puts("=== Callback Pattern ===");
    demo_callbacks();

    std::puts("=== std::function ===");
    demo_std_function();

    return 0;
}
