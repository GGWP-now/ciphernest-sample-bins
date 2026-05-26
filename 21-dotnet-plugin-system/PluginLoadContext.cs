using System.Reflection;
using System.Runtime.Loader;

namespace PluginSystem;

/// <summary>
/// Collectible AssemblyLoadContext that falls back to the default context
/// for assemblies already loaded there — this lets the host share IPlugin type identity
/// with dynamically-loaded plugins.
/// </summary>
public sealed class PluginLoadContext : AssemblyLoadContext
{
    public PluginLoadContext() : base(isCollectible: true)
    {
    }

    protected override Assembly? Load(AssemblyName assemblyName)
    {
        // Resolve from default context so shared types (IPlugin) unify identity,
        // enabling direct casting instead of reflection-based invocation.
        try
        {
            return Assembly.Load(assemblyName);
        }
        catch
        {
            return null;
        }
    }
}
