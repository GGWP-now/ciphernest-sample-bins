#include <stdio.h>

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    printf("macOS AMD64 app victim\n");
    printf("Pointer bits: %u\n", (unsigned)(sizeof(void *) * 8u));
    return 0;
}
