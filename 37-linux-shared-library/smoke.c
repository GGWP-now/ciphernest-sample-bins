#include "linux_shared.h"

#include <stdio.h>

int main(void) {
    printf("Linux shared library victim\n");
    printf("Version: %s\n", linux_shared_version());
    printf("Add: %d\n", linux_shared_add(19, 23));
    printf("Checksum: 0x%08X\n", linux_shared_checksum("matrix-safe"));
    return linux_shared_add(19, 23) == 42 ? 0 : 1;
}
