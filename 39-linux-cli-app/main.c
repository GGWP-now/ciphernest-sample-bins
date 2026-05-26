#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned long checksum(unsigned int limit) {
    unsigned long hash = 1469598103934665603ull;
    for (unsigned int value = 1; value <= limit; ++value) {
        hash ^= value;
        hash *= 1099511628211ull;
    }
    return hash;
}

int main(int argc, char **argv) {
    unsigned int limit = 64;
    if (argc > 1) {
        char *end = NULL;
        errno = 0;
        unsigned long parsed = strtoul(argv[1], &end, 10);
        if (errno || end == argv[1] || *end != '\0') {
            fprintf(stderr, "usage: linux_cli_app [positive-limit]\n");
            return 2;
        }
        limit = (unsigned int)parsed;
    }

    printf("Linux CLI victim\n");
    printf("Limit: %u\n", limit);
    printf("Checksum: 0x%016lX\n", checksum(limit));
    return 0;
}
