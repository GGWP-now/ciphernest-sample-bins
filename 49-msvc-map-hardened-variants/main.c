#include <stdint.h>
#include <stdio.h>
#include <string.h>

#ifndef VICTIM_VARIANT_ID
#define VICTIM_VARIANT_ID 0
#endif

#if VICTIM_VARIANT_ID == 1
#define VICTIM_VARIANT "msvc_debug_map"
#elif VICTIM_VARIANT_ID == 2
#define VICTIM_VARIANT "msvc_release_cf_map"
#elif VICTIM_VARIANT_ID == 3
#define VICTIM_VARIANT "msvc_ltcg_hardened_map"
#else
#define VICTIM_VARIANT "msvc_unknown"
#endif

static uint32_t digest(const char *text) {
    uint32_t value = 0xA5A5A5A5u;
    for (size_t i = 0; text[i] != '\0'; ++i) {
        value = (value << 5) ^ (value >> 2) ^ (unsigned char)text[i];
    }
    return value;
}

int main(void) {
    printf("MSVC MAP hardened victim\n");
    printf("Variant: %s\n", VICTIM_VARIANT);
    printf("Checksum: 0x%08X\n", digest(VICTIM_VARIANT));
    return 0;
}
