#pragma once

#ifdef __cplusplus
extern "C" {
#endif

__attribute__((visibility("default"))) int linux_shared_add(int left, int right);
__attribute__((visibility("default"))) unsigned int linux_shared_checksum(const char *text);
__attribute__((visibility("default"))) const char *linux_shared_version(void);

#ifdef __cplusplus
}
#endif
