#include "macos_shared.h"

#include <stdio.h>

int main(void) {
    printf("macOS shared library victim\n");
    printf("Version: %s\n", macos_shared_version());
    printf("Add: %d\n", macos_shared_add(21, 21));
    printf("Checksum: 0x%08X\n", macos_shared_checksum("matrix-safe"));
    return macos_shared_add(21, 21) == 42 ? 0 : 1;
}
