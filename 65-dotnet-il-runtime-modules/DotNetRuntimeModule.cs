using System;

namespace Protector.Victims.RuntimeModules
{
    public sealed class DotNetRuntimeModule
    {
        private DotNetRuntimeModule()
        {
        }

        public static int Probe(int seed)
        {
            unchecked
            {
                return (seed * 33) ^ 0x444E4554;
            }
        }

        public static string Name()
        {
            return "dotnet-runtime-module";
        }
    }
}
