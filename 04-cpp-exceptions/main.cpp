// C++ Exceptions / RTTI / Virtual / Destructors / STL Demo
// Compile: MSVC /EHsc /GR /O2

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <map>
#include <new>
#include <stdexcept>
#include <string>
#include <typeinfo>
#include <vector>

// ============================================================
// RAII helper – prints acquire/release
// ============================================================
class FileGuard {
    const char* name_;
public:
    explicit FileGuard(const char* name) noexcept
        : name_(name)
    {
        std::printf("[FileGuard] acquired: %s\n", name_);
    }
    ~FileGuard() noexcept
    {
        std::printf("[FileGuard] released: %s\n", name_);
    }
    FileGuard(const FileGuard&) = delete;
    FileGuard& operator=(const FileGuard&) = delete;
};

// ============================================================
// Virtual class hierarchy for RTTI + exception demo
// ============================================================
class Base {
public:
    virtual ~Base() = default;
    virtual const char* name() const = 0;
};

class DerivedA : public Base {
public:
    ~DerivedA() noexcept override
    {
        std::printf("[dtor] DerivedA destroyed\n");
    }
    const char* name() const override { return "DerivedA"; }
};

class DerivedB : public Base {
public:
    ~DerivedB() noexcept override
    {
        std::printf("[dtor] DerivedB destroyed\n");
    }
    const char* name() const override { return "DerivedB"; }
};

// ============================================================
// Test 1: try / catch with class hierarchy
// ============================================================
static void thrower(int which)
{
    if (which == 0) {
        std::printf("  -> throwing std::runtime_error\n");
        throw std::runtime_error("runtime error from thrower(0)");
    }
    if (which == 1) {
        std::printf("  -> throwing std::out_of_range\n");
        throw std::out_of_range("out_of_range from thrower(1)");
    }
    std::printf("  -> argument %d – no exception thrown\n", which);
}

// ============================================================
// Test 2: RTTI – dynamic_cast + typeid
// ============================================================
static void rtti_demo()
{
    std::vector<Base*> objects;
    objects.push_back(new DerivedA());
    objects.push_back(new DerivedB());
    objects.push_back(new DerivedA());
    objects.push_back(new DerivedB());

    for (size_t i = 0; i < objects.size(); ++i) {
        const char* dynamic = "unknown";
        if (dynamic_cast<DerivedA*>(objects[i]))
            dynamic = "DerivedA (via dynamic_cast)";
        else if (dynamic_cast<DerivedB*>(objects[i]))
            dynamic = "DerivedB (via dynamic_cast)";

        std::printf("  objects[%zu]: virtual name=\"%s\", typeid=%s, %s\n",
                    i, objects[i]->name(), typeid(*objects[i]).name(), dynamic);
    }

    for (size_t i = 0; i < objects.size(); ++i)
        delete objects[i];
    objects.clear();
}

// ============================================================
// Test 3: STL containers
// ============================================================
static void stl_demo()
{
    // -- std::vector<int> --
    std::vector<int> vec;
    vec.push_back(10);
    vec.push_back(20);
    vec.push_back(30);
    vec.push_back(40);
    std::printf("  vector after pushes:");
    for (size_t i = 0; i < vec.size(); ++i)
        std::printf(" %d", vec[i]);
    std::printf("\n");

    // erase element at index 1 (value 20)
    vec.erase(vec.begin() + 1);
    std::printf("  vector after erase(vec.begin()+1):");
    for (int v : vec)
        std::printf(" %d", v);
    std::printf("\n");

    // -- std::map<std::string, int> --
    std::map<std::string, int> scores;
    scores["alpha"]   = 100;
    scores["beta"]    = 200;
    scores["gamma"]   = 300;
    std::printf("  map contents:\n");
    for (auto const& kv : scores)
        std::printf("    scores[\"%s\"] = %d\n", kv.first.c_str(), kv.second);

    auto it = scores.find("beta");
    if (it != scores.end())
        std::printf("  map.find(\"beta\") -> %d\n", it->second);

    scores.erase("alpha");
    std::printf("  map after erase(\"alpha\"): size=%zu\n", scores.size());

    // -- std::string operations --
    std::string greeting = "Hello";
    greeting.push_back('!');
    greeting += " C++17";
    std::printf("  string: \"%s\" (length=%zu)\n", greeting.c_str(), greeting.size());

    size_t pos = greeting.find("C++");
    if (pos != std::string::npos)
        std::printf("  string.find(\"C++\") -> position %zu\n", pos);
}

// ============================================================
// Test 4: destructor ordering in nested scopes
// ============================================================
struct Tracker {
    int id;
    explicit Tracker(int id_) noexcept : id(id_)
    {
        std::printf("  [Tracker]  ctor id=%d\n", id);
    }
    ~Tracker() noexcept
    {
        std::printf("  [Tracker]  dtor id=%d\n", id);
    }
    Tracker(const Tracker&) = delete;
    Tracker& operator=(const Tracker&) = delete;
};

static void scope_demo()
{
    std::printf("  Entering outer block\n");
    Tracker t1(1);
    {
        std::printf("  Entering middle block\n");
        Tracker t2(2);
        {
            std::printf("  Entering inner block\n");
            Tracker t3(3);
            std::printf("  Leaving inner block\n");
        }
        std::printf("  Leaving middle block\n");
    }
    std::printf("  Leaving outer block\n");
}

// ============================================================
// Test 5: RAII FileGuard
// ============================================================
static void raii_demo()
{
    std::printf("  Acquiring resources in reverse order\n");
    FileGuard log("log.txt");
    {
        FileGuard cfg("config.ini");
        {
            FileGuard dat("data.bin");
            std::printf("  Inside deepest scope – all guards alive\n");
        }
        std::printf("  data.bin should be released now\n");
    }
    std::printf("  config.ini should be released now\n");
}

// ============================================================
// main
// ============================================================
int main()
{
    // ---- Test 1: try/catch with std::runtime_error and std::out_of_range ----
    std::printf("=== Test 1: try/catch ===\n");
    {
        DerivedA d;
        Base* pb = &d;
        std::printf("  Base pointer holds a %s, vtable offset check\n", pb->name());
    }
    for (int i = 0; i <= 2; ++i) {
        try {
            thrower(i);
        } catch (const std::out_of_range& ex) {
            std::printf("  Caught std::out_of_range: \"%s\"\n", ex.what());
        } catch (const std::runtime_error& ex) {
            std::printf("  Caught std::runtime_error: \"%s\"\n", ex.what());
        } catch (const std::exception& ex) {
            std::printf("  Caught std::exception: \"%s\"\n", ex.what());
        }
    }

    // ---- Test 2: RTTI ----
    std::printf("\n=== Test 2: RTTI (dynamic_cast + typeid) ===\n");
    rtti_demo();

    // ---- Test 3: STL containers ----
    std::printf("\n=== Test 3: STL containers ===\n");
    stl_demo();

    // ---- Test 4: destructor ordering ----
    std::printf("\n=== Test 4: Destructor ordering (reverse construction) ===\n");
    scope_demo();

    // ---- Test 5: RAII FileGuard ----
    std::printf("\n=== Test 5: RAII FileGuard ===\n");
    raii_demo();

    // ---- summary ----
    std::printf("\nAll C++ exception/RTTI/virtual/destructor/STL tests completed.\n");
    return 0;
}
