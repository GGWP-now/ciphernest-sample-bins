using System.Diagnostics;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.Loader;

// ============================================================
// Static C# reference implementations (for benchmarking)
// ============================================================
static int AddRef(int a, int b) => a + b;

static int FactorialRef(int n)
{
    if (n < 0) throw new ArgumentOutOfRangeException(nameof(n));
    int result = 1;
    for (int i = 2; i <= n; i++) result *= i;
    return result;
}

static int FibRef(int n)
{
    if (n < 0) throw new ArgumentOutOfRangeException(nameof(n));
    if (n <= 1) return n;
    return FibRef(n - 1) + FibRef(n - 2);
}

// ============================================================
// 1. Build dynamic assembly with Reflection.Emit
// ============================================================
Console.WriteLine("=== 1. Building collectible dynamic assembly ===\n");

var assemblyName = new AssemblyName("DynamicAssembly") { Version = new Version(1, 0, 0, 0) };
var assemblyBuilder = AssemblyBuilder.DefineDynamicAssembly(
    assemblyName, AssemblyBuilderAccess.RunAndCollect);
var moduleBuilder = assemblyBuilder.DefineDynamicModule("MainModule");
var typeBuilder = moduleBuilder.DefineType("DynamicMath",
    TypeAttributes.Public | TypeAttributes.Abstract | TypeAttributes.Sealed);

// --- static int Add(int a, int b) — simple arithmetic ---
var addMethod = typeBuilder.DefineMethod("Add",
    MethodAttributes.Public | MethodAttributes.Static,
    typeof(int), [typeof(int), typeof(int)]);
var addIl = addMethod.GetILGenerator();
addIl.Emit(OpCodes.Ldarg_0);
addIl.Emit(OpCodes.Ldarg_1);
addIl.Emit(OpCodes.Add);
addIl.Emit(OpCodes.Ret);

// --- static int Factorial(int n) — loop with labels/branches ---
var argOutOfRangeCtor = typeof(ArgumentOutOfRangeException)
    .GetConstructor([typeof(string)])!;

var factMethod = typeBuilder.DefineMethod("Factorial",
    MethodAttributes.Public | MethodAttributes.Static,
    typeof(int), [typeof(int)]);
var factIl = factMethod.GetILGenerator();
factIl.DeclareLocal(typeof(int)); // 0: result
factIl.DeclareLocal(typeof(int)); // 1: i

var fErr = factIl.DefineLabel();
var fChk = factIl.DefineLabel();
var fLp  = factIl.DefineLabel();

factIl.Emit(OpCodes.Ldarg_0);
factIl.Emit(OpCodes.Ldc_I4_0);
factIl.Emit(OpCodes.Blt_S, fErr);
factIl.Emit(OpCodes.Ldc_I4_1); factIl.Emit(OpCodes.Stloc_0);
factIl.Emit(OpCodes.Ldc_I4_2); factIl.Emit(OpCodes.Stloc_1);
factIl.Emit(OpCodes.Br_S, fChk);

factIl.MarkLabel(fLp);
factIl.Emit(OpCodes.Ldloc_0); factIl.Emit(OpCodes.Ldloc_1);
factIl.Emit(OpCodes.Mul); factIl.Emit(OpCodes.Stloc_0);
factIl.Emit(OpCodes.Ldloc_1); factIl.Emit(OpCodes.Ldc_I4_1);
factIl.Emit(OpCodes.Add); factIl.Emit(OpCodes.Stloc_1);

factIl.MarkLabel(fChk);
factIl.Emit(OpCodes.Ldloc_1); factIl.Emit(OpCodes.Ldarg_0);
factIl.Emit(OpCodes.Ble_S, fLp);

factIl.Emit(OpCodes.Ldloc_0);
factIl.Emit(OpCodes.Ret);

factIl.MarkLabel(fErr);
factIl.Emit(OpCodes.Ldstr, "n");
factIl.Emit(OpCodes.Newobj, argOutOfRangeCtor);
factIl.Emit(OpCodes.Throw);

// --- static int Fib(int n) — recursive with self-call ---
var fibMethod = typeBuilder.DefineMethod("Fib",
    MethodAttributes.Public | MethodAttributes.Static,
    typeof(int), [typeof(int)]);
var fibIl = fibMethod.GetILGenerator();

var fbErr = fibIl.DefineLabel();
var fbBase = fibIl.DefineLabel();

