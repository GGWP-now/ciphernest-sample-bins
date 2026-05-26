#pragma once

#ifdef __cplusplus
extern "C" {
#endif

__attribute__((visibility("default"))) int macos_shared_add(int left, int right);
__attribute__((visibility("default"))) unsigned int macos_shared_checksum(const char *text);
__attribute__((visibility("default"))) const char *macos_shared_version(void);

#ifdef __cplusplus
}
#endif
