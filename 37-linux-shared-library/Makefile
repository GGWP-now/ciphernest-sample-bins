CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -fPIC
LDFLAGS ?=
OUT ?= build

.PHONY: all clean run

all: $(OUT)/liblinux_shared.so $(OUT)/linux_shared_smoke

$(OUT):
	mkdir -p $(OUT)

$(OUT)/liblinux_shared.so: linux_shared.c linux_shared.h | $(OUT)
	$(CC) $(CFLAGS) -shared -Wl,-soname,liblinux_shared.so -o $@ linux_shared.c $(LDFLAGS)

$(OUT)/linux_shared_smoke: smoke.c linux_shared.h $(OUT)/liblinux_shared.so | $(OUT)
	$(CC) -O2 -Wall -Wextra -o $@ smoke.c -L$(OUT) -llinux_shared -Wl,-rpath,'$$ORIGIN'

run: all
	$(OUT)/linux_shared_smoke

clean:
	rm -rf $(OUT)
