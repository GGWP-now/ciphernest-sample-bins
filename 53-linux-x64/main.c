#include <stdio.h>

int main(void) {
    printf("Linux x64 victim\n");
    printf("Pointer bits: %u\n", (unsigned)(sizeof(void *) * 8u));
    return 0;
}
