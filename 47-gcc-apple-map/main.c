#include <stdio.h>
#include <string.h>

static unsigned score(const char *text) {
    unsigned value = 7u;
    for (size_t i = 0; text[i] != '\0'; ++i) {
        value = (value * 131u) + (unsigned char)text[i];
    }
    return value;
}

int main(int argc, char **argv) {
    const char *arch = argc > 1 ? argv[1] : "apple-map";
    printf("GCC Apple MAP victim\n");
    printf("Arch: %s\n", arch);
    printf("Score: 0x%08X\n", score(arch));
    return 0;
}
