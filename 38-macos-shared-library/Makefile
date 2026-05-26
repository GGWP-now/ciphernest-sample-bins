CC ?= clang
CFLAGS ?= -O2 -Wall -Wextra -fPIC
OUT ?= build

.PHONY: all clean run

all: $(OUT)/libmacos_shared.dylib $(OUT)/macos_shared_smoke

$(OUT):
	mkdir -p $(OUT)

$(OUT)/libmacos_shared.dylib: macos_shared.c macos_shared.h | $(OUT)
	$(CC) $(CFLAGS) -dynamiclib -install_name @rpath/libmacos_shared.dylib -o $@ macos_shared.c

$(OUT)/macos_shared_smoke: smoke.c macos_shared.h $(OUT)/libmacos_shared.dylib | $(OUT)
	$(CC) -O2 -Wall -Wextra -o $@ smoke.c -L$(OUT) -lmacos_shared -Wl,-rpath,@executable_path

run: all
	$(OUT)/macos_shared_smoke

clean:
	rm -rf $(OUT)
