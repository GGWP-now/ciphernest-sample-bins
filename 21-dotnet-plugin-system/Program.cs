using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.Loader;

namespace PluginSystem;

class Program
{
    // ------------------------------------------------------------------
    // Weak-reference triplet returned from the isolated scope.
    // ------------------------------------------------------------------
    sealed record UnloadProbe(
        WeakReference AlcRef,
        WeakReference AssemblyRef,
        WeakReference InstanceRef);

    // ------------------------------------------------------------------
    // Entry point
    // ------------------------------------------------------------------
    static void Main()
    {
        Console.WriteLine("=== Plugin Isolation Demo (AssemblyLoadContext) ===\n");

        string pluginPath = EmitPluginAssembly();
        Console.WriteLine($"Plugin emitted to: {pluginPath}\n");

        var probe = LoadExecuteAndUnload(pluginPath);

        Console.WriteLine("\nForcing garbage collection...");
        GC.Collect();
        GC.WaitForPendingFinalizers();
        GC.Collect();

        Console.WriteLine($"ALC alive:       {probe.AlcRef.IsAlive}");
        Console.WriteLine($"Assembly alive:  {probe.AssemblyRef.IsAlive}");
        Console.WriteLine($"Instance alive:  {probe.InstanceRef.IsAlive}");

        bool ok = !probe.AlcRef.IsAlive
               && !probe.AssemblyRef.IsAlive
               && !probe.InstanceRef.IsAlive;

        Console.WriteLine($"\nPlugin fully unloaded: {(ok ? "YES  /" : "NO  X")}");

        // Best-effort cleanup of the temp directory
        try
        {
            File.Delete(pluginPath);
            Directory.Delete(Path.GetDirectoryName(pluginPath)!, recursive: true);
        }
        catch { /* best effort */ }

        Console.WriteLine("\n=== Demo complete ===");
    }

    // ------------------------------------------------------------------
    // 1. Emit a plugin assembly with Reflection.Emit
    // ------------------------------------------------------------------
    static string EmitPluginAssembly()
    {
        var asmName = new AssemblyName("DynamicPlugin");
        var asmBld = new PersistedAssemblyBuilder(
            asmName, typeof(object).Assembly);
        var modBld = asmBld.DefineDynamicModule("DynamicPlugin");

        var tb = modBld.DefineType(
            "DynamicPlugin",
            TypeAttributes.Public | TypeAttributes.Class);

        // --- Mark as implementing IPlugin ---
        tb.AddInterfaceImplementation(typeof(IPlugin));

        // Backing field for Name property
        var nameField = tb.DefineField(
            "_name",
            typeof(string),
            FieldAttributes.Private | FieldAttributes.InitOnly);

        // --- Constructor: .ctor(string name) ---
        var ctor = tb.DefineConstructor(
            MethodAttributes.Public,
            CallingConventions.Standard,
            [typeof(string)]);

        var cil = ctor.GetILGenerator();
        cil.Emit(OpCodes.Ldarg_0);
        cil.Emit(OpCodes.Call, typeof(object).GetConstructor(Type.EmptyTypes)!);
        cil.Emit(OpCodes.Ldarg_0);
        cil.Emit(OpCodes.Ldarg_1);
        cil.Emit(OpCodes.Stfld, nameField);
        cil.Emit(OpCodes.Ret);

        // --- Property: string Name { get; } ---
        var getName = tb.DefineMethod(
            "get_Name",
            MethodAttributes.Public | MethodAttributes.Virtual | MethodAttributes.NewSlot,
            typeof(string),
            Type.EmptyTypes);

        cil = getName.GetILGenerator();
        cil.Emit(OpCodes.Ldarg_0);
        cil.Emit(OpCodes.Ldfld, nameField);
        cil.Emit(OpCodes.Ret);

        // --- Method: void Execute() ---
        var exec = tb.DefineMethod(
            "Execute",
            MethodAttributes.Public | MethodAttributes.Virtual | MethodAttributes.NewSlot,
            typeof(void),
            Type.EmptyTypes);

        cil = exec.GetILGenerator();
        cil.Emit(OpCodes.Ldstr, "    [Plugin.Execute]  Greetings from the isolated plugin domain!");
        cil.Emit(OpCodes.Call,
            typeof(Console).GetMethod("WriteLine", [typeof(string)])!);
        cil.Emit(OpCodes.Ret);

        // Finalize the type and persist to bytes
        tb.CreateType();

        string dir = Path.Combine(
            Path.GetTempPath(),
            "PluginDemo_" + Guid.NewGuid().ToString("N"));

        Directory.CreateDirectory(dir);
        string path = Path.Combine(dir, "DynamicPlugin.dll");
        using (var fs = new FileStream(path, FileMode.Create, FileAccess.Write))
            asmBld.Save(fs);
        return path;
    }

    // ------------------------------------------------------------------
    // 2. Load the plugin in an isolated ALC, use it, then unload
    // ------------------------------------------------------------------
    static UnloadProbe LoadExecuteAndUnload(string pluginPath)
    {
        // All strong references live only inside this method.
        // Once it returns, nothing holds the ALC, assembly, or instance alive.

        var alc = new PluginLoadContext();
        var wrAlc = new WeakReference(alc, trackResurrection: true);

        var asm = alc.LoadFromAssemblyPath(pluginPath);
        var wrAsm = new WeakReference(asm, trackResurrection: true);

        var ty = asm.GetType("DynamicPlugin")
            ?? throw new InvalidOperationException("Type DynamicPlugin not found");

        var plugin = (IPlugin)Activator.CreateInstance(ty, "DemoPlugin")!;
        var wrPlugin = new WeakReference(plugin, trackResurrection: true);

        Console.WriteLine($"Plugin name:    {plugin.Name}");
        plugin.Execute();

        // Unload the context — all plugin-derived objects become
        // unreachable once the method's locals evaporate.
        alc.Unload();
        Console.WriteLine("AssemblyLoadContext.Unload() called.");

        return new UnloadProbe(wrAlc, wrAsm, wrPlugin);
    }
}
