#include <ntddk.h>

ULONG DriverRuntimeProbe(ULONG seed) {
    return (seed * 33u) ^ 0x44525631u;
}
