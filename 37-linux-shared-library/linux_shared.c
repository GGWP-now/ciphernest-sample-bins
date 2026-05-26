#include "linux_shared.h"

int linux_shared_add(int left, int right) {
    return left + right;
}

unsigned int linux_shared_checksum(const char *text) {
    unsigned int hash = 5381u;
    if (!text) {
        return hash;
    }
    while (*text) {
        hash = ((hash << 5) + hash) ^ (unsigned char)*text++;
    }
    return hash;
}

const char *linux_shared_version(void) {
    return "linux_shared/1.0";
}
