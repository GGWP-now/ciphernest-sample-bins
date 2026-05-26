#include "win_shared.h"

#include <stdio.h>

int main(void) {
    const char *text = "matrix-safe";
    printf("Windows shared library victim\n");
    printf("Version: %s\n", win_shared_version());
    printf("Add: %d\n", win_shared_add(20, 22));
    printf("Checksum: 0x%08X\n", win_shared_checksum(text));
    return win_shared_add(20, 22) == 42 ? 0 : 1;
}
