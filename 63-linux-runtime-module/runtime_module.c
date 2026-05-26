#include <stdint.h>

__attribute__((visibility("default"))) uint32_t linux_runtime_probe(uint32_t seed) {
    return (seed * 33u) ^ 0x4C524D31u;
}
