.assembly extern mscorlib {}
.assembly ILRuntimeModule {}
.module ILRuntimeModule.dll

.class public abstract sealed ILRuntimeModule
       extends [mscorlib]System.Object
{
  .method public hidebysig static int32 Probe(int32 seed) cil managed
  {
    .maxstack 2
    ldarg.0
    ldc.i4.s 33
    mul
    ldc.i4 0x494C4D31
    xor
    ret
  }
}
