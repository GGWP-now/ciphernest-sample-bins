#include "macos_shared.h"

int macos_shared_add(int left, int right) {
    return left + right;
}

unsigned int macos_shared_checksum(const char *text) {
    unsigned int hash = 0x811C9DC5u;
    if (!text) {
        return hash;
    }
    while (*text) {
        hash ^= (unsigned char)*text++;
        hash *= 0x01000193u;
    }
    return hash;
}

const char *macos_shared_version(void) {
    return "macos_shared/1.0";
}