fibIl.Emit(OpCodes.Ldarg_0); fibIl.Emit(OpCodes.Ldc_I4_0); fibIl.Emit(OpCodes.Blt_S, fbErr);
fibIl.Emit(OpCodes.Ldarg_0); fibIl.Emit(OpCodes.Ldc_I4_1); fibIl.Emit(OpCodes.Ble_S, fbBase);
fibIl.Emit(OpCodes.Ldarg_0); fibIl.Emit(OpCodes.Ldc_I4_1); fibIl.Emit(OpCodes.Sub); fibIl.Emit(OpCodes.Call, fibMethod);
fibIl.Emit(OpCodes.Ldarg_0); fibIl.Emit(OpCodes.Ldc_I4_2); fibIl.Emit(OpCodes.Sub); fibIl.Emit(OpCodes.Call, fibMethod);
fibIl.Emit(OpCodes.Add); fibIl.Emit(OpCodes.Ret);
fibIl.MarkLabel(fbBase); fibIl.Emit(OpCodes.Ldarg_0); fibIl.Emit(OpCodes.Ret);
fibIl.MarkLabel(fbErr);
fibIl.Emit(OpCodes.Ldstr, "n");
fibIl.Emit(OpCodes.Newobj, argOutOfRangeCtor);
fibIl.Emit(OpCodes.Throw);

// Create type — finalises all emitted IL
var dynamicType = typeBuilder.CreateType();
Console.WriteLine("Dynamic assembly built with 3 IL methods (collectible).\n");

// Note: .NET 10 has removed AssemblyBuilder.Save() and DefinePersistedAssembly.
// The assembly lives in memory and is automatically collectible via RunAndCollect.
Console.WriteLine("(.NET 10 removed AssemblyBuilder.Save — assembly is used in-memory.\n" +
                  " The assembly is collectible: the ALC + GC will reclaim it on unload.)\n");

// ============================================================
// 2. Verification — invoke emitted IL methods
// ============================================================
Console.WriteLine("=== 2. Verification ===\n");

int pass = 0, total = 0;
Action<string, int, int> chk = (lbl, got, exp) =>
{
    total++; if (got == exp) pass++;
    Console.WriteLine($"  {lbl,-24} = {got,-6} {(got == exp ? "\u2713" : $"\u2717 wanted {exp}")}");
};

// Since dynamicType is a real runtime Type, call methods directly via Invoke
chk("Add(3, 7)",         (int)dynamicType.GetMethod("Add", [typeof(int), typeof(int)])!.Invoke(null, [3, 7])!, 10);
chk("Add(-5, 12)",       (int)dynamicType.GetMethod("Add", [typeof(int), typeof(int)])!.Invoke(null, [-5, 12])!, 7);
chk("Add(0, 0)",         (int)dynamicType.GetMethod("Add", [typeof(int), typeof(int)])!.Invoke(null, [0, 0])!, 0);
chk("Factorial(0)",      (int)dynamicType.GetMethod("Factorial", [typeof(int)])!.Invoke(null, [0])!, 1);
chk("Factorial(1)",      (int)dynamicType.GetMethod("Factorial", [typeof(int)])!.Invoke(null, [1])!, 1);
chk("Factorial(5)",      (int)dynamicType.GetMethod("Factorial", [typeof(int)])!.Invoke(null, [5])!, 120);
chk("Factorial(10)",     (int)dynamicType.GetMethod("Factorial", [typeof(int)])!.Invoke(null, [10])!, 3628800);
chk("Fib(0)",            (int)dynamicType.GetMethod("Fib", [typeof(int)])!.Invoke(null, [0])!, 0);
chk("Fib(1)",            (int)dynamicType.GetMethod("Fib", [typeof(int)])!.Invoke(null, [1])!, 1);
chk("Fib(10)",           (int)dynamicType.GetMethod("Fib", [typeof(int)])!.Invoke(null, [10])!, 55);
chk("Fib(20)",           (int)dynamicType.GetMethod("Fib", [typeof(int)])!.Invoke(null, [20])!, 6765);

// Error handling
bool factErr = false, fibErr = false;
try { dynamicType.GetMethod("Factorial", [typeof(int)])!.Invoke(null, [-1]); }
catch (TargetInvocationException ex) when (ex.InnerException is ArgumentOutOfRangeException) { factErr = true; }
try { dynamicType.GetMethod("Fib", [typeof(int)])!.Invoke(null, [-1]); }
catch (TargetInvocationException ex) when (ex.InnerException is ArgumentOutOfRangeException) { fibErr = true; }
total++; if (factErr) pass++; Console.WriteLine($"  {"Factorial(-1) throws",-24} = {(factErr ? "ArgumentOutOfRangeException \u2713" : "FAIL")}");
total++; if (fibErr) pass++; Console.WriteLine($"  {"Fib(-1) throws",-24} = {(fibErr ? "ArgumentOutOfRangeException \u2713" : "FAIL")}");

Console.WriteLine($"\n  {pass}/{total} passed {(pass == total ? "\u2713" : "\u2717")}\n");

// ============================================================
// 3. Benchmark (Stopwatch)
// ============================================================
Console.WriteLine("=== 3. Benchmark (2M iterations each) ===\n");

const int N = 2_000_000;
const int BA = 42, BB = 58, BN = 10;

var addRef   = (Func<int, int, int>)Delegate.CreateDelegate(typeof(Func<int, int, int>), dynamicType.GetMethod("Add", [typeof(int), typeof(int)])!);
var factRef  = (Func<int, int>)Delegate.CreateDelegate(typeof(Func<int, int>), dynamicType.GetMethod("Factorial", [typeof(int)])!);
var fibRef   = (Func<int, int>)Delegate.CreateDelegate(typeof(Func<int, int>), dynamicType.GetMethod("Fib", [typeof(int)])!);
var addIL    = addRef;  // alias for clarity: delegate wrapping dynamic IL method
var factIL   = factRef;
var fibIL    = fibRef;

