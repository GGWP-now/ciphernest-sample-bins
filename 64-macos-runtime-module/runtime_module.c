#include <stdint.h>

__attribute__((visibility("default"))) uint32_t macos_runtime_probe(uint32_t seed) {
    return (seed * 33u) ^ 0x4D524D31u;
}
