#include "win_shared.h"

int win_shared_add(int left, int right) {
    return left + right;
}

unsigned int win_shared_checksum(const char *text) {
    unsigned int hash = 2166136261u;
    if (!text) {
        return hash;
    }
    while (*text) {
        hash ^= (unsigned char)*text++;
        hash *= 16777619u;
    }
    return hash;
}

const char *win_shared_version(void) {
    return "win_shared/1.0";
}