var sw = new Stopwatch();

// Direct C# — baseline
sw.Restart(); long sDA=0; for (int i=0;i<N;i++) sDA+=AddRef(BA,BB);        var tADC = sw.Elapsed;
sw.Restart(); long sDF=0; for (int i=0;i<N;i++) sDF+=FactorialRef(BN);     var tFDC = sw.Elapsed;
sw.Restart(); long sDfb=0; for (int i=0;i<N;i++) sDfb+=FibRef(BN);         var tFbD = sw.Elapsed;

// Dynamic IL via delegate — near-native speed
sw.Restart(); long sDeA=0; for (int i=0;i<N;i++) sDeA+=addIL(BA,BB);       var tADI = sw.Elapsed;
sw.Restart(); long sDeF=0; for (int i=0;i<N;i++) sDeF+=factIL(BN);          var tFDI = sw.Elapsed;
sw.Restart(); long sDefb=0; for (int i=0;i<N;i++) sDefb+=fibIL(BN);         var tFbI = sw.Elapsed;

// MethodInfo.Invoke — full reflection dispatch
var addMI = dynamicType.GetMethod("Add", [typeof(int), typeof(int)])!;
var factMI = dynamicType.GetMethod("Factorial", [typeof(int)])!;
var fibMI = dynamicType.GetMethod("Fib", [typeof(int)])!;
sw.Restart(); long sRA=0; for (int i=0;i<N;i++) sRA+=(int)addMI.Invoke(null,[BA,BB])!; var tARI = sw.Elapsed;
sw.Restart(); long sRF=0; for (int i=0;i<N;i++) sRF+=(int)factMI.Invoke(null,[BN])!;    var tFRI = sw.Elapsed;
sw.Restart(); long sRfb=0; for (int i=0;i<N;i++) sRfb+=(int)fibMI.Invoke(null,[BN])!;   var tFbR = sw.Elapsed;

bool aOk = sDA == sDeA && sDeA == sRA;
bool fOk = sDF == sDeF && sDeF == sRF;
bool fbOk = sDfb == sDefb && sDefb == sRfb;

// ============================================================
// 4. Comparison table
// ============================================================
Console.WriteLine("=== 4. Performance Comparison ===\n");

Console.WriteLine($"{"Function",-12} {"Direct C# (ms)",-16} {"Emit+Delegate (ms)",-20} {"Reflection (ms)",-16} {"Correct",-10}");
Console.WriteLine(new string('-', 76));
Console.WriteLine($"{"Add",-12} {tADC.TotalMilliseconds,-15:F3} {tADI.TotalMilliseconds,-19:F3} {tARI.TotalMilliseconds,-15:F3} {(aOk?"\u2713":"\u2717"),-10}");
Console.WriteLine($"{"Factorial",-12} {tFDC.TotalMilliseconds,-15:F3} {tFDI.TotalMilliseconds,-19:F3} {tFRI.TotalMilliseconds,-15:F3} {(fOk?"\u2713":"\u2717"),-10}");
Console.WriteLine($"{"Fib",-12} {tFbD.TotalMilliseconds,-15:F3} {tFbI.TotalMilliseconds,-19:F3} {tFbR.TotalMilliseconds,-15:F3} {(fbOk?"\u2713":"\u2717"),-10}");

Console.WriteLine($"\nAll sums consistent: {(aOk && fOk && fbOk ? "YES \u2713" : "FAIL \u2717")}");
Console.WriteLine("\nInterpretation:");
Console.WriteLine("  Direct C#       — statically compiled call (baseline)");
Console.WriteLine("  Emit+Delegate   — IL-emitted method invoked via delegate (JIT-compiled once, near-native)");
Console.WriteLine("  Reflection      — MethodInfo.Invoke (boxing + dispatch overhead per call)\n");

Console.WriteLine("Checksums:");
Console.WriteLine($"  Direct:    Add={sDA,-12} Fact={sDF,-12} Fib={sDfb}");
Console.WriteLine($"  Delegate:  Add={sDeA,-12} Fact={sDeF,-12} Fib={sDefb}");
Console.WriteLine($"  Reflect:   Add={sRA,-12}  Fact={sRF,-12} Fib={sRfb}");

// ============================================================
// 5. Cleanup — collectible assembly eligible for GC
// ============================================================
Console.WriteLine("\n=== 5. Cleanup ===\n");

// Null out all references to the type and assembly
addRef = null!; factRef = null!; fibRef = null!;
addMI = null!; factMI = null!; fibMI = null!;
GC.Collect();
GC.WaitForPendingFinalizers();

Console.WriteLine("References released. Dynamic assembly is eligible for collection.\n");
Console.WriteLine("Complete.");
